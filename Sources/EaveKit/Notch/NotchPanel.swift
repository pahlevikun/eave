#if canImport(AppKit)
import AppKit
import EaveCore
import SwiftUI

@MainActor
public final class NotchPanel {
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private let onClose: () -> Void

    public var isOpen: Bool { panel != nil }
    public init(onClose: @escaping () -> Void = {}) { self.onClose = onClose }

    public func open(plan: NotchTrayModel.Plan, on screen: NSScreen) {
        close()
        let panel = OverflowPanelWindow(
            contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        self.panel = panel
        update(plan: plan, on: screen)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.close()
                return nil
            }
            if event.type != .keyDown, event.window !== self.panel { self.close() }
            return event
        }
        Self.present(panel, reduceMotion: ActionDispatcher.accessibilityDisplayShouldReduceMotion)
    }

    static func present(_ panel: NSPanel, reduceMotion: Bool) {
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        guard !reduceMotion else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }
        // Visibility must not depend on the compositor delivering an animation frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak panel] in
            guard let panel, panel.isVisible else { return }
            panel.alphaValue = 1
        }
    }

    public func update(plan: NotchTrayModel.Plan, on screen: NSScreen) {
        guard let panel else { return }
        var notch: PanelRect?
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = PanelRect(x: left.maxX, y: screen.frame.maxY - screen.safeAreaInsets.top,
                           width: max(0, right.minX - left.maxX), height: screen.safeAreaInsets.top)
        }
        let frame = NotchPanelGeometry.frame(
            screen: Self.rect(screen.frame), visibleFrame: Self.rect(screen.visibleFrame), notch: notch,
            menuBarHeight: NSStatusBar.system.thickness,
            contentHeight: CGFloat(max(1, plan.overflowed.count) * 32 + 100)
        )
        Self.updateContent(of: panel, plan: plan)
        panel.setFrame(NSRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height), display: true)
    }

    static func updateContent(of panel: NSPanel, plan: NotchTrayModel.Plan) {
        if let content = panel.contentView as? NSHostingView<NotchTrayView> {
            if content.rootView.plan != plan { content.rootView = NotchTrayView(plan: plan) }
        } else {
            panel.contentView = NSHostingView(rootView: NotchTrayView(plan: plan))
        }
    }

    private static func rect(_ frame: NSRect) -> PanelRect {
        PanelRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    public func close() {
        let wasOpen = isOpen
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        panel?.close()
        panel = nil
        if wasOpen { onClose() }
    }

    public func toggle(plan: NotchTrayModel.Plan, on screen: NSScreen) {
        if isOpen { close() } else { open(plan: plan, on: screen) }
    }
}
private final class OverflowPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
#endif
