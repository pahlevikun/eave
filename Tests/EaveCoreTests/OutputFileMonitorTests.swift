import Foundation
import Testing
@testable import EaveCore

@Suite("Output file monitor", .serialized)
struct OutputFileMonitorTests {
    private func makeFile(bytes: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-monitor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("stdout")
        try Data(repeating: 120, count: bytes).write(to: url)
        return url
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func readsTheRealFileSize() throws {
        let url = try makeFile(bytes: 5_000)
        defer { remove(url) }
        #expect(OutputFileMonitor.fileSize(at: url) == 5_000)
    }

    @Test func missingFileReportsZero() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eave-absent-\(UUID().uuidString)")
        #expect(OutputFileMonitor.fileSize(at: url) == 0)
    }

    @Test func loudStreamIsTruncatedAndReported() throws {
        let url = try makeFile(bytes: 2_000)
        defer { remove(url) }
        let result = OutputFileMonitor.enforceGeneratedCap(
            stdoutURL: url, stderrURL: url, generatedBytes: 1_000
        )
        #expect(result.truncated)
        #expect(result.runaway == false)
        #expect(OutputFileMonitor.fileSize(at: url) == 0)
    }

    @Test func silentStreamIsLeftAlone() throws {
        let url = try makeFile(bytes: 500)
        defer { remove(url) }
        let result = OutputFileMonitor.enforceGeneratedCap(
            stdoutURL: url, stderrURL: url, generatedBytes: 1_000
        )
        #expect(result == OutputFileMonitor.Enforced())
        #expect(OutputFileMonitor.fileSize(at: url) == 500)
    }

    @Test func hugeOvershootIsARunaway() throws {
        let url = try makeFile(bytes: 200_000)
        defer { remove(url) }
        let result = OutputFileMonitor.enforceGeneratedCap(
            stdoutURL: url, stderrURL: url, generatedBytes: 1_000
        )
        #expect(result.runaway)
        #expect(result.truncated)
    }

    @Test func runawayLimitHandlesHugeCapsWithoutOverflow() {
        let result = OutputFileMonitor.enforceGeneratedCap(
            stdoutURL: URL(fileURLWithPath: "/nonexistent-a"),
            stderrURL: URL(fileURLWithPath: "/nonexistent-b"),
            generatedBytes: Int.max / 2
        )
        #expect(result == OutputFileMonitor.Enforced())
    }
}
