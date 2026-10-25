#if canImport(AppKit)
import AppKit
import EaveCore

enum KeyboardShortcutKit {
    static func modifierMask(for shortcut: KeyboardShortcut) -> NSEvent.ModifierFlags {
        var mask = NSEvent.ModifierFlags()
        let modifiers = shortcut.modifiers
        if modifiers.contains(.command) {
            mask.insert(.command)
        }
        if modifiers.contains(.option) {
            mask.insert(.option)
        }
        if modifiers.contains(.control) {
            mask.insert(.control)
        }
        if modifiers.contains(.shift) {
            mask.insert(.shift)
        }
        return mask
    }

    static func apply(_ shortcut: KeyboardShortcut?, to item: NSMenuItem) {
        guard let shortcut else { return }
        item.keyEquivalent = shortcut.key
        item.keyEquivalentModifierMask = modifierMask(for: shortcut)
    }
}
#endif
