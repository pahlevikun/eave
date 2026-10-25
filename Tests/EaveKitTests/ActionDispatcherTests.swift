#if canImport(AppKit)
import AppKit
import EaveCore
import Testing
@testable import EaveKit

@Suite("ActionDispatcher shell", .serialized)
@MainActor
struct ActionDispatcherTests {
    private final class ShellCallRecorder: @unchecked Sendable {
        var calls = 0
        var command = ""
        var arguments: [String] = []
    }

    @Test func runShellInvokesInjectedExecutor() {
        _ = NSApplication.shared
        let recorder = ShellCallRecorder()
        let ok = ActionDispatcher.perform(
            .runShell(command: "echo hi", arguments: ["a", "b"]),
            shell: { command, arguments in
                recorder.calls += 1
                recorder.command = command
                recorder.arguments = arguments
                return true
            }
        )
        #expect(ok)
        #expect(recorder.calls == 1)
        #expect(recorder.command == "echo hi")
        #expect(recorder.arguments == ["a", "b"])
    }

    @Test func unsupportedDoesNotInvokeShell() {
        _ = NSApplication.shared
        let recorder = ShellCallRecorder()
        let ok = ActionDispatcher.perform(
            .unsupported(parameter: "bash"),
            shell: { _, _ in
                recorder.calls += 1
                return true
            }
        )
        #expect(ok == false)
        #expect(recorder.calls == 0)
    }
}
#endif
