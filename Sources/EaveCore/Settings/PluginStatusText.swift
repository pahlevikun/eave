import Foundation

public enum PluginStatusText {
    /// Examples: "ok, 12s ago", "exit 7, 3m ago", "timeout after 5s",
    /// "not executable", "output cut at 1 MB".
    ///
    /// `now` is a parameter so the test does not depend on the clock.
    public static func describe(
        diagnostics: PluginDiagnostics?,
        now: Date
    ) -> String {
        guard let diagnostics else {
            return "never run"
        }

        if let failure = diagnostics.failure {
            switch failure {
            case .notExecutable:
                return "not executable"
            case .timedOut(let seconds):
                return "timeout after \(formatTimeoutSeconds(seconds))"
            case .exitedNonZero(let code, _):
                return exitLine(code: code, diagnostics: diagnostics, now: now)
            }
        }

        if diagnostics.exitCode == 0 {
            return "ok, \(formatAge(since: diagnostics.finishedAt, now: now))"
        }

        if let code = diagnostics.exitCode {
            return exitLine(code: code, diagnostics: diagnostics, now: now)
        }

        return "not executable"
    }

    private static func exitLine(
        code: Int32,
        diagnostics: PluginDiagnostics,
        now: Date
    ) -> String {
        var line = "exit \(code), \(formatAge(since: diagnostics.finishedAt, now: now))"
        if diagnostics.outputTruncated {
            line += ", output cut at 1 MB"
        }
        return line
    }

    private static func formatTimeoutSeconds(_ seconds: Double) -> String {
        if seconds == seconds.rounded(), seconds >= 0 {
            return "\(Int(seconds))s"
        }
        return "\(seconds)s"
    }

    private static func formatAge(since: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(since))
        if elapsed < 60 {
            let seconds = Int(elapsed.rounded(.down))
            return "\(seconds)s ago"
        }
        if elapsed < 3_600 {
            let minutes = Int((elapsed / 60).rounded(.down))
            return "\(minutes)m ago"
        }
        let hours = Int((elapsed / 3_600).rounded(.down))
        return "\(hours)h ago"
    }
}
