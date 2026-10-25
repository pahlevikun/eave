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
    /// Stdout or stderr exceeded the runner’s returned-output byte cap.
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

/// A registration remains valid until discovery removes or replaces its plugin.
/// Check again on the presentation actor before using a delivered result.
public final class PluginDeliveryToken: @unchecked Sendable {
    private let lock = NSLock()
    private var current = true

    public var isCurrent: Bool { lock.withLock { current } }
    public func invalidate() { lock.withLock { current = false } }
}

/// Owns registrations and run tickets. Retired processes finish normally and
/// retain their in-flight exclusion until their own completion arrives.
public actor PluginScheduler {
    public typealias Delivery = @Sendable (Plugin, PluginOutcome, PluginDeliveryToken) -> Void

    private static let execution = DispatchQueue(
        label: "com.eave.plugin-execution",
        qos: .utility,
        attributes: .concurrent
    )

    private struct Registration {
        let plugin: Plugin
        let token: PluginDeliveryToken
    }

    private struct Ticket {
        let plugin: Plugin
        let id: UUID
        let token: PluginDeliveryToken
    }

    private let runner: ScriptRunner
    private let deliver: Delivery
    private var plugins: [Plugin] = []
    private var registrations: [String: Registration] = [:]
    private var lastRun: [String: Date] = [:]
    private var running: [String: Ticket] = [:]
    private var diagnostics: [String: PluginDiagnostics] = [:]

    public init(runner: ScriptRunner = ScriptRunner(), deliver: @escaping Delivery) {
        self.runner = runner
        self.deliver = deliver
    }

    /// Unchanged values retain identity. Same-path content edits take effect on
    /// the next scheduled run; discovery does not fingerprint file contents.
    @discardableResult
    public func setPlugins(_ plugins: [Plugin]) -> [String: PluginDeliveryToken] {
        let incoming = Dictionary(uniqueKeysWithValues: plugins.map { ($0.id, $0) })
        for (id, registration) in registrations {
            if incoming[id] != registration.plugin || !registration.token.isCurrent {
                registration.token.invalidate()
                registrations.removeValue(forKey: id)
                lastRun.removeValue(forKey: id)
                diagnostics.removeValue(forKey: id)
            }
        }
        for plugin in plugins where registrations[plugin.id] == nil {
            registrations[plugin.id] = Registration(plugin: plugin, token: PluginDeliveryToken())
        }
        self.plugins = plugins
        return registrations.mapValues(\.token)
    }

    @discardableResult
    public func tick(now: Date = Date()) -> Int {
        let due = SchedulePlanner.due(
            plugins: plugins, lastRun: lastRun, running: Set(running.keys), now: now
        )
        for plugin in due {
            guard let registration = registrations[plugin.id] else { continue }
            let ticket = Ticket(plugin: plugin, id: UUID(), token: registration.token)
            running[plugin.id] = ticket
            let runner = self.runner
            Self.execution.async { [weak self] in
                let run = Self.run(plugin: plugin, with: runner)
                let finishedAt = Date()
                Task { await self?.finish(plugin: plugin, ticket: ticket, run: run, finishedAt: finishedAt) }
            }
        }
        return due.count
    }

    public func isRunning(_ plugin: Plugin) -> Bool {
        running[plugin.id]?.plugin == plugin
    }

    public func diagnostics(for plugin: Plugin) -> PluginDiagnostics? {
        guard registrations[plugin.id]?.plugin == plugin else { return nil }
        return diagnostics[plugin.id]
    }

    private func finish(plugin: Plugin, ticket: Ticket, run: Run, finishedAt: Date) {
        guard running[plugin.id]?.id == ticket.id else { return }
        running.removeValue(forKey: plugin.id)
        guard ticket.token.isCurrent,
              registrations[plugin.id]?.token === ticket.token else { return }
        lastRun[plugin.id] = finishedAt
        let failure: PluginFailure? = {
            if case .failed(let reason) = run.outcome { return reason }
            return nil
        }()
        diagnostics[plugin.id] = PluginDiagnostics(
            finishedAt: finishedAt, exitCode: run.exitCode, stderr: run.stderr,
            outputTruncated: run.truncated, failure: failure
        )
        deliver(plugin, run.outcome, ticket.token)
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
