import Foundation

/// Runs plugins on their own intervals and hands each result to a callback.
///
/// The actor serialises access to the run state. Plugin execution itself
/// happens off the actor so a slow plugin does not block the others.
public actor PluginScheduler {
    /// Called once per finished run, on an arbitrary task. The status item
    /// renderer is the intended consumer.
    public typealias Delivery = @Sendable (Plugin, Result<[ScriptItem], Error>) -> Void

    private let runner: ScriptRunner
    private let deliver: Delivery
    private var lastRun: [String: Date] = [:]
    private var running: Set<String> = []

    public init(runner: ScriptRunner = ScriptRunner(), deliver: @escaping Delivery) {
        self.runner = runner
        self.deliver = deliver
    }

    /// Runs every plugin that is due. Returns how many were started, which is
    /// what the tests assert on.
    @discardableResult
    public func tick(plugins: [Plugin], now: Date = Date()) -> Int {
        let due = SchedulePlanner.due(
            plugins: plugins,
            lastRun: lastRun,
            running: running,
            now: now
        )

        for plugin in due {
            running.insert(plugin.id)
            let runner = self.runner

            Task.detached { [weak self] in
                let result: Result<[ScriptItem], Error>
                do {
                    let output = try runner.run(path: plugin.path)
                    result = .success(
                        ScriptOutputParser.parse(output.stdout, namespace: plugin.namespace)
                    )
                } catch {
                    result = .failure(error)
                }

                // Record completion before delivering, so a slow callback
                // cannot make the plugin look overdue.
                await self?.finish(plugin: plugin, result: result)
            }
        }

        return due.count
    }

    private func finish(plugin: Plugin, result: Result<[ScriptItem], Error>) {
        running.remove(plugin.id)
        lastRun[plugin.id] = Date()
        deliver(plugin, result)
    }

    /// Drops run state for plugins that vanished from the folder, so a
    /// removed plugin does not keep a stale entry forever.
    public func prune(keeping plugins: [Plugin]) {
        let live = Set(plugins.map(\.id))
        lastRun = lastRun.filter { live.contains($0.key) }
        running = running.intersection(live)
    }

    public func isRunning(_ plugin: Plugin) -> Bool {
        running.contains(plugin.id)
    }
}
