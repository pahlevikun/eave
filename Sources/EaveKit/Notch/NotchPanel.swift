#if canImport(AppKit)
import AppKit
import EaveCore
import SwiftUI

/// Panel under the notch that lists overflowed tray items.
@MainActor
public final class NotchPanel {
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var plan: NotchTrayModel.Plan = .init(kept: [], overflowed: [])

    public var isOpen: Bool { panel != nil }

    public init() {}

    public func open(plan: NotchTrayModel.Plan, on screen: NSScreen) {
        self.plan = plan
        close()

        let frame = panelFrame(on: screen)
        let panel = NotchPanelWindow(contentRect: frame)
        panel.contentView = NSHostingView(rootView: NotchTrayView(plan: plan))
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        installOutsideClickMonitor()
    }

    public func close() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        panel?.close()
        panel = nil
    }

    public func toggle(plan: NotchTrayModel.Plan, on screen: NSScreen) {
        if isOpen {
            close()
        } else {
            open(plan: plan, on: screen)
        }
    }

    private func panelFrame(on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let auxLeft = screen.auxiliaryTopLeftArea?.width ?? 0
        let auxRight = screen.auxiliaryTopRightArea?.width ?? 0
        let notchWidth = NotchGeometry.width(
            screenWidth: screenFrame.width,
            auxLeftWidth: auxLeft,
            auxRightWidth: auxRight
        )
        let safeTop = screen.safeAreaInsets.top
        let isNotched = safeTop > 0
        let height = NotchGeometry.height(
            safeAreaTop: safeTop,
            isNotched: isNotched,
            menuBarThickness: NSStatusBar.system.thickness
        )
        let notchMaxX = screenFrame.minX + auxLeft + notchWidth
        let width = max(notchWidth, 120)
        let originX = notchMaxX - width / 2
        let originY = screenFrame.maxY - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func installOutsideClickMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }
}

private final class NotchPanelWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .mainMenu + 3
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isOpaque = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
#endif
