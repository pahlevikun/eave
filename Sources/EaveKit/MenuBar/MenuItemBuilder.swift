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
            if let href = item.parameters["href"], URL(string: href) != nil {
                entry.action = #selector(MenuItemActionTarget.openLink(_:))
                entry.target = MenuItemActionTarget.shared
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

    @objc func openLink(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ScriptItem,
              let href = item.parameters["href"],
              let url = URL(string: href)
        else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
