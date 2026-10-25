#if canImport(AppKit)
import AppKit
import EaveCore

/// Builds `NSMenu` trees from `ScriptItem` values.
@MainActor
public enum MenuItemBuilder {
    public static func menu(for item: ScriptItem) -> NSMenu {
        let menu = NSMenu()
        for child in item.children {
            menu.addItem(menuItem(for: child))
        }
        return menu
    }

    private static func menuItem(for item: ScriptItem) -> NSMenuItem {
        let entry = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
        entry.representedObject = item

        if item.children.isEmpty {
            switch item.action {
            case .openURL, .runShell:
                entry.action = #selector(MenuItemActionTarget.perform(_:))
                entry.target = MenuItemActionTarget.shared
            case .unsupported, .none:
                entry.isEnabled = false
            }
        } else {
            entry.submenu = menu(for: item)
        }

        return entry
    }
}

@MainActor
final class MenuItemActionTarget: NSObject {
    static let shared = MenuItemActionTarget()

    @objc func perform(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ScriptItem else { return }
        ActionDispatcher.perform(item.action, shell: ActionDispatcher.productionShellExecutor)
    }
}
#endif
