import AppKit

@MainActor
final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var tabController: SettingsTabController?

    func show(appState: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            tabController?.bind(appState: appState)
            return
        }

        let tabs = SettingsTabController()
        tabs.bind(appState: appState)
        tabController = tabs

        let contentSize = NSSize(width: 560, height: 400)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Eave Settings"
        window.contentView = tabs
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
