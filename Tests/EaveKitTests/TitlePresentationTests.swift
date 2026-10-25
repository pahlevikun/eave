#if canImport(AppKit)
import AppKit
@testable import EaveKit
import EaveCore
import Testing

/// A real status item needs a window server, and a plain swift-testing run has
/// none. Same opt-in as the application tests.
private let guiTestsEnabled =
    ProcessInfo.processInfo.environment["EAVE_NATIVE_UI_TESTS"] == "1"

@Suite struct TitlePresentationTests {
    @Test(.enabled(if: guiTestsEnabled, "Requires a GUI test host for a real status item."))
    @MainActor
    func dropdownFalseClearsMenuDespiteChildren() {
        let renderer = MenuBarRenderer()
        renderer.apply(
            [
                ScriptItem(
                    title: "Title",
                    namespace: "demo",
                    parameters: ["dropdown": "false"],
                    children: [ScriptItem(title: "Child", namespace: "demo")]
                ),
            ],
            for: "demo"
        )
        #expect(renderer.notchTrayItems().first?.title == "Title")
        #expect(renderer.hasAttachedMenu(for: "demo") == false)
    }

    @Test(.enabled(if: guiTestsEnabled, "Requires a GUI test host for a real status item."))
    @MainActor
    func statusItemTitleStripsANSI() {
        let renderer = MenuBarRenderer()
        renderer.apply(
            [ScriptItem(title: "\u{1B}[31m14:22\u{1B}[0m", namespace: "clock")],
            for: "clock"
        )
        #expect(renderer.notchTrayItems().first?.title == "14:22")
    }

    @Test @MainActor func menuRowAppliesNamedColour() {
        let root = ScriptItem(
            title: "root",
            namespace: "demo",
            children: [
                ScriptItem(title: "Alert", namespace: "demo", parameters: ["color": "red"]),
                ScriptItem(title: "Default", namespace: "demo"),
            ]
        )
        let menu = MenuItemBuilder.menu(for: root)
        let coloured = menu.items[0]
        let plain = menu.items[1]

        let applied = coloured.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(applied == NSColor.systemRed)
        #expect(coloured.title.isEmpty)
        #expect(plain.title == "Default")
        #expect(plain.attributedTitle?.length == 0)
    }

    @Test(.enabled(if: guiTestsEnabled, "Requires a GUI test host for a real status item."))
    @MainActor
    func statusButtonUsesPlainTitleWithoutColour() {
        let button = NSButton()
        button.applyMenuBarTitle("steady", color: nil)
        #expect(button.title == "steady")
        #expect(button.attributedTitle.length == 0)
    }

    @Test func namedColoursMapToSystemColours() {
        for named in ScriptColor.Named.allCases {
            let mapped = ScriptColorKit.nsColor(for: named)
            switch named {
            case .black:
                #expect(mapped == .black)
            case .white:
                #expect(mapped == .white)
            case .red:
                #expect(mapped == .systemRed)
            case .green:
                #expect(mapped == .systemGreen)
            case .blue:
                #expect(mapped == .systemBlue)
            case .yellow:
                #expect(mapped == .systemYellow)
            case .orange:
                #expect(mapped == .systemOrange)
            case .purple:
                #expect(mapped == .systemPurple)
            case .gray:
                #expect(mapped == .systemGray)
            case .pink:
                #expect(mapped == .systemPink)
            }
        }
    }
}
#endif
