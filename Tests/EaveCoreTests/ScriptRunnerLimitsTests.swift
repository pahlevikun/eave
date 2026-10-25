import Foundation
import Testing
@testable import EaveCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@Suite("OutputLimits")
struct OutputLimitsTests {
    @Test func defaultsAreOneAndEightMegabytes() {
        let limits = OutputLimits.default
        #expect(limits.returnedBytes == 1 << 20)
        #expect(limits.generatedBytes == 8 << 20)
    }

    @Test func customValuesSurviveInit() {
        let limits = OutputLimits(returnedBytes: 4096, generatedBytes: 16_384)
        #expect(limits.returnedBytes == 4096)
        #expect(limits.generatedBytes == 16_384)
    }

    @Test func generatedBelowReturnedIsAllowed() {
        _ = OutputLimits(returnedBytes: 8192, generatedBytes: 1024)
    }
}

@Suite("ScriptRunner limits", .serialized)
struct ScriptRunnerLimitsTests {
    private func makeScript(_ body: String, marker: URL? = nil) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-limits-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let marker {
            let path = dir.appendingPathComponent("plugin.sh").path
            let markerPath = marker.path
            try ("#!/bin/sh\n" + body.replacingOccurrences(of: "$MARKER", with: markerPath) + "\n")
                .write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            return path
        }
        let path = dir.appendingPathComponent("plugin.sh").path
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    private func limits(returned: Int, generated: Int) -> OutputLimits {
        OutputLimits(returnedBytes: returned, generatedBytes: generated)
    }

    private func countEaveRunDirs() -> Int {
        let tmp = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path)) ?? []
        return names.filter { $0.hasPrefix("eave-run-") }.count
    }

    @Test func smallOutputWithinReturnedCap() throws {
        let path = try makeScript("dd if=/dev/zero bs=1024 count=4 2>/dev/null | tr '\\0' a")
        let runner = ScriptRunner(limits: limits(returned: 8 << 10, generated: 1 << 20))
        let out = try runner.run(path: path)
        #expect(out.stdout.utf8.count == 4 << 10)
        #expect(out.returnedBytesTruncated == false)
    }

    @Test func returnedCapTruncatesLargeStdout() throws {
        let path = try makeScript("dd if=/dev/zero bs=1024 count=64 2>/dev/null | tr '\\0' a")
        let runner = ScriptRunner(limits: limits(returned: 4 << 10, generated: 1 << 20))
        let out = try runner.run(path: path)
        #expect(out.stdout.utf8.count == 4 << 10)
        #expect(out.returnedBytesTruncated == true)
    }

    @Test func generatedCapFlagsAndBoundsFiles() throws {
        let path = try makeScript(
            "i=0; while [ $i -lt 50 ]; do printf '%04096s' '' | tr ' ' x; i=$((i+1)); done"
        )
        let cap = 32 << 10
        let runner = ScriptRunner(timeout: 2, limits: limits(returned: cap, generated: cap))
        let out = try runner.run(path: path)
        #expect(out.generatedBytesExceeded == true)
        #expect(out.stdout.utf8.count <= cap)
    }

    @Test func stderrFloodIsBoundedAndNonBlocking() throws {
        let path = try makeScript(
            """
            i=0
            while [ $i -lt 80 ]; do
              echo "$(printf '%04096s' '' | tr ' ' e)" >&2
              i=$((i+1))
            done
            """
        )
        let cap = 32 << 10
        let runner = ScriptRunner(timeout: 2, limits: limits(returned: cap, generated: cap))
        let out = try runner.run(path: path)
        #expect(out.generatedBytesExceeded == true)
        #expect(out.stderr.utf8.count <= cap)
    }

    @Test func bothStreamsFloodingFinishes() throws {
        let path = try makeScript(
            """
            i=0
            while [ $i -lt 30 ]; do
              printf '%02048s' '' | tr ' ' o
              printf '%02048s' '' | tr ' ' e 1>&2
              i=$((i+1))
            done
            """
        )
        let cap = 24 << 10
        let runner = ScriptRunner(timeout: 2, limits: limits(returned: cap, generated: cap))
        let out = try runner.run(path: path)
        #expect(out.generatedBytesExceeded == true)
        #expect(out.stdout.utf8.count <= cap)
        #expect(out.stderr.utf8.count <= cap)
    }

    @Test func timeoutThrowsQuickly() throws {
        let path = try makeScript("sleep 10")
        let start = Date()
        #expect(throws: ScriptRunner.RunError.timedOut(seconds: 0.3)) {
            try ScriptRunner(timeout: 0.3).run(path: path)
        }
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func timeoutKillsBackgroundDescendant() throws {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-bg-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: marker) }
        let path = try makeScript(
            "sleep 10 & echo $! > $MARKER; sleep 10",
            marker: marker
        )
        #expect(throws: ScriptRunner.RunError.self) {
            try ScriptRunner(timeout: 0.3).run(path: path)
        }
        guard let text = try? String(contentsOf: marker, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            Issue.record("Could not read background child pid")
            return
        }
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
    }

    @Test func tempDirectoryRemovedOnSuccessTimeoutAndRefusal() throws {
        let before = countEaveRunDirs()
        let okPath = try makeScript("echo ok")
        _ = try ScriptRunner().run(path: okPath)
        #expect(countEaveRunDirs() == before)

        let slowPath = try makeScript("sleep 10")
        #expect(throws: ScriptRunner.RunError.self) {
            try ScriptRunner(timeout: 0.2).run(path: slowPath)
        }
        #expect(countEaveRunDirs() == before)

        #expect(throws: ScriptRunner.RunError.self) {
            try ScriptRunner().run(path: "/etc/hostname")
        }
        #expect(countEaveRunDirs() == before)
    }
}
