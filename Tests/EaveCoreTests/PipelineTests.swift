import Foundation
import Testing
@testable import EaveCore

/// End-to-end for the only pipeline that exists today: name a plugin file,
/// run it, parse its output. Everything the app will do starts here, so this
/// test is the honest proof that the foundation is more than isolated parts.
@Suite("Pipeline", .serialized)
struct PipelineTests {
    private func makePlugin(named name: String, body: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-pipeline-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(name).path
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    @Test func pluginFileBecomesMenuBarItem() throws {
        // A real xbar plugin, byte for byte the shape people already publish.
        let path = try makePlugin(named: "clock.5s.sh", body: """
        echo "14:22 | color=#ffffff"
        echo "---"
        echo "Refresh | refresh=true"
        echo "-- Open docs | href=https://example.com"
        """)

        let interval = RefreshInterval.parse(fromFilename: "clock.5s.sh")
        #expect(interval?.seconds == 5)

        let output = try ScriptRunner().run(path: path)
        #expect(output.exitCode == 0)

        let items = XbarParser.parse(output.stdout, namespace: "clock")
        #expect(items.count == 1)
        #expect(items[0].title == "14:22")
        #expect(items[0].parameters["color"] == "#ffffff")
        // `--` nests under the line above it, so "Open docs" is a submenu of
        // "Refresh", not a sibling. Same rule as xbar's own parser.
        #expect(items[0].children.map(\.title) == ["Refresh"])
        #expect(items[0].children[0].children.map(\.title) == ["Open docs"])
        #expect(items[0].children[0].children[0].parameters["href"] == "https://example.com")
    }

    @Test func pluginThatFailsStillYieldsNothingAndReportsExit() throws {
        let path = try makePlugin(named: "broken.10s.sh", body: "echo partial; exit 2")
        let output = try ScriptRunner().run(path: path)
        #expect(output.exitCode == 2)
        let items = XbarParser.parse(output.stdout, namespace: "broken")
        #expect(items.map(\.title) == ["partial"])
    }

    @Test func pluginWithNoOutputYieldsNoItems() throws {
        let path = try makePlugin(named: "quiet.1m.sh", body: "true")
        let output = try ScriptRunner().run(path: path)
        #expect(XbarParser.parse(output.stdout, namespace: "quiet").isEmpty)
    }
}
