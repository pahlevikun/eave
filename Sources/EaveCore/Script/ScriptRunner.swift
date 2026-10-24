import Foundation

/// Runs a plugin script with a wall-clock timeout and an output cap.
///
/// A plugin is user code. It can hang, and it can flood stdout. Both get
/// tamed here, not in the caller.
///
/// Output goes to a temp file rather than a pipe, for a concrete reason: a
/// grandchild process (the `sleep` inside a shell) also holds the write end
/// of a pipe, so the pipe reader never sees EOF and the caller hangs even
/// after the child is killed. A file has no such problem, and the size cap
/// can still be enforced at read time.
public struct ScriptRunner: Sendable {
    public struct Output: Sendable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32
        public let truncated: Bool
    }

    public enum RunError: Error, Equatable {
        case notExecutable(String)
        case timedOut(seconds: Double)
    }

    /// Output cap. 1 MB covers any reasonable plugin and stops a broken one
    /// from eating disk or memory.
    public static let outputLimit = 1 << 20

    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    public func run(
        path: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) throws -> Output {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw RunError.notExecutable(path)
        }

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eave-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let outURL = tmpDir.appendingPathComponent("stdout")
        let errURL = tmpDir.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)

        let outHandle = try FileHandle(forWritingTo: outURL)
        let errHandle = try FileHandle(forWritingTo: errURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        // Minimal environment: a plugin needs none of the user's shell setup,
        // and inheriting all of it exposes tokens and secrets to the child.
        process.environment = environment ?? [
            "PATH": "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin",
            "HOME": NSHomeDirectory(),
        ]
        process.standardOutput = outHandle
        process.standardError = errHandle

        try process.run()

        let exited = waitForExit(process, upTo: timeout)
        if !exited { terminate(process) }
        try? outHandle.close()
        try? errHandle.close()

        let stdoutData = readCapped(at: outURL)
        let stderrData = readCapped(at: errURL)

        if !exited {
            throw RunError.timedOut(seconds: timeout)
        }

        return Output(
            stdout: String(decoding: stdoutData.data, as: UTF8.self),
            stderr: String(decoding: stderrData.data, as: UTF8.self),
            exitCode: process.terminationStatus,
            truncated: stdoutData.truncated
        )
    }

    private func waitForExit(_ process: Process, upTo seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !process.isRunning
    }

    /// SIGTERM first so the script can clean up, then SIGKILL.
    ///
    /// The signal goes to the whole process group (`-pid`), not just the
    /// child. The child is usually a shell, and the grandchild (`sleep`,
    /// `curl`) is what actually hangs. Killing the shell leaves the
    /// grandchild alive, and `waitUntilExit()` then waits for it.
    private func terminate(_ process: Process) {
        let pid = process.processIdentifier
        kill(-pid, SIGTERM)
        let deadline = Date().addingTimeInterval(0.3)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            kill(-pid, SIGKILL)
        }
        process.waitUntilExit()
    }

    /// Reads a file up to the cap, without loading the whole thing first.
    private func readCapped(at url: URL) -> (data: Data, truncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return (Data(), false)
        }
        defer { try? handle.close() }

        let data = ((try? handle.read(upToCount: Self.outputLimit)) ?? nil) ?? Data()
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? data.count
        return (data, size > Self.outputLimit)
    }
}
