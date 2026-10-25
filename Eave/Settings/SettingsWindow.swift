import AppKit

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var tabController: SettingsTabController?

    func show(appState: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            tabController?.bind(appState: appState)
            tabController?.setPresented(true)
            appState.attachTouchBar(to: window)
            return
        }

        let tabs = SettingsTabController()
        tabs.bind(appState: appState)
        tabController = tabs

        let contentSize = NSSize(width: 680, height: 480)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Eave Settings"
        window.contentMinSize = NSSize(width: 600, height: 420)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = tabs
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        tabs.setPresented(true)
        appState.attachTouchBar(to: window)
    }

    func windowWillClose(_ notification: Notification) {
        tabController?.setPresented(false)
    }
}
