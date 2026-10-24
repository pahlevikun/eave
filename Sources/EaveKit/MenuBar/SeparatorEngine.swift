#if canImport(AppKit)
import AppKit
import EaveCore

/// One status item whose length hides everything to its left.
@MainActor
public final class SeparatorEngine {
    private let onExpand: @MainActor () -> Void
    private let autosaveName = "com.eave.hide.separator"
    private var statusItem: NSStatusItem?
    private var isCollapsed = false
    private var screenObserver: NSObjectProtocol?

    public init(onExpand: @escaping @MainActor () -> Void = {}) {
        self.onExpand = onExpand
    }

    public var collapsed: Bool { isCollapsed }

    public func startObserving() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isCollapsed else { return }
                self.statusItem?.length = self.collapsedLength()
            }
        }
    }

    /// The engine lives for the lifetime of the app; call this on quit rather than implicit teardown.
    public func stopObserving() {
        guard let screenObserver else { return }
        NotificationCenter.default.removeObserver(screenObserver)
        self.screenObserver = nil
    }

    public func toggleCollapsed() {
        if isCollapsed {
            expand()
        } else {
            collapse()
        }
    }

    private func collapse() {
        ensureStatusItem()
        isCollapsed = true
        statusItem?.length = collapsedLength()
        startObserving()
    }

    private func expand() {
        ensureStatusItem()
        isCollapsed = false
        statusItem?.length = 1
        onExpand()
    }

    private func ensureStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: 1)
        item.autosaveName = autosaveName
        statusItem = item
    }

    private func collapsedLength() -> CGFloat {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 0
        return SeparatorWidth.collapsed(widestScreenWidth: widest)
    }

    /// Call before dropping the item so AppKit can restore its saved slot later.
    public func tearDown() {
        guard let item = statusItem else { return }
        let savedName = item.autosaveName
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        if let savedName {
            let replacement = NSStatusBar.system.statusItem(withLength: 1)
            replacement.autosaveName = savedName
            NSStatusBar.system.removeStatusItem(replacement)
        }
    }
}
#endif
