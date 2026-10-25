import Foundation
import Testing
@testable import EaveCore

@Suite("ScriptRunner", .serialized)
struct ScriptRunnerTests {
    /// Menulis script sementara, mengembalikan path-nya.
    private func makeScript(_ body: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("plugin.sh").path
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    @Test func capturesStdout() throws {
        let path = try makeScript("echo hello")
        let out = try ScriptRunner().run(path: path)
        #expect(out.stdout == "hello\n")
        #expect(out.exitCode == 0)
        #expect(out.returnedBytesTruncated == false)
    }

    @Test func capturesExitCode() throws {
        let path = try makeScript("exit 3")
        let out = try ScriptRunner().run(path: path)
        #expect(out.exitCode == 3)
    }

    @Test func killsRunawayScript() throws {
        let path = try makeScript("sleep 10")
        let start = Date()
        #expect(throws: ScriptRunner.RunError.self) {
            try ScriptRunner(timeout: 0.5).run(path: path)
        }
        #expect(Date().timeIntervalSince(start) < 3)
    }

    @Test func refusesNonExecutable() {
        #expect(throws: ScriptRunner.RunError.self) {
            try ScriptRunner().run(path: "/etc/hostname")
        }
    }

    @Test func truncatesHugeOutput() throws {
        let path = try makeScript("head -c 2000000 /dev/zero | tr '\\0' a")
        let out = try ScriptRunner(timeout: 5).run(path: path)
        #expect(out.returnedBytesTruncated)
        #expect(out.stdout.utf8.count == OutputLimits.default.returnedBytes)
    }

    @Test func passesEnvironment() throws {
        let path = try makeScript("echo $EAVE_TEST")
        let out = try ScriptRunner().run(
            path: path,
            environment: ["PATH": "/bin:/usr/bin", "EAVE_TEST": "on"]
        )
        #expect(out.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "on")
    }
}
