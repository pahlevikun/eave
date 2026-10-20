import Testing
@testable import EaveCore

@Suite("XbarParser")
struct XbarParserTests {
    @Test func parsesTitleWithParams() {
        let items = XbarParser.parse("14:22 | color=#ffffff\n---\nRefresh | href=xbar://refresh", namespace: "clock")
        #expect(items.count == 1)
        #expect(items[0].title == "14:22")
        #expect(items[0].parameters["color"] == "#ffffff")
    }

    @Test func dropdownChildrenAreAttached() {
        let items = XbarParser.parse("CPU 12%\n---\nDetails\ntop", namespace: "cpu")
        #expect(items.count == 1)
        #expect(items[0].children.count == 2)
        #expect(items[0].children[0].title == "Details")
    }

    @Test func countsSubmenuDepth() {
        #expect(XbarParser.stripDashes("Item").depth == 0)
        #expect(XbarParser.stripDashes("-- Child").depth == 1)
        #expect(XbarParser.stripDashes("---- GreatGrandchild").depth == 2)
    }

    @Test func nestedChildLandsInParent() {
        let items = XbarParser.parse("T\n---\nA\n-- A1\n-- A2\nB", namespace: "ns")
        let children = items[0].children
        #expect(children.count == 2)
        #expect(children[0].title == "A")
        #expect(children[0].children.map(\.title) == ["A1", "A2"])
        #expect(children[1].title == "B")
    }

    @Test func topLevelItemKeepsDropdownAtDepthZero() {
        let items = XbarParser.parse("T\n---\nPlain\n-- Nested", namespace: "ns")
        #expect(items[0].children.count == 1)
        #expect(items[0].children[0].title == "Plain")
        #expect(items[0].children[0].children.map(\.title) == ["Nested"])
    }

    @Test func splitsSpaceSeparatedParams() {
        let (title, params) = XbarParser.splitParams("CPU 12% | font=Menlo size=12")
        #expect(title == "CPU 12%")
        #expect(params["font"] == "Menlo")
        #expect(params["size"] == "12")
    }

    @Test func supportsQuotedValuesWithSpaces() {
        let (_, params) = XbarParser.splitParams("x | bash=\"/bin/sh\" label='hello world'")
        #expect(params["bash"] == "/bin/sh")
        #expect(params["label"] == "hello world")
    }

    @Test func titleWithPipeInItKeepsFirstSegment() {
        let (title, params) = XbarParser.splitParams("a | b | key=val")
        #expect(title == "a")
        #expect(params["key"] == "val")
    }

    @Test func ignoresBlankLinesAndTrailingPipe() {
        let items = XbarParser.parse("\n\nHi |\n\n", namespace: "ns")
        #expect(items.count == 1)
        #expect(items[0].title == "Hi")
        #expect(items[0].parameters.isEmpty)
    }

    @Test func paramWithoutEqualsIsIgnored() {
        let (_, params) = XbarParser.splitParams("x | junk ok=1")
        #expect(params.count == 1)
        #expect(params["ok"] == "1")
    }

    @Test func deepChildOnEmptyRootDoesNotCrash() {
        let items = XbarParser.parse("T\n---\n-- Orphan", namespace: "ns")
        #expect(items.count == 1)
        #expect(items[0].children.count == 1)
        #expect(items[0].children[0].title == "Orphan")
    }
}

@Suite("ScriptItem")
struct ScriptItemTests {
    @Test func idIsStableAcrossRefreshes() {
        let a = ScriptItem(title: "CPU 12%", namespace: "cpu")
        let b = ScriptItem(title: "CPU 12%", namespace: "cpu", parameters: ["x": "1"])
        #expect(a.id == b.id)
    }
}
