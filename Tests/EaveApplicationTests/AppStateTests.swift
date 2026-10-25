import AppKit
import Testing
import EaveCore
@testable import EaveApplication

@Suite("Application reconciliation", .serialized)
@MainActor
struct AppStateTests {
    private func fixtureDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("eave-app-fixture-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func script(in directory: URL, name: String, body: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @Test(.enabled(
        if: ProcessInfo.processInfo.environment["EAVE_NATIVE_UI_TESTS"] == "1",
        "Requires a GUI test host; the command-line helper exits during native status item delivery."
    ))
    func removalClearsAllPresentationsAndFailures() async throws {
        _ = NSApplication.shared
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let success = try script(in: directory, name: "good.1h.sh", body: "echo visible")
        let failure = try script(in: directory, name: "bad.1h.sh", body: "echo problem >&2; exit 7")
        let state = AppState(pluginsDirectory: directory.path)
        let window = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: false)
        state.attachTouchBar(to: window)
        state.rescanPlugins()
        await state.tick()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, state.menuBarRenderer.itemCount != 1 || state.lastRunFailed.values.filter({ $0 }).count != 1 {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(state.menuBarRenderer.itemCount == 1)
        #expect(state.lastRunFailed.values.filter { $0 }.count == 1)
        #expect(window.touchBar?.defaultItemIdentifiers.contains { $0.rawValue == "good:visible" } == true)
        try FileManager.default.removeItem(at: success)
        try FileManager.default.removeItem(at: failure)
        state.rescanPlugins()
        #expect(state.plugins.isEmpty)
        #expect(state.menuBarRenderer.itemCount == 0)
        #expect(state.lastRunFailed.isEmpty)
        #expect(state.notchTrayPlan.kept.isEmpty)
        #expect(state.notchTrayPlan.overflowed.isEmpty)
        #expect(window.touchBar?.defaultItemIdentifiers.contains { $0.rawValue == "good:visible" } == false)
    }

    @Test func watcherStartFailureCanBeRetried() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watcher = PluginFolderWatcher(path: directory.path, startStream: { _ in false }) {}
        #expect(watcher.start() == false)
        #expect(watcher.start() == false)
        watcher.stop()
    }

    @Test func failedScanRetainsPriorListAndReportsError() throws {
        _ = NSApplication.shared
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try script(in: directory, name: "clock.5s.sh", body: "echo clock")
        let state = AppState(pluginsDirectory: directory.path)
        state.rescanPlugins()
        let plugins = state.plugins
        #expect(plugins.count == 1)
        try FileManager.default.removeItem(at: directory)
        state.rescanPlugins()
        #expect(state.plugins == plugins)
        #expect(state.scanError != nil)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        state.rescanPlugins()
        #expect(state.plugins.isEmpty)
        #expect(state.scanError == nil)
    }
}
