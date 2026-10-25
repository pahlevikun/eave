#if canImport(AppKit)
import AppKit
import EaveCore

/// Maps each plugin namespace to one `NSStatusItem` in the system menu bar.
@MainActor
public final class MenuBarRenderer {
    private let pluginsDirectory: String
    private var statusItems: [String: NSStatusItem] = [:]
    private var pluginScriptPathByNamespace: [String: String] = [:]
    private var separatedForHide: Set<String> = []

    public init() {
        pluginsDirectory = (NSHomeDirectory() as NSString).appendingPathComponent(".eave/plugins")
    }

    /// Remembers the plugin script path so relative `image` parameters resolve correctly.
    public func registerPluginScriptPath(_ path: String, for namespace: String) {
        pluginScriptPathByNamespace[namespace] = path
    }

    /// Applies one plugin's output. Empty output removes that plugin's item.
    public func apply(_ items: [ScriptItem], for namespace: String) {
        guard let first = items.first else {
            remove(namespace: namespace)
            return
        }

        let title = first.title
        let imagePath = first.parameters["image"]
        let hasImage = imagePath != nil && !(imagePath?.isEmpty ?? true)

        if title.isEmpty, !hasImage {
            remove(namespace: namespace)
            return
        }

        let statusItem = statusItem(for: namespace)
        statusItem.button?.title = title
        statusItem.button?.image = loadImage(path: imagePath, namespace: namespace)

        if first.children.isEmpty {
            statusItem.menu = nil
        } else {
            statusItem.menu = MenuItemBuilder.menu(for: first)
        }
    }

    public func remove(namespace: String) {
        separatedForHide.remove(namespace)
        pluginScriptPathByNamespace.removeValue(forKey: namespace)
        guard let item = statusItems.removeValue(forKey: namespace) else { return }
        NSStatusBar.system.removeStatusItem(item)
    }

    public var itemCount: Int { statusItems.count }

    /// Members in deterministic namespace order.
    public func sectionMembers() -> [SectionMembership] {
        orderedNamespaces().map { namespace in
            SectionMembership(id: namespace, isMovable: true, isHideable: true)
        }
    }

    /// Items currently shown in the menu bar, for notch packing.
    public func notchTrayItems(measuredFallbackWidth: CGFloat = 24) -> [NotchTrayItem] {
        orderedNamespaces().map { namespace in
            let title = statusItems[namespace]?.button?.title ?? namespace
            // Placeholder width is a lie until measured.
            let width = measuredWidth(for: namespace) ?? measuredFallbackWidth
            return NotchTrayItem(id: namespace, title: title, width: width)
        }
    }

    public func measuredWidth(for namespace: String) -> CGFloat? {
        guard let button = statusItems[namespace]?.button else { return nil }
        button.layoutSubtreeIfNeeded()
        let width = button.frame.width
        guard width > 0 else { return nil }
        return width
    }

    /// Hides movable items before the separator expands.
    public func separateForHide(namespaces: [String]) {
        for namespace in namespaces {
            separatedForHide.insert(namespace)
            statusItems[namespace]?.button?.isHidden = true
        }
    }

    public func restoreSeparatedForHide() {
        for namespace in separatedForHide {
            statusItems[namespace]?.button?.isHidden = false
        }
        separatedForHide.removeAll()
    }

    public func moverItem(for namespace: String) -> ItemMover.Item? {
        guard let button = statusItems[namespace]?.button,
              let window = button.window
        else { return nil }
        button.layoutSubtreeIfNeeded()
        let frame = button.convert(button.bounds, to: nil)
        let screenFrame = window.convertToScreen(frame)
        let pid = ProcessInfo.processInfo.processIdentifier
        return ItemMover.Item(id: namespace, frame: screenFrame, ownerPID: pid)
    }

    public func menuBarMetrics() -> (width: Double, height: Double) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let width = screen?.frame.width ?? 1_512
        let topInset = screen?.safeAreaInsets.top ?? 0
        let height = topInset > 0 ? 37.0 : 24.0
        return (Double(width), height)
    }

    private func orderedNamespaces() -> [String] {
        statusItems.keys.sorted()
    }

    private func statusItem(for namespace: String) -> NSStatusItem {
        if let existing = statusItems[namespace] {
            return existing
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItems[namespace] = item
        return item
    }

    private func loadImage(path: String?, namespace: String) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }

        let resolved = resolveImagePath(path, namespace: namespace)
        guard FileManager.default.fileExists(atPath: resolved) else { return nil }
        return NSImage(contentsOfFile: resolved)
    }

    private func resolveImagePath(_ path: String, namespace: String) -> String {
        if path.hasPrefix("/") {
            return path
        }

        if let scriptPath = pluginScriptPathByNamespace[namespace] {
            let pluginDir = (scriptPath as NSString).deletingLastPathComponent
            let relative = (pluginDir as NSString).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: relative) {
                return relative
            }
        }

        return (pluginsDirectory as NSString).appendingPathComponent(path)
    }
}
#endif
