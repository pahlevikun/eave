import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Runs a plugin script with a wall-clock timeout and separate returned/generated caps.
///
/// Output goes to temp files rather than pipes so a grandchild cannot hold a pipe
/// open and deadlock the reader after the child is killed.
public struct ScriptRunner: Sendable {
    public struct RunOutput: Equatable, Sendable {
        /// Stdout kept in memory, cut at `OutputLimits.returnedBytes`.
        public let stdout: String
        /// Stderr kept in memory, cut at `OutputLimits.returnedBytes`.
        public let stderr: String
        public let exitCode: Int32
        /// The child wrote more than the returned cap, so the text above is partial.
        public let returnedBytesTruncated: Bool
        /// The child hit the generated cap while it was still running.
        public let generatedBytesExceeded: Bool
    }

    public enum RunError: Error, Equatable, Sendable {
        case notExecutable(path: String)
        case timedOut(seconds: TimeInterval)
        case generatedTooMuch(bytes: Int)
    }

    public let timeout: TimeInterval
    public let limits: OutputLimits

    private static let pollInterval: TimeInterval = 0.05
    private static let terminateGrace: TimeInterval = 0.3
    private static let postKillWait: TimeInterval = 0.3

    public init(timeout: TimeInterval = 5, limits: OutputLimits = .default) {
        self.timeout = timeout
        self.limits = limits
    }

    private static let runLock = NSLock()

    public func run(
        path: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) throws -> RunOutput {
        Self.runLock.lock()
        defer { Self.runLock.unlock() }

        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw RunError.notExecutable(path: path)
        }

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { Self.removeTemporaryRunDirectory(tmpDir) }

        let outURL = tmpDir.appendingPathComponent("stdout")
        let errURL = tmpDir.appendingPathComponent("stderr")
        guard FileManager.default.createFile(atPath: outURL.path, contents: nil),
              FileManager.default.createFile(atPath: errURL.path, contents: nil)
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        let outHandle = try FileHandle(forWritingTo: outURL)
        let errHandle = try FileHandle(forWritingTo: errURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment ?? [
            "PATH": "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin",
            "HOME": NSHomeDirectory(),
        ]
        process.standardOutput = outHandle
        process.standardError = errHandle

        try process.run()

        var generatedBytesExceeded = false
        var consecutiveTruncations = 0
        let waitResult = waitForExit(
            process,
            stdoutURL: outURL,
            stderrURL: errURL,
            upTo: timeout,
            generatedBytesExceeded: &generatedBytesExceeded,
            consecutiveTruncations: &consecutiveTruncations
        )

        if waitResult == .generatedTooMuch {
            try? outHandle.close()
            try? errHandle.close()
            terminate(process)
            throw RunError.generatedTooMuch(bytes: limits.generatedBytes)
        }

        if waitResult == .timedOut {
            try? outHandle.close()
            try? errHandle.close()
            terminate(process)
        } else {
            try? outHandle.close()
            try? errHandle.close()
        }

        if OutputFileMonitor.fileSize(at: outURL) > limits.generatedBytes
            || OutputFileMonitor.fileSize(at: errURL) > limits.generatedBytes
        {
            generatedBytesExceeded = true
        }

        let stdoutData = readCapped(at: outURL)
        let stderrData = readCapped(at: errURL)

        if waitResult == .timedOut {
            throw RunError.timedOut(seconds: timeout)
        }

        return RunOutput(
            stdout: String(decoding: stdoutData.data, as: UTF8.self),
            stderr: String(decoding: stderrData.data, as: UTF8.self),
            exitCode: process.terminationStatus,
            returnedBytesTruncated: stdoutData.truncated || stderrData.truncated,
            generatedBytesExceeded: generatedBytesExceeded
        )
    }

    private enum WaitResult {
        case exited
        case timedOut
        case generatedTooMuch
    }

    private func waitForExit(
        _ process: Process,
        stdoutURL: URL,
        stderrURL: URL,
        upTo seconds: TimeInterval,
        generatedBytesExceeded: inout Bool,
        consecutiveTruncations: inout Int
    ) -> WaitResult {
        let deadline = Date().addingTimeInterval(seconds)
        while process.isRunning, Date() < deadline {
            if OutputFileMonitor.enforceGeneratedCap(
                stdoutURL: stdoutURL,
                stderrURL: stderrURL,
                generatedBytes: limits.generatedBytes,
                consecutiveTruncations: &consecutiveTruncations
            ) {
                generatedBytesExceeded = true
            }
            if consecutiveTruncations >= 3 {
                return .generatedTooMuch
            }
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }
        if process.isRunning {
            return .timedOut
        }
        return .exited
    }

    /// SIGTERM first, then SIGKILL. Signals the process group only when verified.
    private func terminate(_ process: Process) {
        let pid = process.processIdentifier
        signalProcessGroup(pid: pid, signal: SIGTERM)

        let graceDeadline = Date().addingTimeInterval(Self.terminateGrace)
        while process.isRunning, Date() < graceDeadline {
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }
        if process.isRunning {
            signalProcessGroup(pid: pid, signal: SIGKILL)
        }

        let killDeadline = Date().addingTimeInterval(Self.postKillWait)
        while process.isRunning, Date() < killDeadline {
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }
        if !process.isRunning {
            process.waitUntilExit()
        }
    }

    private static func removeTemporaryRunDirectory(_ url: URL) {
        let fm = FileManager.default
        for name in ["stdout", "stderr"] {
            try? fm.removeItem(at: url.appendingPathComponent(name))
        }
        for _ in 0..<40 {
            try? fm.removeItem(at: url)
            if !fm.fileExists(atPath: url.path) { return }
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }
    }

    private func signalProcessGroup(pid: pid_t, signal: Int32) {
        let group = getpgid(pid)
        if group == pid {
            kill(-pid, signal)
        } else {
            kill(pid, signal)
        }
    }

    private func readCapped(at url: URL) -> (data: Data, truncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return (Data(), false)
        }
        defer { try? handle.close() }

        let cap = limits.returnedBytes
        let data = ((try? handle.read(upToCount: cap)) ?? nil) ?? Data()
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? data.count
        return (data, size > cap)
    }
}
