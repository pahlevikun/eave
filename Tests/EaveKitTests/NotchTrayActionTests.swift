#if canImport(AppKit)
import AppKit
import EaveCore
import SwiftUI
import Testing
@testable import EaveKit

@Suite("Notch tray actions", .serialized)
@MainActor
struct NotchTrayActionTests {
    private func host<V: View>(_ view: V, size: NSSize = NSSize(width: 248, height: 32)) -> NSHostingView<V> {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    private func findButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let found = findButton(in: subview) { return found }
        }
        return nil
    }

    @Test func hrefRowExposesEnabledControl() throws {
        _ = NSApplication.shared
        let item = ScriptItem(
            title: "Link",
            namespace: "clock",
            parameters: ["href": "https://example.com"]
        )
        let view = host(NotchTrayRow(item: item, isSelected: false, perform: { _ in true }))
        let button = try #require(findButton(in: view))
        #expect(button.isEnabled)
    }

    @Test func noActionRowIsDisabled() throws {
        _ = NSApplication.shared
        let item = ScriptItem(title: "Plain", namespace: "clock")
        let view = host(NotchTrayRow(item: item, isSelected: false, perform: { _ in true }))
        let button = try #require(findButton(in: view))
        #expect(button.isEnabled == false)
    }

    @Test func bashRowIsDisabledAndDoesNotRun() throws {
        _ = NSApplication.shared
        var performed = false
        let item = ScriptItem(
            title: "Shell",
            namespace: "clock",
            parameters: ["bash": "echo hi", "href": "https://example.com"]
        )
        let view = host(NotchTrayRow(item: item, isSelected: false, perform: { _ in
            performed = true
            return true
        }))
        let button = try #require(findButton(in: view))
        #expect(button.isEnabled == false)
        button.performClick(nil)
        #expect(performed == false)
    }

    @Test func activatingEnabledRowCallsDispatcherOnce() throws {
        _ = NSApplication.shared
        var callCount = 0
        let item = ScriptItem(
            title: "Link",
            namespace: "clock",
            parameters: ["href": "https://example.com"]
        )
        let view = host(
            NotchTrayRow(item: item, isSelected: true, perform: { action in
                callCount += 1
                #expect(action == .openURL(URL(string: "https://example.com")!))
                return true
            })
        )
        let button = try #require(findButton(in: view))
        button.performClick(nil)
        #expect(callCount == 1)
    }

    @Test func escapeClosesPanelWithEmptySelection() throws {
        _ = NSApplication.shared
        let plan = NotchTrayModel.Plan(kept: [], overflowed: [])
        var didClose = false
        let notch = NotchPanel { didClose = true }
        let screen = try #require(NSScreen.main ?? NSScreen.screens.first)
        notch.open(plan: plan, on: screen)
        defer { notch.close() }
        #expect(notch.isOpen)
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 53
        )
        let keyEvent = try #require(event)
        NSApp.postEvent(keyEvent, atStart: false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        #expect(didClose)
        #expect(notch.isOpen == false)
    }
}
#endif
