#if canImport(AppKit)
import AppKit
import EaveCore

/// Maps each plugin namespace to one `NSStatusItem` in the system menu bar.
@MainActor
public final class MenuBarRenderer {
    private let pluginsDirectory: String
    private var statusItems: [String: NSStatusItem] = [:]
    private var pluginScriptPathByNamespace: [String: String] = [:]

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
        guard let item = statusItems.removeValue(forKey: namespace) else { return }
        NSStatusBar.system.removeStatusItem(item)
        pluginScriptPathByNamespace.removeValue(forKey: namespace)
    }

    public var itemCount: Int { statusItems.count }

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
