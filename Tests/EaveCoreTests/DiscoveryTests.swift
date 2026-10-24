import Foundation
import Testing
@testable import EaveCore

@Suite("JSONOutputParser")
struct JSONOutputParserTests {
    @Test func parsesTitleAndColor() {
        let payload = JSONOutputParser.parse(##"{"title":"CPU 12%","color":"#ff0000"}"##)
        #expect(payload?.title == "CPU 12%")
        #expect(payload?.color == "#ff0000")
    }

    @Test func parsesImageOnly() {
        let payload = JSONOutputParser.parse(#"{"image":"icon.png"}"#)
        let item = payload.flatMap { JSONOutputParser.item(from: $0, namespace: "ns") }
        #expect(item?.parameters["image"] == "icon.png")
        #expect(item?.title == "")
    }

    @Test func rejectsPlainText() {
        #expect(JSONOutputParser.parse("CPU 12%") == nil)
    }

    @Test func rejectsMalformedJSON() {
        #expect(JSONOutputParser.parse(#"{"title": }"#) == nil)
    }

    @Test func rejectsEmptyPayload() {
        let payload = JSONOutputParser.parse("{}")
        #expect(payload != nil)
        #expect(JSONOutputParser.item(from: payload!, namespace: "ns") == nil)
    }

    @Test func outputParserPrefersJSON() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-json-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("p.sh").path
        try "#!/bin/sh\necho '{\"title\":\"hi\"}'\n".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)

        let output = try ScriptRunner().run(path: path)
        let items = ScriptOutputParser.parse(output.stdout, namespace: "p")
        #expect(items.map(\.title) == ["hi"])
    }

    @Test func outputParserFallsBackToPlainText() {
        let items = ScriptOutputParser.parse("14:22 | color=#fff", namespace: "clock")
        #expect(items.map(\.title) == ["14:22"])
        #expect(items[0].parameters["color"] == "#fff")
    }
}

@Suite("PluginDiscovery")
struct PluginDiscoveryTests {
    private func makeDir() throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    private func write(_ dir: String, _ name: String, executable: Bool = true) throws {
        let path = (dir as NSString).appendingPathComponent(name)
        try "#!/bin/sh\necho hi\n".write(toFile: path, atomically: true, encoding: .utf8)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
    }

    @Test func findsExecutablesAndReadsInterval() throws {
        let dir = try makeDir()
        try write(dir, "clock.5s.sh")
        try write(dir, "cpu.sh")

        let plugins = try PluginDiscovery.scan(directory: dir)
        #expect(plugins.count == 2)
        #expect(plugins[0].filename == "clock.5s.sh")
        #expect(plugins[0].interval.seconds == 5)
        #expect(plugins[0].namespace == "clock")
        #expect(plugins[1].interval.seconds == RefreshInterval.default.seconds)
        #expect(plugins[1].namespace == "cpu")
    }

    @Test func skipsNonExecutableAndHiddenFiles() throws {
        let dir = try makeDir()
        try write(dir, "run.sh")
        try write(dir, "notes.txt", executable: false)
        try write(dir, ".hidden.sh")

        let plugins = try PluginDiscovery.scan(directory: dir)
        #expect(plugins.map(\.filename) == ["run.sh"])
    }

    @Test func sortsByName() throws {
        let dir = try makeDir()
        try write(dir, "zeta.sh")
        try write(dir, "alpha.sh")
        try write(dir, "mid.sh")
        #expect(try PluginDiscovery.scan(directory: dir).map(\.filename) == ["alpha.sh", "mid.sh", "zeta.sh"])
    }

    @Test func namespaceStripsIntervalAndExtension() {
        #expect(Plugin.namespace(fromFilename: "clock.5s.sh") == "clock")
        #expect(Plugin.namespace(fromFilename: "git-status.sh") == "git-status")
        #expect(Plugin.namespace(fromFilename: "weather.1d.sh") == "weather")
    }

    @Test func throwsWhenDirectoryMissing() {
        #expect(throws: PluginDiscovery.ScanError.self) {
            try PluginDiscovery.scan(directory: "/nope/\(UUID().uuidString)")
        }
    }
}
