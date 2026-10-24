import Foundation
import Testing
@testable import EaveCore

@Suite("TouchBarPlan")
struct TouchBarPlanTests {
    private func entry(_ id: String, width: Double = 40) -> TouchBarEntry {
        TouchBarEntry(id: id, title: id)
    }

    private func widthOf(_ entry: TouchBarEntry) -> Double {
        entry.isSpacer ? 8 : 40
    }

    @Test func underCapNothingOverflows() {
        let entries = [entry("a"), entry("b")]
        let plan = TouchBarPlan.plan(entries: entries, maxVisible: 3, widthOfEntry: widthOf)
        #expect(plan.overflowed.isEmpty)
        #expect(plan.shown.map(\.id) == ["a", "b"])
    }

    @Test func overCapTailOverflowsInOrder() {
        let entries = [entry("a"), entry("b"), entry("c"), entry("d")]
        let plan = TouchBarPlan.plan(entries: entries, maxVisible: 2, widthOfEntry: widthOf)
        #expect(plan.shown.map(\.id) == ["a", "b"])
        #expect(plan.overflowed.map(\.id) == ["c", "d"])
    }

    @Test func spacersDoNotConsumeCap() {
        let spacer = TouchBarEntry(id: "s", title: "|", isSpacer: true)
        let entries = [entry("a"), spacer, entry("b"), entry("c")]
        let plan = TouchBarPlan.plan(entries: entries, maxVisible: 2, widthOfEntry: widthOf)
        #expect(plan.shown.map(\.id) == ["a", "s", "b"])
        #expect(plan.overflowed.map(\.id) == ["c"])
    }

    @Test func maxVisibleZeroOverflowsNonSpacersKeepsSpacersShown() {
        let spacer = TouchBarEntry(id: "s", title: "|", isSpacer: true)
        let entries = [spacer, entry("a"), entry("b")]
        let plan = TouchBarPlan.plan(entries: entries, maxVisible: 0, widthOfEntry: widthOf)
        #expect(plan.shown.map(\.id) == ["s"])
        #expect(plan.overflowed.map(\.id) == ["a", "b"])
    }

    @Test func usedWidthSumsShownEntries() {
        let entries = [entry("a"), TouchBarEntry(id: "s", title: "|", isSpacer: true)]
        let plan = TouchBarPlan.plan(entries: entries, maxVisible: 5, widthOfEntry: widthOf)
        #expect(plan.usedWidth == 48)
    }
}
