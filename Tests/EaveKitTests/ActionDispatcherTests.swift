#if canImport(AppKit)
import AppKit
import EaveCore
import Testing
@testable import EaveKit

@Suite("ActionDispatcher shell", .serialized)
@MainActor
struct ActionDispatcherTests {
    @Test func runShellInvokesInjectedExecutor() {
        _ = NSApplication.shared
        var calls = 0
        var seenCommand = ""
        var seenArguments: [String] = []
        let ok = ActionDispatcher.perform(
            .runShell(command: "echo hi", arguments: ["a", "b"]),
            shell: { command, arguments in
                calls += 1
                seenCommand = command
                seenArguments = arguments
                return true
            }
        )
        #expect(ok)
        #expect(calls == 1)
        #expect(seenCommand == "echo hi")
        #expect(seenArguments == ["a", "b"])
    }

    @Test func unsupportedDoesNotInvokeShell() {
        _ = NSApplication.shared
        var calls = 0
        let ok = ActionDispatcher.perform(
            .unsupported(parameter: "bash"),
            shell: { _, _ in
                calls += 1
                return true
            }
        )
        #expect(ok == false)
        #expect(calls == 0)
    }
}
#endif
