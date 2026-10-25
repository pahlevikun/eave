#if canImport(AppKit)
import AppKit
import EaveCore

@MainActor
public enum ActionDispatcher {
    public typealias ShellExecutor = @Sendable (String, [String]) -> Bool

    /// Opens the URL or runs shell when the action allows it. Returns false when nothing ran.
    public static func perform(_ action: ScriptItemAction, shell: ShellExecutor) -> Bool {
        switch action {
        case .openURL(let url):
            NSWorkspace.shared.open(url)
            return true
        case .runShell(let command, let arguments):
            return shell(command, arguments)
        case .unsupported, .none:
            return false
        }
    }

    /// Runs plugin shell commands off the main actor. Returns false when `/bin/sh` cannot run.
    public static let productionShellExecutor: ShellExecutor = { command, arguments in
        guard FileManager.default.isExecutableFile(atPath: "/bin/sh") else { return false }
        Task.detached(priority: .utility) {
            _ = try? ScriptRunner().runShell(command, arguments: arguments)
        }
        return true
    }

    public static var accessibilityDisplayShouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
#endif
