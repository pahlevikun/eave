import Foundation
import Testing
@testable import EaveCore

@Suite("NotchTrayModel")
struct NotchTrayModelTests {
    private func item(_ id: String, width: CGFloat) -> NotchTrayItem {
        let scriptItem = ScriptItem(title: id, namespace: id)
        return NotchTrayItem(id: id, title: id, width: width, scriptItem: scriptItem)
    }

    @Test func everythingFits() {
        let items = [item("a", width: 20), item("b", width: 30)]
        let plan = NotchTrayModel.plan(items: items, availableWidth: 100)
        #expect(plan.kept == items)
        #expect(plan.overflowed.isEmpty)
    }

    @Test func crossingLimitOverflowsRest() {
        let items = [item("a", width: 40), item("b", width: 40), item("c", width: 10)]
        let plan = NotchTrayModel.plan(items: items, availableWidth: 70)
        #expect(plan.kept == [items[0]])
        #expect(plan.overflowed == [items[1], items[2]])
    }

    @Test func nonPositiveWidthOverflowsAll() {
        let items = [item("a", width: 10)]
        let plan = NotchTrayModel.plan(items: items, availableWidth: 0)
        #expect(plan.kept.isEmpty)
        #expect(plan.overflowed == items)
    }

    @Test func nonFiniteWidthOverflowsAll() {
        let items = [item("a", width: 10)]
        let plan = NotchTrayModel.plan(items: items, availableWidth: .infinity)
        #expect(plan.kept.isEmpty)
        #expect(plan.overflowed == items)
    }

    @Test func emptyInput() {
        let plan = NotchTrayModel.plan(items: [], availableWidth: 200)
        #expect(plan.kept.isEmpty)
        #expect(plan.overflowed.isEmpty)
    }

    @Test func keptPreservesInputOrder() {
        let items = [item("first", width: 10), item("second", width: 10), item("third", width: 10)]
        let plan = NotchTrayModel.plan(items: items, availableWidth: 25)
        #expect(plan.kept.map(\.id) == ["first", "second"])
        #expect(plan.overflowed.map(\.id) == ["third"])
    }
}
