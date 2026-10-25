import Foundation
import Testing
@testable import EaveCore

@Suite("SchedulePlanner")
struct SchedulePlannerTests {
    private func plugin(_ name: String, seconds: Int) -> Plugin {
        Plugin(
            filename: name,
            path: "/tmp/\(name)",
            interval: RefreshInterval(seconds: seconds)
        )
    }

    @Test func neverRunIsDue() {
        let p = plugin("clock.5s.sh", seconds: 5)
        let due = SchedulePlanner.due(plugins: [p], lastRun: [:], now: Date())
        #expect(due.map(\.id) == [p.id])
    }

    @Test func notDueBeforeInterval() {
        let p = plugin("clock.5s.sh", seconds: 5)
        let now = Date()
        let due = SchedulePlanner.due(
            plugins: [p],
            lastRun: [p.id: now.addingTimeInterval(-2)],
            now: now
        )
        #expect(due.isEmpty)
    }

    @Test func dueExactlyAtInterval() {
        let p = plugin("clock.5s.sh", seconds: 5)
        let now = Date()
        let due = SchedulePlanner.due(
            plugins: [p],
            lastRun: [p.id: now.addingTimeInterval(-5)],
            now: now
        )
        #expect(due.map(\.id) == [p.id])
    }

    @Test func runningPluginIsNeverDueAgain() {
        let p = plugin("slow.1s.sh", seconds: 1)
        let now = Date()
        let due = SchedulePlanner.due(
            plugins: [p],
            lastRun: [p.id: now.addingTimeInterval(-60)],
            running: [p.id],
            now: now
        )
        #expect(due.isEmpty)
    }

    @Test func onlyOverduePluginsComeBack() {
        let fast = plugin("a.5s.sh", seconds: 5)
        let slow = plugin("b.1h.sh", seconds: 3_600)
        let now = Date()
        let due = SchedulePlanner.due(
            plugins: [fast, slow],
            lastRun: [
                fast.id: now.addingTimeInterval(-10),
                slow.id: now.addingTimeInterval(-10),
            ],
            now: now
        )
        #expect(due.map(\.id) == [fast.id])
    }
}

@Suite("PluginScheduler")
struct PluginSchedulerTests {
    private func makePlugin(_ name: String, body: String) throws -> Plugin {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-sched-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(name).path
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return Plugin(
            filename: name,
            path: path,
            interval: RefreshInterval.parse(fromFilename: name) ?? .default
        )
    }

    @Test func deliversParsedItems() async throws {
        let plugin = try makePlugin("clock.5s.sh", body: #"echo "14:22""#)

        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([plugin])

        #expect(await scheduler.tick() == 1)
        #expect(try await box.wait() == .items([
            ScriptItem(title: "14:22", namespace: "clock")
        ]))
    }

    @Test func secondTickBeforeIntervalStartsNothing() async throws {
        let plugin = try makePlugin("clock.1h.sh", body: #"echo hi"#)

        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([plugin])

        #expect(await scheduler.tick() == 1)
        _ = try await box.wait()
        #expect(await scheduler.tick() == 0)
    }

    @Test func nonZeroExitIsReportedAsFailureWithItsCode() async throws {
        let plugin = try makePlugin("bad.5s.sh", body: "echo oops >&2; exit 7")

        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([plugin])

        _ = await scheduler.tick()
        #expect(try await box.wait() == .failed(.exitedNonZero(code: 7, stderr: "oops\n")))
    }

    @Test func timeoutIsReportedAsFailure() async throws {
        let plugin = try makePlugin("slow.5s.sh", body: "sleep 10")

        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler(runner: ScriptRunner(timeout: 0.3)) { _, outcome, _ in
            box.record(outcome)
        }
        await scheduler.setPlugins([plugin])

        _ = await scheduler.tick()
        #expect(try await box.wait() == .failed(.timedOut(seconds: 0.3)))
    }

    @Test func settingPluginsForgetsRemovedOnes() async throws {
        let plugin = try makePlugin("gone.5s.sh", body: "echo hi")
        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }

        await scheduler.setPlugins([plugin])
        _ = await scheduler.tick()
        _ = try await box.wait()

        await scheduler.setPlugins([])
        await scheduler.setPlugins([plugin])
        // Back to never-run, so it is due again.
        #expect(await scheduler.tick() == 1)
        _ = try await box.wait()
    }

    @Test func diagnosticsCarryExitCodeAndStderr() async throws {
        let plugin = try makePlugin("bad.5s.sh", body: "echo 'bad flag' >&2; exit 3")
        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([plugin])

        #expect(await scheduler.diagnostics(for: plugin) == nil)

        _ = await scheduler.tick()
        _ = try await box.wait()

        let diagnostics = await scheduler.diagnostics(for: plugin)
        #expect(diagnostics?.exitCode == 3)
        #expect(diagnostics?.stderr == "bad flag\n")
        #expect(diagnostics?.outputTruncated == false)
    }

    @Test func diagnosticsFlagTruncatedOutput() async throws {
        let plugin = try makePlugin(
            "loud.5s.sh",
            body: "head -c 2000000 /dev/zero | tr '\\0' a"
        )
        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let box = OutcomeBox()
        let scheduler = PluginScheduler(runner: ScriptRunner(timeout: 10)) { _, outcome, _ in
            box.record(outcome)
        }
        await scheduler.setPlugins([plugin])

        _ = await scheduler.tick()
        _ = try await box.wait()

        #expect(await scheduler.diagnostics(for: plugin)?.outputTruncated == true)
    }

    @Test func diagnosticsForNeverRunPluginAreNil() async throws {
        let plugin = try makePlugin("quiet.5s.sh", body: "echo hi")
        defer { try? FileManager.default.removeItem(atPath: (plugin.path as NSString).deletingLastPathComponent) }
        let scheduler = PluginScheduler { _, _, _ in }
        await scheduler.setPlugins([plugin])
        #expect(await scheduler.diagnostics(for: plugin) == nil)
    }
}

/// Thread-safe collector for delivered outcomes.
final class OutcomeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [PluginOutcome] = []
    func record(_ outcome: PluginOutcome) {
        lock.withLock { outcomes.append(outcome) }
    }

    var count: Int { lock.withLock { outcomes.count } }

    func wait() async throws -> PluginOutcome {
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if let outcome = lock.withLock({ outcomes.isEmpty ? nil : outcomes.removeFirst() }) {
                return outcome
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw CocoaError(.fileReadUnknown)
    }
}
