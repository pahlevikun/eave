import Foundation
import Testing
@testable import EaveCore

@Suite("PluginStatusText")
struct PluginStatusTextTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func nilMeansNeverRun() {
        #expect(PluginStatusText.describe(diagnostics: nil, now: now) == "never run")
    }

    @Test func okShowsSecondsAgo() {
        let diag = PluginDiagnostics(
            finishedAt: now.addingTimeInterval(-12),
            exitCode: 0,
            stderr: "",
            outputTruncated: false
        )
        #expect(PluginStatusText.describe(diagnostics: diag, now: now) == "ok, 12s ago")
    }

    @Test func exitCodeShowsMinutesAgo() {
        let diag = PluginDiagnostics(
            finishedAt: now.addingTimeInterval(-180),
            exitCode: 7,
            stderr: "oops",
            outputTruncated: false,
            failure: .exitedNonZero(code: 7, stderr: "oops")
        )
        #expect(PluginStatusText.describe(diagnostics: diag, now: now) == "exit 7, 3m ago")
    }

    @Test func exitCodeWithTruncation() {
        let diag = PluginDiagnostics(
            finishedAt: now.addingTimeInterval(-5),
            exitCode: 2,
            stderr: "",
            outputTruncated: true,
            failure: .exitedNonZero(code: 2, stderr: "")
        )
        #expect(
            PluginStatusText.describe(diagnostics: diag, now: now)
                == "exit 2, 5s ago, output cut at 1 MB"
        )
    }

    @Test func timeoutShape() {
        let diag = PluginDiagnostics(
            finishedAt: now,
            exitCode: nil,
            stderr: "",
            outputTruncated: false,
            failure: .timedOut(seconds: 5)
        )
        #expect(PluginStatusText.describe(diagnostics: diag, now: now) == "timeout after 5s")
    }

    @Test func notExecutableShape() {
        let diag = PluginDiagnostics(
            finishedAt: now,
            exitCode: nil,
            stderr: "",
            outputTruncated: false,
            failure: .notExecutable(path: "/tmp/x.sh")
        )
        #expect(PluginStatusText.describe(diagnostics: diag, now: now) == "not executable")
    }

    @Test func okShowsHoursAgo() {
        let diag = PluginDiagnostics(
            finishedAt: now.addingTimeInterval(-7_200),
            exitCode: 0,
            stderr: "",
            outputTruncated: false
        )
        #expect(PluginStatusText.describe(diagnostics: diag, now: now) == "ok, 2h ago")
    }

    @Test func returnedCapWordingUsesDefaultLimit() {
        let diag = PluginDiagnostics(
            finishedAt: now,
            exitCode: 0,
            stderr: "",
            outputTruncated: true
        )
        #expect(
            PluginStatusText.describe(diagnostics: diag, now: now)
                == "ok, 0s ago, \(PluginStatusText.returnedOutputTruncationNote)"
        )
    }

    @Test func generatedCapWordingUsesDefaultLimit() {
        let diag = PluginDiagnostics(
            finishedAt: now,
            exitCode: 0,
            stderr: "",
            outputTruncated: false,
            generatedBytesExceeded: true
        )
        #expect(
            PluginStatusText.describe(diagnostics: diag, now: now)
                == "ok, 0s ago, \(PluginStatusText.generatedOutputExceededNote)"
        )
    }

    @Test func hardStopWordingUsesDefaultGeneratedLimit() {
        let diag = PluginDiagnostics(
            finishedAt: now,
            exitCode: nil,
            stderr: "",
            outputTruncated: false,
            generatedBytesExceeded: true,
            failure: .generatedTooMuch(bytes: OutputLimits.default.generatedBytes)
        )
        #expect(
            PluginStatusText.describe(diagnostics: diag, now: now)
                == "stopped after \(PluginStatusText.formatByteCap(OutputLimits.default.generatedBytes))"
        )
    }
}
