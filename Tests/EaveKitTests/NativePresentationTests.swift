#if canImport(AppKit)
import AppKit
import EaveCore
import Testing
@testable import EaveKit

@Suite("Native presentation state", .serialized)
@MainActor
struct NativePresentationTests {
    @Test func cachedTouchBarButtonEnablesWhenURLAppears() throws {
        _ = NSApplication.shared
        let presenter = TouchBarPresenter()
        presenter.update(scriptItems: [ScriptItem(title: "same", namespace: "fixture")])
        let bar = try #require(presenter.touchBar)
        let identifier = NSTouchBarItem.Identifier("fixture:same")
        let before = try #require(bar.item(forIdentifier: identifier) as? NSCustomTouchBarItem)
        let button = try #require(before.view as? NSButton)
        #expect(button.isEnabled == false)

        presenter.update(scriptItems: [ScriptItem(title: "same", namespace: "fixture", parameters: ["href": "https://example.invalid"])])

        #expect(bar.item(forIdentifier: identifier) === before)
        #expect(button.isEnabled)
    }

    @Test func cachedTouchBarButtonDisablesWhenURLDisappears() throws {
        _ = NSApplication.shared
        let presenter = TouchBarPresenter()
        presenter.update(scriptItems: [ScriptItem(title: "same", namespace: "fixture", parameters: ["href": "https://example.invalid"])])
        let bar = try #require(presenter.touchBar)
        let identifier = NSTouchBarItem.Identifier("fixture:same")
        let before = try #require(bar.item(forIdentifier: identifier) as? NSCustomTouchBarItem)
        let button = try #require(before.view as? NSButton)
        #expect(button.isEnabled)

        presenter.update(scriptItems: [ScriptItem(title: "same", namespace: "fixture")])

        #expect(bar.item(forIdentifier: identifier) === before)
        #expect(button.isEnabled == false)
    }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    private func layout(_ panel: NSPanel) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func overflowFixture() throws -> (NSPanel, NotchTrayModel.Plan, NSScrollView) {
        _ = NSApplication.shared
        let plan = NotchTrayModel.Plan(kept: [], overflowed: (0..<30).map { index in
            let title = "Overflow title \(index)"
            let scriptItem = ScriptItem(title: title, namespace: "row\(index)")
            return NotchTrayItem(id: "row\(index)", title: title, width: 100, scriptItem: scriptItem)
        })
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 360),
                            styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        NotchPanel.updateContent(of: panel, plan: plan)
        layout(panel)
        let scroll = try #require(scrollView(in: panel.contentView!))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(scroll.contentView.bounds.origin.y == 120)
        return (panel, plan, scroll)
    }

    @Test func unchangedOverflowPlanPreservesNativeScroll() throws {
        let (panel, plan, before) = try overflowFixture()
        defer { panel.close() }
        let hostingView = panel.contentView
        NotchPanel.updateContent(of: panel, plan: plan)
        layout(panel)
        let after = try #require(scrollView(in: panel.contentView!))
        #expect(panel.contentView === hostingView)
        #expect(after === before)
        #expect(after.contentView.bounds.origin.y == 120)
    }

    @Test func changedOverflowPlanRetainsScrollForSurvivingItems() throws {
        let (panel, plan, before) = try overflowFixture()
        defer { panel.close() }
        let oldHeight = try #require(before.documentView).frame.height
        let changed = NotchTrayModel.Plan(kept: [], overflowed: plan.overflowed + [
            NotchTrayItem(
                id: "new",
                title: "New overflow title",
                width: 100,
                scriptItem: ScriptItem(title: "New overflow title", namespace: "new")
            ),
        ])
        NotchPanel.updateContent(of: panel, plan: changed)
        layout(panel)
        let after = try #require(scrollView(in: panel.contentView!))
        #expect(after === before)
        #expect(after.contentView.bounds.origin.y == 120)
        #expect(try #require(after.documentView).frame.height > oldHeight)
    }

    @Test func reducedMotionOpensAtFinalOpacityAndGeometry() {
        _ = NSApplication.shared
        let frame = NSRect(x: 40, y: 50, width: 280, height: 180)
        let panel = NSPanel(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }

        NotchPanel.present(panel, reduceMotion: true)

        #expect(panel.alphaValue == 1)
        #expect(panel.frame == frame)
        #expect(panel.isVisible)
    }

    @Test func openingFadeReachesFinalOpacityWithoutMovingThePanel() async throws {
        _ = NSApplication.shared
        let frame = NSRect(x: 40, y: 50, width: 280, height: 180)
        let panel = NSPanel(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }

        NotchPanel.present(panel, reduceMotion: false)
        try await Task.sleep(for: .milliseconds(160))

        #expect(panel.alphaValue == 1)
        #expect(panel.frame == frame)
    }

}
#endif
