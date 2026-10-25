#if canImport(AppKit)
import AppKit
@testable import EaveKit
import EaveCore
import Testing

@Suite struct MenuItemBuilderTests {
    @Test @MainActor func twoChildrenProduceTwoMenuItems() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [
                ScriptItem(title: "One", namespace: "clock"),
                ScriptItem(title: "Two", namespace: "clock"),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        #expect(menu.items.count == 2)
        #expect(menu.items[0].title == "One")
        #expect(menu.items[1].title == "Two")
    }

    @Test @MainActor func childWithHrefHasActionAndTarget() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [
                ScriptItem(
                    title: "Link",
                    namespace: "clock",
                    parameters: ["href": "https://example.com"]
                ),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        let item = menu.items[0]
        #expect(item.action != nil)
        #expect(item.target != nil)
    }

    @Test @MainActor func childWithoutHrefHasNilAction() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [ScriptItem(title: "Plain", namespace: "clock")]
        )
        let menu = MenuItemBuilder.menu(for: root)
        #expect(menu.items[0].action == nil)
    }

    @Test @MainActor func rowShortcutSetsKeyEquivalent() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [
                ScriptItem(
                    title: "Reload",
                    namespace: "clock",
                    parameters: ["href": "https://example.com", "shortcut": "cmd+shift+r"]
                ),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        let item = menu.items[0]
        #expect(item.keyEquivalent == "r")
        #expect(item.keyEquivalentModifierMask.contains(.command))
        #expect(item.keyEquivalentModifierMask.contains(.shift))
    }

    @Test @MainActor func rowWithoutShortcutLeavesKeyEquivalentEmpty() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [
                ScriptItem(
                    title: "Link",
                    namespace: "clock",
                    parameters: ["href": "https://example.com"]
                ),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        #expect(menu.items[0].keyEquivalent == "")
        #expect(menu.items[0].keyEquivalentModifierMask.isEmpty)
    }

    @Test @MainActor func nestedChildProducesSubmenu() {
        let root = ScriptItem(
            title: "root",
            namespace: "clock",
            children: [
                ScriptItem(
                    title: "Parent",
                    namespace: "clock",
                    children: [ScriptItem(title: "Child", namespace: "clock")]
                ),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        let parent = menu.items[0]
        #expect(parent.submenu != nil)
        #expect(parent.submenu?.items.count == 1)
        #expect(parent.submenu?.items[0].title == "Child")
    }
}
#endif
