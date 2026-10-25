import Testing
@testable import EaveCore

@Suite("AnsiText")
struct AnsiTextTests {
    @Test func stripsSGRColour() {
        let input = "\u{1B}[31mred\u{1B}[0m"
        #expect(AnsiText.strip(input) == "red")
    }

    @Test func stripsNestedAndInlineCodes() {
        let input = "\u{1B}[1mbo\u{1B}[31mld\u{1B}[0m"
        #expect(AnsiText.strip(input) == "bold")
    }

    @Test func stripsOSCTitleSequence() {
        let input = "\u{1B}]0;hello\u{07}text"
        #expect(AnsiText.strip(input) == "text")
    }

    @Test func removesLoneEscapeAtEnd() {
        #expect(AnsiText.strip("ok\u{1B}") == "ok")
    }

    @Test func leavesPlainTextUntouched() {
        let input = "plain [brackets] and $HOME"
        #expect(AnsiText.strip(input) == input)
    }

    @Test func stripAndFirstLineKeepsLeadingLine() {
        let input = "14:22\nsecond line"
        #expect(AnsiText.stripAndFirstLine(input) == "14:22")
    }

    @Test func stripAndFirstLineEmptyString() {
        #expect(AnsiText.stripAndFirstLine("") == "")
    }

    @Test func onlyEscapesBecomesEmpty() {
        let input = "\u{1B}[31m\u{1B}[0m"
        #expect(AnsiText.strip(input) == "")
    }
}
