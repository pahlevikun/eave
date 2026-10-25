#if canImport(AppKit)
import AppKit
import EaveCore

@MainActor
public enum ActionDispatcher {
    /// Opens the URL when the action allows it. Returns false when nothing ran.
    public static func perform(_ action: ScriptItemAction) -> Bool {
        switch action {
        case .openURL(let url):
            NSWorkspace.shared.open(url)
            return true
        case .unsupported, .none:
            return false
        }
    }

    public static var accessibilityDisplayShouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
#endif
