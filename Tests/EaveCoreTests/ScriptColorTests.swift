import Testing
@testable import EaveCore

@Suite("ScriptColor")
struct ScriptColorTests {
    @Test func redParsesToNamedRed() {
        #expect(ScriptColor.parse("red") == .named(.red))
    }

    @Test func redIsCaseInsensitive() {
        #expect(ScriptColor.parse("Red") == .named(.red))
        #expect(ScriptColor.parse("RED") == .named(.red))
    }

    @Test func greyMapsToGray() {
        #expect(ScriptColor.parse("grey") == .named(.gray))
    }

    @Test func shortHexIsRed() {
        #expect(ScriptColor.parse("#f00") == .rgb(red: 1, green: 0, blue: 0, alpha: 1))
    }

    @Test func shortHexWithoutHash() {
        #expect(ScriptColor.parse("f00") == .rgb(red: 1, green: 0, blue: 0, alpha: 1))
    }

    @Test func longHexMatchesShortRed() {
        #expect(ScriptColor.parse("#FF0000") == .rgb(red: 1, green: 0, blue: 0, alpha: 1))
    }

    @Test func eightDigitHexSetsAlpha() {
        let expected = 128.0 / 255.0
        #expect(ScriptColor.parse("#80FF0000") == .rgb(red: 1, green: 0, blue: 0, alpha: expected))
    }

    @Test func unknownNameReturnsNil() {
        #expect(ScriptColor.parse("chartreuse") == nil)
    }

    @Test func emptyStringReturnsNil() {
        #expect(ScriptColor.parse("") == nil)
        #expect(ScriptColor.parse("   ") == nil)
    }

    @Test func fourDigitHexReturnsNil() {
        #expect(ScriptColor.parse("#RGBA") == nil)
        #expect(ScriptColor.parse("#f0a0") == nil)
    }

    @Test func fiveDigitHexReturnsNil() {
        #expect(ScriptColor.parse("#12345") == nil)
    }

    @Test func scriptItemColorReadsParameter() {
        let plain = ScriptItem(title: "t", namespace: "ns")
        #expect(plain.color == nil)

        let coloured = ScriptItem(
            title: "t",
            namespace: "ns",
            parameters: ["color": "orange"]
        )
        #expect(coloured.color == .named(.orange))
    }
}
