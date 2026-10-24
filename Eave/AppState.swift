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

    private var scheduler: PluginScheduler!
    private var tickTimer: Timer?
    private var pluginWatcher: PluginFolderWatcher?
    private var watcherFailed = false

    private let pluginsDirectory: String

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
            } else {
                menuBarRenderer.apply(items, for: plugin.namespace)
            }
        case .failed:
            lastRunFailed[plugin.id] = true
            menuBarRenderer.remove(namespace: plugin.namespace)
        }
        objectWillChange.send()
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
