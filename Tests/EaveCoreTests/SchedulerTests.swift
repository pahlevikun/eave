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
    private func makePlugin(_ name: String, body: String) throws -> (String, Plugin) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-sched-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(name).path
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return (path, Plugin(
            filename: name,
            path: path,
            interval: RefreshInterval.parse(fromFilename: name) ?? .default
        ))
    }

    @Test func deliversParsedItems() async throws {
        let (_, plugin) = try makePlugin("clock.5s.sh", body: #"echo "14:22""#)

        let box = ResultBox()
        let scheduler = PluginScheduler { _, result in
            box.record(result)
        }

        let started = await scheduler.tick(plugins: [plugin])
        #expect(started == 1)

        let items = try await box.wait()
        #expect(items.map(\.title) == ["14:22"])
    }

    @Test func secondTickBeforeIntervalStartsNothing() async throws {
        let (_, plugin) = try makePlugin("clock.1h.sh", body: #"echo hi"#)

        let box = ResultBox()
        let scheduler = PluginScheduler { _, result in box.record(result) }

        #expect(await scheduler.tick(plugins: [plugin]) == 1)
        _ = try await box.wait()
        #expect(await scheduler.tick(plugins: [plugin]) == 0)
    }

    @Test func failingPluginStillDeliversFailure() async throws {
        let (_, plugin) = try makePlugin("bad.5s.sh", body: "exit 7")

        let box = ResultBox()
        let scheduler = PluginScheduler { _, result in box.record(result) }

        _ = await scheduler.tick(plugins: [plugin])
        let items = try await box.wait()
        // Exit 7 still prints nothing, so the parse is empty rather than a throw.
        #expect(items.isEmpty)
    }

    @Test func pruneForgetsRemovedPlugins() async throws {
        let (_, plugin) = try makePlugin("gone.5s.sh", body: "echo hi")
        let box = ResultBox()
        let scheduler = PluginScheduler { _, result in box.record(result) }

        _ = await scheduler.tick(plugins: [plugin])
        _ = try await box.wait()
        await scheduler.prune(keeping: [])
        // After prune the plugin counts as never-run again.
        #expect(await scheduler.tick(plugins: [plugin]) == 1)
    }
}

/// Minimal thread-safe collector for delivery results.
final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<[ScriptItem], Error>] = []
    private var waiters: [CheckedContinuation<[ScriptItem], Error>] = []

    func record(_ result: Result<[ScriptItem], Error>) {
        lock.lock()
        results.append(result)
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        if let first = pending.first {
            deliver(first, result)
            for extra in pending.dropFirst() { deliver(extra, result) }
        }
    }

    func wait() async throws -> [ScriptItem] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let first = results.first {
                lock.unlock()
                deliver(continuation, first)
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    private func deliver(
        _ continuation: CheckedContinuation<[ScriptItem], Error>,
        _ result: Result<[ScriptItem], Error>
    ) {
        switch result {
        case .success(let items): continuation.resume(returning: items)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}
