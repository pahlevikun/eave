import AppKit
import Combine
import EaveCore
import EaveKit

@MainActor
final class AppState: ObservableObject {
    let menuBarRenderer = MenuBarRenderer()
    let permissionStore = PermissionStore()
    private(set) var plugins: [Plugin] = []
    private(set) var scanRejections: [PluginDiscovery.Rejection] = []
    private(set) var lastRunFailed: [String: Bool] = [:]

    private lazy var separatorEngine = SeparatorEngine(
        onExpand: { [weak self] in
            self?.menuBarRenderer.restoreSeparatedForHide()
        }
    )
    private lazy var itemMover = ItemMover { [weak self] id in
        self?.menuBarRenderer.moverItem(for: id)?.frame
    }
    private lazy var hiddenSectionController = HiddenSectionController(
        separatorEngine: separatorEngine,
        itemMover: itemMover,
        resolveItem: { [weak self] id in
            self?.menuBarRenderer.moverItem(for: id)
        },
        barMetrics: { [weak self] in
            self?.menuBarRenderer.menuBarMetrics() ?? (width: 1_512, height: 24)
        },
        onExpand: { [weak self] in
            self?.menuBarRenderer.restoreSeparatedForHide()
        }
    )
    private let touchBarPresenter = TouchBarPresenter()
    private var touchBarItemsByNamespace: [String: [ScriptItem]] = [:]
    private(set) var isTouchBarEnabled = true

    private let notchPanel = NotchPanel()
    private(set) var notchTrayPlan = NotchTrayModel.Plan(kept: [], overflowed: [])

    private var scheduler: PluginScheduler!
    private var tickTimer: Timer?
    private var pluginWatcher: PluginFolderWatcher?
    private var watcherFailed = false

    private let pluginsDirectory: String

    var isHideSectionCollapsed: Bool { hiddenSectionController.isCollapsed }

    init() {
        pluginsDirectory = (NSHomeDirectory() as NSString).appendingPathComponent(".eave/plugins")
        ensurePluginsDirectory()
        scheduler = PluginScheduler { [weak self] plugin, outcome in
            Task { @MainActor in
                self?.handleDelivery(plugin: plugin, outcome: outcome)
            }
        }
    }

    func start() {
        permissionStore.startPolling()
        touchBarPresenter.install()
        rescanPlugins()
        pluginWatcher = PluginFolderWatcher(path: pluginsDirectory) { [weak self] in
            Task { @MainActor in
                self?.rescanPlugins()
            }
        }
        if pluginWatcher?.start() == false {
            watcherFailed = true
            NSLog("Eave: FSEvent stream failed, rescanning plugins on every tick")
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
    }

    func diagnostics(for plugin: Plugin) async -> PluginDiagnostics? {
        await scheduler.diagnostics(for: plugin)
    }

    func lastOutcomeFailed(for plugin: Plugin) -> Bool {
        lastRunFailed[plugin.id] ?? false
    }

    func toggleHiddenSection() {
        let members = menuBarRenderer.sectionMembers()
        let hasAccessibility = permissionStore.granted[.accessibility] == true
        let decision = HidePlan.decide(members: members, hasAccessibility: hasAccessibility)
        hiddenSectionController.toggle(decision: decision)
        objectWillChange.send()
    }

    func setTouchBarEnabled(_ enabled: Bool) {
        isTouchBarEnabled = enabled
        touchBarPresenter.isEnabled = enabled
        if enabled {
            refreshTouchBar()
        } else {
            touchBarPresenter.clearIfNeeded()
        }
        objectWillChange.send()
    }

    func toggleNotchTray() {
        recomputeNotchTrayPlan()
        guard let screen = NSScreen.main else { return }
        notchPanel.toggle(plan: notchTrayPlan, on: screen)
    }

    private func recomputeNotchTrayPlan() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let auxLeft = screen.auxiliaryTopLeftArea?.width ?? 0
        let notchWidth = NotchGeometry.width(
            screenWidth: frame.width,
            auxLeftWidth: auxLeft,
            auxRightWidth: screen.auxiliaryTopRightArea?.width ?? 0
        )
        let notchMaxX = frame.minX + auxLeft + notchWidth
        let budget = NotchGeometry.usableWidthRightOfNotch(
            screenMaxX: frame.maxX,
            notchMaxX: notchMaxX
        )
        let items = menuBarRenderer.notchTrayItems()
        notchTrayPlan = NotchTrayModel.plan(items: items, availableWidth: budget)
    }

    private func ensurePluginsDirectory() {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: pluginsDirectory, isDirectory: &isDir) {
            return
        }
        try? FileManager.default.createDirectory(
            atPath: pluginsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func rescanPlugins() {
        do {
            let result = try PluginDiscovery.scan(directory: pluginsDirectory)
            plugins = result.plugins
            scanRejections = result.rejections
            Task {
                await scheduler.setPlugins(plugins)
            }
        } catch PluginDiscovery.ScanError.directoryMissing {
            ensurePluginsDirectory()
            plugins = []
            scanRejections = []
            Task {
                await scheduler.setPlugins([])
            }
        } catch {
            NSLog("Eave: plugin scan failed: \(error)")
        }
    }

    private func tick() async {
        if watcherFailed {
            rescanPlugins()
        }
        await scheduler.tick()
    }

    private func handleDelivery(plugin: Plugin, outcome: PluginOutcome) {
        menuBarRenderer.registerPluginScriptPath(plugin.path, for: plugin.namespace)
        switch outcome {
        case .items(let items):
            lastRunFailed[plugin.id] = false
            if items.isEmpty {
                menuBarRenderer.remove(namespace: plugin.namespace)
                touchBarItemsByNamespace.removeValue(forKey: plugin.namespace)
            } else {
                menuBarRenderer.apply(items, for: plugin.namespace)
                touchBarItemsByNamespace[plugin.namespace] = items
            }
        case .failed:
            lastRunFailed[plugin.id] = true
            menuBarRenderer.remove(namespace: plugin.namespace)
            touchBarItemsByNamespace.removeValue(forKey: plugin.namespace)
        }
        refreshTouchBar()
        recomputeNotchTrayPlan()
        objectWillChange.send()
    }

    private func refreshTouchBar() {
        let items = touchBarItemsByNamespace.values.flatMap { $0 }
        touchBarPresenter.update(scriptItems: items)
    }

    func rejectionFooterText() -> String {
        scanRejections.map { rejection in
            switch rejection.reason {
            case .duplicateNamespace(let kept):
                return "skipped \(rejection.filename), name already used by \(kept)"
            }
        }.joined(separator: "; ")
    }
}
