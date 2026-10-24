import AppKit

@MainActor
final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var scriptsPane: ScriptsPane?

    func show(appState: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            scriptsPane?.bind(appState: appState)
            return
        }

        let pane = ScriptsPane()
        pane.bind(appState: appState)
        scriptsPane = pane

        let contentSize = NSSize(width: 560, height: 360)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Eave Settings"
        window.contentView = pane
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
