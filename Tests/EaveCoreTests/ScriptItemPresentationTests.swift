import EaveCore
import Testing

@Suite struct ScriptItemPresentationTests {
    private func item(parameters: [String: String] = [:]) -> ScriptItem {
        ScriptItem(title: "row", namespace: "demo", parameters: parameters)
    }

    @Test func noParametersUsesDefaults() {
        let presentation = item().presentation
        #expect(presentation.length == nil)
        #expect(presentation.showsDropdown)
        #expect(presentation.shortcut == nil)
        #expect(presentation.refreshesAfterAction == false)
    }

    @Test func lengthEighty() {
        #expect(item(parameters: ["length": "80"]).presentation.length == 80)
    }

    @Test func lengthZeroIsNil() {
        #expect(item(parameters: ["length": "0"]).presentation.length == nil)
    }

    @Test func lengthNonNumericIsNil() {
        #expect(item(parameters: ["length": "abc"]).presentation.length == nil)
        #expect(item(parameters: ["length": "-5"]).presentation.length == nil)
    }

    @Test func lengthAboveCapIsNil() {
        #expect(item(parameters: ["length": "501"]).presentation.length == nil)
    }

    @Test func dropdownFalseDisablesMenu() {
        #expect(item(parameters: ["dropdown": "false"]).presentation.showsDropdown == false)
        #expect(item(parameters: ["dropdown": "no"]).presentation.showsDropdown)
    }

    @Test func shortcutCommandR() {
        let shortcut = item(parameters: ["shortcut": "cmd+r"]).presentation.shortcut
        #expect(shortcut?.key == "r")
        #expect(shortcut?.modifiers.contains(.command) == true)
        #expect(shortcut?.modifiers.contains(.shift) == false)
    }

    @Test func shortcutCommandShiftR() {
        let shortcut = item(parameters: ["shortcut": "cmd+shift+r"]).presentation.shortcut
        #expect(shortcut?.key == "r")
        #expect(shortcut?.modifiers.contains(.command) == true)
        #expect(shortcut?.modifiers.contains(.shift) == true)
    }

    @Test func shortcutBareKey() {
        let shortcut = item(parameters: ["shortcut": "x"]).presentation.shortcut
        #expect(shortcut?.key == "x")
        #expect(shortcut?.modifierFlags == 0)
    }

    @Test func shortcutUnknownModifierIsNil() {
        #expect(item(parameters: ["shortcut": "hyper+x"]).presentation.shortcut == nil)
    }

    @Test func shortcutTrailingPlusIsNil() {
        #expect(item(parameters: ["shortcut": "cmd+"]).presentation.shortcut == nil)
    }

    @Test func refreshTrueOnly() {
        #expect(item(parameters: ["refresh": "true"]).presentation.refreshesAfterAction)
        #expect(item(parameters: ["refresh": "yes"]).presentation.refreshesAfterAction == false)
    }

    @Test func caseInsensitiveFlags() {
        let dropdown = item(parameters: ["dropdown": "FALSE"]).presentation
        #expect(dropdown.showsDropdown == false)

        let refresh = item(parameters: ["refresh": "TRUE"]).presentation
        #expect(refresh.refreshesAfterAction)

        let shortcut = item(parameters: ["shortcut": "CMD+R"]).presentation.shortcut
        #expect(shortcut?.key == "r")
        #expect(shortcut?.modifiers.contains(.command) == true)
    }

    @Test func whitespacePaddingIsTrimmed() {
        let presentation = item(parameters: [
            "length": "  80 ",
            "dropdown": " false ",
            "refresh": " true ",
            "shortcut": " cmd + r ",
        ]).presentation
        #expect(presentation.length == 80)
        #expect(presentation.showsDropdown == false)
        #expect(presentation.refreshesAfterAction)
        #expect(presentation.shortcut?.key == "r")
        #expect(presentation.shortcut?.modifiers.contains(.command) == true)
    }
}
