import Foundation
import Testing
@testable import EaveCore

private struct ControlledPlugin {
    let directory: URL
    let plugin: Plugin
    var started: URL { directory.appendingPathComponent("started") }
    var release: URL { directory.appendingPathComponent("release") }

    init(title: String = "result") throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("eave-controlled-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appendingPathComponent("fixture.1s.sh")
        let body = """
        #!/bin/sh
        cd "$(dirname "$0")"
        touch started
        while [ ! -f release ]; do sleep 0.01; done
        echo '\(title)'
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        plugin = Plugin(filename: script.lastPathComponent, path: script.path, interval: RefreshInterval(seconds: 1))
    }

    func unblock() throws { try Data().write(to: release) }
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

private func eventually(_ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(4)
    while Date() < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw CocoaError(.fileReadUnknown)
}

@Suite("Lifecycle regressions")
struct LifecycleRegressionTests {
    @Test func intervalOverflowIsRejectedAndBoundaryIsAccepted() {
        #expect(RefreshInterval.parse(fromFilename: "clock.\(Int.max)d.sh") == nil)
        let days = Int.max / 86_400
        #expect(RefreshInterval.parse(fromFilename: "clock.\(days)d.sh")?.seconds == days * 86_400)
        #expect(RefreshInterval.parse(fromFilename: "clock.\(Int.max)s.sh")?.seconds == Int.max)
    }

    @Test func successfulTruncationIsVisible() {
        let date = Date()
        let diagnostics = PluginDiagnostics(finishedAt: date, exitCode: 0, stderr: "", outputTruncated: true)
        #expect(PluginStatusText.describe(diagnostics: diagnostics, now: date).contains("output cut at 1 MB"))
    }

    @Test func completionTimeFollowsExecutionAndUnchangedScanPreservesInterval() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        let firstTokens = await scheduler.setPlugins([fixture.plugin])
        _ = await scheduler.tick()
        try await eventually { FileManager.default.fileExists(atPath: fixture.started.path) }
        let releaseTime = Date()
        try fixture.unblock()
        _ = try await box.wait()
        let diagnostics = try #require(await scheduler.diagnostics(for: fixture.plugin))
        #expect(diagnostics.finishedAt >= releaseTime)
        let nextTokens = await scheduler.setPlugins([fixture.plugin])
        #expect(firstTokens[fixture.plugin.id] === nextTokens[fixture.plugin.id])
        #expect(await scheduler.tick(now: diagnostics.finishedAt.addingTimeInterval(0.99)) == 0)
    }

    @Test func removalSuppressesInFlightCompletion() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        let tokens = await scheduler.setPlugins([fixture.plugin])
        _ = await scheduler.tick()
        try await eventually { FileManager.default.fileExists(atPath: fixture.started.path) }
        await scheduler.setPlugins([])
        #expect(tokens[fixture.plugin.id]?.isCurrent == false)
        #expect(await scheduler.isRunning(fixture.plugin))
        try fixture.unblock()
        try await eventually { await !scheduler.isRunning(fixture.plugin) }
        #expect(box.count == 0)
        #expect(await scheduler.diagnostics(for: fixture.plugin) == nil)
    }

    @Test(arguments: [false, true]) func replacementAndReaddRejectRetiredWork(replacePath: Bool) async throws {
        let old = try ControlledPlugin(title: "old")
        let replacement = try ControlledPlugin(title: "new")
        defer {
            old.cleanup()
            replacement.cleanup()
        }
        let current = replacePath ? replacement.plugin : old.plugin
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        let tokens = await scheduler.setPlugins([old.plugin])
        _ = await scheduler.tick()
        try await eventually { FileManager.default.fileExists(atPath: old.started.path) }
        if !replacePath { await scheduler.setPlugins([]) }
        await scheduler.setPlugins([current])
        #expect(tokens[old.plugin.id]?.isCurrent == false)
        #expect(await scheduler.tick() == 0)
        try old.unblock()
        try await eventually { await !scheduler.isRunning(old.plugin) }
        #expect(box.count == 0)
        #expect(await scheduler.diagnostics(for: current) == nil)
        try replacement.unblock()
        #expect(await scheduler.tick() == 1)
        let result = try await box.wait()
        #expect(result == .items([ScriptItem(title: replacePath ? "new" : "old", namespace: "fixture")]))
    }

    @Test func manualRequestStartsOneRunAndDeliversOnce() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([fixture.plugin])
        try fixture.unblock()
        let result = await scheduler.requestRun(pluginID: fixture.plugin.id)
        #expect(result == .queued)
        _ = try await box.wait()
        #expect(box.count == 0)
    }

    @Test func repeatedManualRequestWhileBlockingReturnsAlreadyRunning() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([fixture.plugin])
        #expect(await scheduler.requestRun(pluginID: fixture.plugin.id) == .queued)
        try await eventually { FileManager.default.fileExists(atPath: fixture.started.path) }
        #expect(await scheduler.requestRun(pluginID: fixture.plugin.id) == .alreadyRunning)
        try fixture.unblock()
        _ = try await box.wait()
        #expect(box.count == 0)
    }

    @Test func manualRequestForUnknownPluginIsUnavailable() async throws {
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        #expect(await scheduler.requestRun(pluginID: "missing") == .unavailable)
        #expect(box.count == 0)
    }

    @Test func manualRequestAfterRemovalIsUnavailable() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([fixture.plugin])
        await scheduler.setPlugins([])
        #expect(await scheduler.requestRun(pluginID: fixture.plugin.id) == .unavailable)
        #expect(box.count == 0)
    }

    @Test func manualRunRestartsIntervalFromCompletion() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        await scheduler.setPlugins([fixture.plugin])
        try fixture.unblock()
        #expect(await scheduler.requestRun(pluginID: fixture.plugin.id) == .queued)
        _ = try await box.wait()
        let diagnostics = try #require(await scheduler.diagnostics(for: fixture.plugin))
        let finishedAt = diagnostics.finishedAt
        #expect(await scheduler.tick(now: finishedAt.addingTimeInterval(fixture.plugin.interval.seconds - 0.01)) == 0)
        #expect(await scheduler.tick(now: finishedAt.addingTimeInterval(Double(fixture.plugin.interval.seconds))) == 1)
    }

    @Test func removedPluginSuppressesInFlightManualRun() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        let tokens = await scheduler.setPlugins([fixture.plugin])
        #expect(await scheduler.requestRun(pluginID: fixture.plugin.id) == .queued)
        try await eventually { FileManager.default.fileExists(atPath: fixture.started.path) }
        await scheduler.setPlugins([])
        #expect(tokens[fixture.plugin.id]?.isCurrent == false)
        #expect(await scheduler.isRunning(fixture.plugin))
        try fixture.unblock()
        try await eventually { await !scheduler.isRunning(fixture.plugin) }
        #expect(box.count == 0)
        #expect(await scheduler.diagnostics(for: fixture.plugin) == nil)
    }

    @Test func queuedDeliveryCanBeRejectedAfterActorHop() async throws {
        let fixture = try ControlledPlugin()
        defer { fixture.cleanup() }
        let box = OutcomeBox()
        let scheduler = PluginScheduler { _, outcome, _ in box.record(outcome) }
        let tokens = await scheduler.setPlugins([fixture.plugin])
        try fixture.unblock()
        _ = await scheduler.tick()
        _ = try await box.wait()
        let token = try #require(tokens[fixture.plugin.id])
        #expect(token.isCurrent)
        await scheduler.setPlugins([])
        #expect(await MainActor.run { token.isCurrent } == false)
    }
}

@Suite("Panel geometry")
struct PanelGeometryTests {
    @Test func notchedPanelUsesMidpointAndSitsBelowMenuBar() {
        let screen = PanelRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = PanelRect(x: 0, y: 40, width: 1512, height: 904)
        let notch = PanelRect(x: 660, y: 944, width: 192, height: 38)
        let frame = NotchPanelGeometry.frame(screen: screen, visibleFrame: visible, notch: notch, menuBarHeight: 24, contentHeight: 900)
        #expect(frame.midX == notch.midX)
        #expect(frame.maxY == 936)
        #expect(frame.width == 280)
        #expect(frame.height == 360)
    }

    @Test func offsetNonnotchedDisplayUsesItsOwnCenter() {
        let screen = PanelRect(x: -1920, y: 200, width: 1920, height: 1080)
        let visible = PanelRect(x: -1920, y: 200, width: 1920, height: 1056)
        let frame = NotchPanelGeometry.frame(screen: screen, visibleFrame: visible, notch: nil, menuBarHeight: 24, contentHeight: 100)
        #expect(frame.midX == -960)
        #expect(frame.maxY == 1248)
        #expect(frame.minY >= screen.minY + 8)
    }

    @Test func narrowScreenClampsPanelAndOffCenterNotch() {
        let screen = PanelRect(x: 300, y: -300, width: 240, height: 280)
        let notch = PanelRect(x: 510, y: -44, width: 20, height: 24)
        let frame = NotchPanelGeometry.frame(screen: screen, visibleFrame: screen, notch: notch, menuBarHeight: 24, contentHeight: 900)
        #expect(frame.minX == 308)
        #expect(frame.maxX == 532)
        #expect(frame.minY == -292)
        #expect(frame.maxY == -52)
    }
}
