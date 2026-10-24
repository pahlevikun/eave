import Foundation

/// Why a plugin run produced no items.
///
/// The set is closed on purpose. A caller decides what to show the user, and
/// an untyped `Error` would force it to guess.
public enum PluginFailure: Equatable, Sendable {
    case notExecutable(path: String)
    case timedOut(seconds: Double)
    /// The plugin ran but exited non-zero. Its stderr is the reason.
    case exitedNonZero(code: Int32, stderr: String)
}

/// What one run yielded.
public enum PluginOutcome: Equatable, Sendable {
    case items([ScriptItem])
    case failed(PluginFailure)
}

/// Runs plugins on their own intervals and hands each result to a callback.
///
/// The actor serialises access to the run state. Plugin execution happens off
/// the actor, so a slow plugin does not block the others. This is the only
/// place in `EaveCore` that knows a process exists; which plugin runs when is
/// `SchedulePlanner`'s job, and that is pure.
public actor PluginScheduler {
    /// Called once per finished run, on an arbitrary task. The status item
    /// renderer is the intended consumer.
    public typealias Delivery = @Sendable (Plugin, PluginOutcome) -> Void

    private let runner: ScriptRunner
    private let deliver: Delivery

    /// Owned here so callers stop threading an array through every tick.
    private var plugins: [Plugin] = []
    private var lastRun: [String: Date] = [:]
    private var running: Set<String> = []

    public init(runner: ScriptRunner = ScriptRunner(), deliver: @escaping Delivery) {
        self.runner = runner
        self.deliver = deliver
    }

    /// Replaces the plugin list and forgets run state for plugins that left,
    /// so a removed plugin does not keep a stale entry forever.
    ///
    /// Call on scan, not on every tick.
    public func setPlugins(_ plugins: [Plugin]) {
        self.plugins = plugins
        let live = Set(plugins.map(\.id))
        lastRun = lastRun.filter { live.contains($0.key) }
        running = running.intersection(live)
    }

    /// Runs every plugin that is due. Returns how many were started, which is
    /// what the tests assert on.
    @discardableResult
    public func tick(now: Date = Date()) -> Int {
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
                let outcome = Self.run(plugin: plugin, with: runner)
                // Record completion before delivering, so a slow callback
                // cannot make the plugin look overdue.
                await self?.finish(plugin: plugin, outcome: outcome)
            }
        }

        return due.count
    }

    public func isRunning(_ plugin: Plugin) -> Bool {
        running.contains(plugin.id)
    }

    private func finish(plugin: Plugin, outcome: PluginOutcome) {
        running.remove(plugin.id)
        lastRun[plugin.id] = Date()
        deliver(plugin, outcome)
    }

    /// Maps one run to an outcome.
    ///
    /// A non-zero exit wins over parsed items: a plugin that prints something
    /// and then fails should not paint a stale title over a working one.
    private static func run(plugin: Plugin, with runner: ScriptRunner) -> PluginOutcome {
        do {
            let output = try runner.run(path: plugin.path)
            guard output.exitCode == 0 else {
                return .failed(.exitedNonZero(code: output.exitCode, stderr: output.stderr))
            }
            return .items(ScriptOutput.parse(output.stdout, namespace: plugin.namespace))
        } catch ScriptRunner.RunError.notExecutable(let path) {
            return .failed(.notExecutable(path: path))
        } catch ScriptRunner.RunError.timedOut(let seconds) {
            return .failed(.timedOut(seconds: seconds))
        } catch {
            return .failed(.exitedNonZero(code: -1, stderr: "\(error)"))
        }
    }
}
