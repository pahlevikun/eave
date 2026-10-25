import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let mark = Bundle.main.url(forResource: "status-mark", withExtension: "pdf")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Eave")
        mark?.isTemplate = true
        mark?.size = NSSize(width: 18, height: 18)
        item.button?.image = mark
        item.button?.setAccessibilityLabel("Eave")
        item.button?.toolTip = "Eave"
        if mark == nil { item.button?.title = "Eave" }
        item.menu = mainMenu()
        statusItem = item

        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdown()
    }

    private func mainMenu() -> NSMenu {
        let menu = NSMenu()
        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)
        let folder = NSMenuItem(title: "Open Scripts Folder", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        let overflow = NSMenuItem(title: "Show Overflow Preview", action: #selector(showOverflow), keyEquivalent: "")
        overflow.target = self
        menu.addItem(overflow)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    @objc private func openFolder() { appState.openPluginsFolder() }
    @objc private func showOverflow() { appState.toggleNotchTray() }

    @objc private func openSettings() {
        SettingsWindow.shared.show(appState: appState)
    }
}
