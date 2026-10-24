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

/// Facts about the last run of one plugin.
///
/// Separate from `PluginOutcome` because these are things a person reads in a
/// settings list, not things the renderer acts on. Keeping them apart stops
/// the renderer from having to carry exit codes around.
public struct PluginDiagnostics: Equatable, Sendable {
    public var finishedAt: Date
    /// `nil` when the process never started.
    public var exitCode: Int32?
    /// Captured stderr, capped at `stderrLimit` characters.
    public var stderr: String
    /// The plugin printed more than the output cap, so its title is partial.
    public var outputTruncated: Bool
    /// Set when the last run failed, so settings text can name the reason.
    public var failure: PluginFailure?

    /// Stderr shown to a person. The rest is dropped: a plugin that dumps a
    /// stack trace should not push the interesting line off the pane.
    public static let stderrLimit = 2_000

    public init(
        finishedAt: Date,
        exitCode: Int32?,
        stderr: String,
        outputTruncated: Bool,
        failure: PluginFailure? = nil
    ) {
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.stderr = String(stderr.prefix(Self.stderrLimit))
        self.outputTruncated = outputTruncated
        self.failure = failure
    }
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
    private var diagnostics: [String: PluginDiagnostics] = [:]

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
        diagnostics = diagnostics.filter { live.contains($0.key) }
    }

    /// Runs every plugin that is due. Returns how many were started.
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
                let finishedAt = Date()
                let run = Self.run(plugin: plugin, with: runner)
                // Record completion before delivering, so a slow callback
                // cannot make the plugin look overdue.
                await self?.finish(plugin: plugin, run: run, finishedAt: finishedAt)
            }
        }

        return due.count
    }

    public func isRunning(_ plugin: Plugin) -> Bool {
        running.contains(plugin.id)
    }

    /// The last run's facts, for the settings list. `nil` before the first run.
    public func diagnostics(for plugin: Plugin) -> PluginDiagnostics? {
        diagnostics[plugin.id]
    }

    private func finish(plugin: Plugin, run: Run, finishedAt: Date) {
        running.remove(plugin.id)
        lastRun[plugin.id] = finishedAt
        let failure: PluginFailure? = {
            if case .failed(let reason) = run.outcome { return reason }
            return nil
        }()
        diagnostics[plugin.id] = PluginDiagnostics(
            finishedAt: finishedAt,
            exitCode: run.exitCode,
            stderr: run.stderr,
            outputTruncated: run.truncated,
            failure: failure
        )
        deliver(plugin, run.outcome)
    }

    /// One run's outcome plus the facts that only a person needs.
    private struct Run {
        var outcome: PluginOutcome
        var exitCode: Int32?
        var stderr: String
        var truncated: Bool
    }

    /// Maps one run to an outcome.
    ///
    /// A non-zero exit wins over parsed items: a plugin that prints something
    /// and then fails should not paint a stale title over a working one.
    private static func run(plugin: Plugin, with runner: ScriptRunner) -> Run {
        do {
            let output = try runner.run(path: plugin.path)
            guard output.exitCode == 0 else {
                return Run(
                    outcome: .failed(.exitedNonZero(code: output.exitCode, stderr: output.stderr)),
                    exitCode: output.exitCode,
                    stderr: output.stderr,
                    truncated: output.truncated
                )
            }
            return Run(
                outcome: .items(ScriptOutput.parse(output.stdout, namespace: plugin.namespace)),
                exitCode: output.exitCode,
                stderr: output.stderr,
                truncated: output.truncated
            )
        } catch ScriptRunner.RunError.notExecutable(let path) {
            return Run(
                outcome: .failed(.notExecutable(path: path)),
                exitCode: nil,
                stderr: "",
                truncated: false
            )
        } catch ScriptRunner.RunError.timedOut(let seconds) {
            return Run(
                outcome: .failed(.timedOut(seconds: seconds)),
                exitCode: nil,
                stderr: "",
                truncated: false
            )
        } catch {
            return Run(
                outcome: .failed(.notExecutable(path: plugin.path)),
                exitCode: nil,
                stderr: "\(error)",
                truncated: false
            )
        }
    }
}
