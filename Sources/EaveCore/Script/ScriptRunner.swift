import Foundation

/// Menjalankan script plugin dengan batas waktu dan batas output.
///
/// Plugin adalah kode user: bisa menggantung, bisa membanjiri stdout.
/// Keduanya harus dijinakkan di sini, bukan di pemanggil.
///
/// Output ditampung di file sementara, bukan pipe. Alasannya konkret: proses
/// cucu (mis. `sleep` di dalam shell) ikut memegang ujung tulis pipe, jadi
/// pembaca pipe tidak pernah melihat EOF dan pemanggil menggantung meski anak
/// sudah dibunuh. File tidak punya masalah itu, dan batas ukuran tetap bisa
/// ditegakkan saat membaca.
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

    /// Batas keluaran. 1MB cukup untuk plugin apa pun yang masuk akal, dan
    /// mencegah plugin rusak menghabiskan disk atau memori.
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
        // Lingkungan minimal: plugin tidak butuh seluruh environment user,
        // dan mewariskan semuanya membuat token/secret ikut terbaca.
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

    /// SIGTERM dulu supaya script sempat membersihkan diri, lalu SIGKILL.
    ///
    /// Sinyal dikirim ke seluruh process group (`-pid`), bukan ke anak saja.
    /// Anak biasanya shell, dan cucunya (`sleep`, `curl`) yang sebenarnya
    /// menggantung; membunuh shell tidak menyentuh cucu, sehingga
    /// `waitUntilExit()` menunggu sampai cucu selesai sendiri.
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

    /// Membaca file sampai batas, tanpa memuat seluruh isi ke memori lebih dulu.
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
