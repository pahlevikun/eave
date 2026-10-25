import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Polls runner temp files and enforces the generated-byte cap while the child runs.
enum OutputFileMonitor {
    static func fileSize(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int) ?? 0
    }

    static func truncateToZero(at url: URL) {
        let path = url.path
        let fd = open(path, O_RDWR)
        guard fd >= 0 else { return }
        defer { close(fd) }
        ftruncate(fd, 0)
    }

    /// Truncates streams that grew past the cap. Returns whether any stream was truncated
    /// this cycle and updates `consecutiveTruncations` for hard-stop detection.
    static func enforceGeneratedCap(
        stdoutURL: URL,
        stderrURL: URL,
        generatedBytes: Int,
        consecutiveTruncations: inout Int
    ) -> Bool {
        var truncatedAny = false
        for url in [stdoutURL, stderrURL] {
            guard fileSize(at: url) > generatedBytes else { continue }
            truncateToZero(at: url)
            truncatedAny = true
            consecutiveTruncations += 1
        }
        if !truncatedAny {
            consecutiveTruncations = 0
        }
        return truncatedAny
    }
}
