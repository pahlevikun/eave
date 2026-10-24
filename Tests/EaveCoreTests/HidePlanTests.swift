import Testing
@testable import EaveCore

@Suite("HidePlan")
struct HidePlanTests {
    private func member(
        _ id: String,
        movable: Bool = true,
        hideable: Bool = true
    ) -> SectionMembership {
        SectionMembership(id: id, isMovable: movable, isHideable: hideable)
    }

    @Test func withoutAccessibilityUsesSeparatorOnly() {
        let decision = HidePlan.decide(
            members: [member("a"), member("b")],
            hasAccessibility: false
        )
        #expect(decision == .separator)
    }

    @Test func withPermissionAllMovableAndHideable() {
        let decision = HidePlan.decide(
            members: [member("a"), member("b")],
            hasAccessibility: true
        )
        #expect(decision == .separateThenMove(movable: ["a", "b"], skipped: []))
    }

    @Test func notMovableGoesToSkipped() {
        let decision = HidePlan.decide(
            members: [member("a", movable: false)],
            hasAccessibility: true
        )
        #expect(decision == .separateThenMove(movable: [], skipped: ["a"]))
    }

    @Test func notHideableGoesToSkipped() {
        let decision = HidePlan.decide(
            members: [member("a", hideable: false)],
            hasAccessibility: true
        )
        #expect(decision == .separateThenMove(movable: [], skipped: ["a"]))
    }

    @Test func movableOrderFollowsInput() {
        let decision = HidePlan.decide(
            members: [member("z"), member("a"), member("m")],
            hasAccessibility: true
        )
        #expect(decision == .separateThenMove(movable: ["z", "a", "m"], skipped: []))
    }
}
