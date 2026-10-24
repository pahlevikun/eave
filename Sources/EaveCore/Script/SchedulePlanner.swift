import Foundation

/// Decides which plugins are due, without running anything.
///
/// Pure on purpose: a scheduler that only exists as timers can't be tested
/// without sleeping, and sleep-based tests are slow and flaky. The planner
/// takes the clock as a parameter, so "10 seconds later" is an argument.
public enum SchedulePlanner {
    /// A plugin is due when it has never run, or when its interval has
    /// elapsed since the last completed run.
    ///
    /// A plugin already running is not due, even if its interval elapsed.
    /// That is the coalescing rule: a slow plugin must not stack up copies of
    /// itself when its output takes longer than its interval.
    public static func due(
        plugins: [Plugin],
        lastRun: [String: Date],
        running: Set<String> = [],
        now: Date
    ) -> [Plugin] {
        plugins.filter { plugin in
            if running.contains(plugin.id) { return false }
            guard let previous = lastRun[plugin.id] else { return true }
            let elapsed = now.timeIntervalSince(previous)
            return elapsed >= TimeInterval(plugin.interval.seconds)
        }
    }
}
