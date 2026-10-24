import Foundation
import Testing
@testable import EaveCore

@Suite("ScriptOutput JSON")
struct ScriptOutputJSONTests {
    @Test func readsTitleAndColor() {
        let items = ScriptOutput.parse(##"{"title":"CPU 12%","color":"#ff0000"}"##, namespace: "cpu")
        #expect(items.map(\.title) == ["CPU 12%"])
        #expect(items.first?.parameters["color"] == "#ff0000")
    }

    @Test func readsImageOnlyPayload() {
        let items = ScriptOutput.parse(#"{"image":"icon.png"}"#, namespace: "ns")
        #expect(items.count == 1)
        #expect(items[0].title == "")
        #expect(items[0].parameters["image"] == "icon.png")
    }

    @Test func plainTextIsNotTreatedAsJSON() {
        // Falls through to the line parser, which is what a non-JSON plugin needs.
        let items = ScriptOutput.parse("CPU 12%", namespace: "cpu")
        #expect(items.map(\.title) == ["CPU 12%"])
    }

    @Test func malformedJSONFallsBackToLineParsing() {
        let items = ScriptOutput.parse(#"{"title": }"#, namespace: "ns")
        // The line parser sees one line with no `---`, so the raw text is the title.
        #expect(items.map(\.title) == [#"{"title": }"#])
    }

    @Test func emptyObjectYieldsNoItem() {
        #expect(ScriptOutput.parse("{}", namespace: "ns").isEmpty)
    }

    @Test func pluginPrintingJSONBecomesOneItem() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-json-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("p.sh").path
        try "#!/bin/sh\necho '{\"title\":\"hi\"}'\n".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)

        let output = try ScriptRunner().run(path: path)
        let items = ScriptOutput.parse(output.stdout, namespace: "p")
        #expect(items.map(\.title) == ["hi"])
    }

    @Test func outputParserFallsBackToPlainText() {
        let items = ScriptOutput.parse("14:22 | color=#fff", namespace: "clock")
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

        let result = try PluginDiscovery.scan(directory: dir)
        #expect(result.plugins.count == 2)
        #expect(result.rejections.isEmpty)
        #expect(result.plugins[0].filename == "clock.5s.sh")
        #expect(result.plugins[0].interval.seconds == 5)
        #expect(result.plugins[0].namespace == "clock")
        #expect(result.plugins[1].interval.seconds == RefreshInterval.default.seconds)
        #expect(result.plugins[1].namespace == "cpu")
    }

    @Test func skipsNonExecutableAndHiddenFiles() throws {
        let dir = try makeDir()
        try write(dir, "run.sh")
        try write(dir, "notes.txt", executable: false)
        try write(dir, ".hidden.sh")

        let result = try PluginDiscovery.scan(directory: dir)
        #expect(result.plugins.map(\.filename) == ["run.sh"])
        #expect(result.rejections.isEmpty)
    }

    @Test func sortsByName() throws {
        let dir = try makeDir()
        try write(dir, "zeta.sh")
        try write(dir, "alpha.sh")
        try write(dir, "mid.sh")
        #expect(
            try PluginDiscovery.scan(directory: dir).plugins.map(\.filename)
                == ["alpha.sh", "mid.sh", "zeta.sh"]
        )
    }

    @Test func namespaceStripsIntervalAndExtension() {
        #expect(Plugin.namespace(fromFilename: "clock.5s.sh") == "clock")
        #expect(Plugin.namespace(fromFilename: "git-status.sh") == "git-status")
        #expect(Plugin.namespace(fromFilename: "weather.1d.sh") == "weather")
    }

    @Test func namespaceIgnoresNonIntervalSuffixes() {
        // "status" is not an interval, so it stays part of the name.
        #expect(Plugin.namespace(fromFilename: "git-status.sh") == "git-status")
        // A bare name keeps everything.
        #expect(Plugin.namespace(fromFilename: "clock.sh") == "clock")
        // Digits with an unknown unit are not an interval either.
        #expect(Plugin.namespace(fromFilename: "backup.5x.sh") == "backup.5x")
    }

    @Test func duplicateNamespaceRejectsTheSecondFile() throws {
        let dir = try makeDir()
        try write(dir, "clock.5s.sh")
        try write(dir, "clock.1m.sh")

        let result = try PluginDiscovery.scan(directory: dir)
        // Sorted order: 1m comes first, so it is kept and 5s is rejected.
        #expect(result.plugins.map(\.filename) == ["clock.1m.sh"])
        #expect(
            result.rejections == [
                .init(filename: "clock.5s.sh", reason: .duplicateNamespace(kept: "clock.1m.sh"))
            ]
        )
    }

    @Test func collidingFilesStillHaveDistinctIdentities() throws {
        let dir = try makeDir()
        try write(dir, "clock.5s.sh")
        try write(dir, "clock.1m.sh")

        let result = try PluginDiscovery.scan(directory: dir)
        // The kept file keeps its own id; the rejected one is simply absent,
        // so state for it would be dropped on the next setPlugins.
        #expect(result.plugins[0].id == "clock.1m.sh")
        #expect(result.plugins.contains { $0.id == "clock.5s.sh" } == false)
    }

    @Test func throwsWhenDirectoryMissing() {
        #expect(throws: PluginDiscovery.ScanError.self) {
            try PluginDiscovery.scan(directory: "/nope/\(UUID().uuidString)")
        }
    }
}
