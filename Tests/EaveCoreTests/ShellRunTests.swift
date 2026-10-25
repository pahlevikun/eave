import Foundation
import Testing
@testable import EaveCore

@Suite("Shell run", .serialized)
struct ShellRunTests {
    @Test func echoHello() throws {
        let out = try ScriptRunner().runShell("echo hello")
        #expect(out.stdout == "hello\n")
        #expect(out.exitCode == 0)
    }

    @Test func positionalArgumentsFromParam1() throws {
        let out = try ScriptRunner().runShell("printf '%s-%s' \"$1\" \"$2\"", arguments: ["a", "b"])
        #expect(out.stdout == "a-b")
        #expect(out.exitCode == 0)
    }

    @Test func nonZeroExitIsNotAnError() throws {
        let out = try ScriptRunner().runShell("exit 3")
        #expect(out.exitCode == 3)
    }

    @Test func returnedCapTruncatesLargeStdout() throws {
        let limits = OutputLimits(returnedBytes: 4 << 10, generatedBytes: 8 << 20)
        let out = try ScriptRunner(timeout: 5, limits: limits).runShell(
            "dd if=/dev/zero bs=1024 count=64 2>/dev/null | tr '\\0' a"
        )
        #expect(out.stdout.utf8.count == 4 << 10)
        #expect(out.returnedBytesTruncated == true)
        #expect(out.exitCode == 0)
    }

    @Test func timeoutThrowsQuickly() throws {
        let start = Date()
        #expect(throws: ScriptRunner.RunError.timedOut(seconds: 0.3)) {
            try ScriptRunner(timeout: 0.3).runShell("sleep 10")
        }
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func commandStringPassedVerbatimIncludingPipes() throws {
        let out = try ScriptRunner().runShell("echo one | tr 'o' O")
        #expect(out.stdout == "One\n")
    }

    @Test func ninthParameterIsForwarded() throws {
        let out = try ScriptRunner().runShell("printf '%s' \"$9\"", arguments: [
            "skip", "skip", "skip", "skip", "skip", "skip", "skip", "skip", "last",
        ])
        #expect(out.stdout == "last")
    }

    @Test func workingDirectoryIsHonoured() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-shell-pwd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let out = try ScriptRunner().runShell("pwd", workingDirectory: dir.path)
        let reported = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(reported == dir.path)
    }
}
