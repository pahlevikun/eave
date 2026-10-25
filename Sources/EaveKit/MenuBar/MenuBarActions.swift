#if canImport(AppKit)
import EaveCore

/// Hooks the app uses after menu bar row actions.
@MainActor
public enum MenuBarActions {
    public static var didPerform: ((ScriptItem) -> Void)?
}
#endif
