import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Keeps the two output files bounded while a script runs.
///
/// The runner writes child output to files instead of pipes, because a pipe
/// deadlocks when a grandchild keeps the write end open. A file needs a size
/// limit instead, and that limit is enforced here.
enum OutputFileMonitor {
    /// A loud plugin gets truncated and allowed to finish, so a chatty
    /// diagnostic still shows its last lines.
    ///
    /// A plugin that writes this many times the cap between two polls is not
    /// producing output, it is flooding. Truncation cannot keep up with it, so
    /// the run is stopped instead of spinning.
    static let runawayMultiple = 16

    /// Result of one poll.
    struct Enforced: Equatable {
        var truncated = false
        var runaway = false
    }

    static func fileSize(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        // The size arrives as NSNumber. Casting straight to Int works on Darwin
        // and silently returns nil on Linux, which is how the cap went unenforced.
        return (attributes?[.size] as? NSNumber)?.intValue ?? 0
    }

    static func truncateToZero(at url: URL) {
        let path = url.path
        let fd = open(path, O_RDWR)
        guard fd >= 0 else { return }
        defer { close(fd) }
        ftruncate(fd, 0)
    }

    /// Truncates every stream that grew past the cap, and reports whether a
    /// stream overshot far enough to count as a runaway.
    static func enforceGeneratedCap(
        stdoutURL: URL,
        stderrURL: URL,
        generatedBytes: Int
    ) -> Enforced {
        var result = Enforced()
        let runawayLimit = generatedBytes > Int.max / runawayMultiple
            ? Int.max
            : generatedBytes * runawayMultiple

        for url in [stdoutURL, stderrURL] {
            let size = fileSize(at: url)
            guard size > generatedBytes else { continue }
            if size > runawayLimit {
                result.runaway = true
            }
            truncateToZero(at: url)
            result.truncated = true
        }
        return result
    }
}
