import AppKit
import Combine
import EaveCore
import EaveKit

@MainActor
final class AppState: ObservableObject {
    let menuBarRenderer = MenuBarRenderer()
    let permissionStore = PermissionStore()
    private let preferencesStore: PreferencesStore
    private(set) var plugins: [Plugin] = []
    private(set) var scanError: String?
    private(set) var hideStatus = "Menu bar section is expanded."
    private var deliveryTokens: [String: PluginDeliveryToken] = [:]
    private var scanTask: Task<Void, Never>?
    private var scanRevision = 0
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
    private(set) var preferencesPersistenceWarning: String?
    private var suppressPreferenceSave = false

    private lazy var notchPanel = NotchPanel { [weak self] in self?.objectWillChange.send() }
    private(set) var notchTrayPlan = NotchTrayModel.Plan(kept: [], overflowed: [])

    private var scheduler: PluginScheduler!
    private var tickTimer: Timer?
    private var pluginWatcher: PluginFolderWatcher?
    private var watcherFailed = false

    let pluginsDirectory: String

    var isNotchTrayOpen: Bool { notchPanel.isOpen }

    var isHideSectionCollapsed: Bool { hiddenSectionController.isCollapsed }

    init(pluginsDirectory: String? = nil, preferencesStore: PreferencesStore = PreferencesStore()) {
        self.pluginsDirectory = pluginsDirectory ?? (NSHomeDirectory() as NSString).appendingPathComponent(".eave/plugins")
        self.preferencesStore = preferencesStore
        ensurePluginsDirectory()
        scheduler = PluginScheduler { [weak self] plugin, outcome, token in
            Task { @MainActor in
                guard token.isCurrent, self?.deliveryTokens[plugin.id] === token else { return }
                self?.handleDelivery(plugin: plugin, outcome: outcome)
            }
        }
    }

    func start() {
        suppressPreferenceSave = true
        let preferences = preferencesStore.load()
        setTouchBarEnabled(preferences.touchBarEnabled)
        if preferences.hiddenSectionCollapsed {
            toggleHiddenSection()
        }
        suppressPreferenceSave = false

        permissionStore.startPolling()
        _ = separatorEngine
        separatorEngine.startObserving()
        touchBarPresenter.enableCustomizationMenuItem()
        rescanPlugins()
        // The watcher already hops to the main actor before calling this.
        pluginWatcher = PluginFolderWatcher(path: pluginsDirectory) { [weak self] in
            self?.rescanPlugins()
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

    func shutdown() {
        tickTimer?.invalidate()
        tickTimer = nil
        pluginWatcher?.stop()
        pluginWatcher = nil
        permissionStore.stopPolling()
        separatorEngine.stopObserving()
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
        switch hiddenSectionController.toggle(decision: decision) {
        case .toggledSeparator:
            hideStatus = isHideSectionCollapsed ? "Menu bar section is hidden." : "Menu bar section is expanded."
        case .toggledFullMode(let skipped):
            hideStatus = skipped.isEmpty ? "Menu bar section is hidden." : "Hidden with skipped items: " + skipped.joined(separator: ", ")
        case .moveFailed(let id):
            hideStatus = "Could not move \(id). The section may be partly moved."
        }
        persistPreferences()
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
        persistPreferences()
        objectWillChange.send()
    }

    private func persistPreferences() {
        guard !suppressPreferenceSave else { return }
        let preferences = AppPreferences(
            schemaVersion: AppPreferences.currentSchemaVersion,
            hiddenSectionCollapsed: isHideSectionCollapsed,
            touchBarEnabled: isTouchBarEnabled
        )
        if preferencesStore.save(preferences) {
            preferencesPersistenceWarning = nil
        } else {
            preferencesPersistenceWarning =
                "This choice is active now but may not survive a restart."
        }
    }

    func toggleNotchTray() {
        recomputeNotchTrayPlan()
        guard let screen = NSScreen.main else { return }
        notchPanel.toggle(plan: notchTrayPlan, on: screen)
        objectWillChange.send()
    }

    private func recomputeNotchTrayPlan() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let budget: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let notchWidth = NotchGeometry.width(
                screenWidth: frame.width, auxLeftWidth: left.width, auxRightWidth: right.width
            )
            budget = NotchGeometry.usableWidthRightOfNotch(
                screenMaxX: frame.maxX, notchMaxX: frame.minX + left.width + notchWidth
            )
        } else {
            budget = max(0, frame.width - 16)
        }
        let items = menuBarRenderer.notchTrayItems()
        notchTrayPlan = NotchTrayModel.plan(items: items, availableWidth: budget)
        notchPanel.update(plan: notchTrayPlan, on: screen)
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

    func rescanPlugins() {
        do {
            let result = try PluginDiscovery.scan(directory: pluginsDirectory)
            let previous = plugins
            let retained = Set(result.plugins.filter { previous.contains($0) }.map(\.id))
            for plugin in previous where !retained.contains(plugin.id) {
                deliveryTokens.removeValue(forKey: plugin.id)?.invalidate()
                menuBarRenderer.remove(namespace: plugin.namespace)
                touchBarItemsByNamespace.removeValue(forKey: plugin.namespace)
                lastRunFailed.removeValue(forKey: plugin.id)
            }
            plugins = result.plugins
            scanRejections = result.rejections
            scanError = nil
            scanRevision += 1
            let revision = scanRevision
            let snapshot = plugins
            let previousTask = scanTask
            scanTask = Task { [weak self] in
                await previousTask?.value
                guard let self else { return }
                let tokens = await scheduler.setPlugins(snapshot)
                guard revision == scanRevision else { return }
                deliveryTokens = tokens
                objectWillChange.send()
            }
            refreshTouchBar()
            recomputeNotchTrayPlan()
        } catch {
            scanError = "Could not read Scripts Folder. \(error.localizedDescription)"
        }
        objectWillChange.send()
    }

    func isRunning(_ plugin: Plugin) async -> Bool {
        await scheduler.isRunning(plugin)
    }

    func runNow(pluginID: String) async -> RunRequestResult {
        await scheduler.requestRun(pluginID: pluginID)
    }

    func attachTouchBar(to window: NSWindow) {
        touchBarPresenter.attach(to: window)
    }

    func openPluginsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: pluginsDirectory, isDirectory: true))
    }

    func tick() async {
        if watcherFailed {
            rescanPlugins()
        }
        await scanTask?.value
        await scheduler.tick()
    }

    private func handleDelivery(plugin: Plugin, outcome: PluginOutcome) {
        guard plugins.contains(plugin) else { return }
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
        let items = touchBarItemsByNamespace.keys.sorted().flatMap { touchBarItemsByNamespace[$0] ?? [] }
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
