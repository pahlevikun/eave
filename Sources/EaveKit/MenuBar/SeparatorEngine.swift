#if canImport(AppKit)
import AppKit
import EaveCore

/// One status item whose length hides everything to its left.
@MainActor
public final class SeparatorEngine {
    private let onExpand: () -> Void
    private let autosaveName = "com.eave.hide.separator"
    private var statusItem: NSStatusItem?
    private var isCollapsed = false
    private var screenObserver: NSObjectProtocol?

    public init(onExpand: @escaping () -> Void = {}) {
        self.onExpand = onExpand
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    public var collapsed: Bool { isCollapsed }

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
        observeScreenChangesIfNeeded()
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

    private func observeScreenChangesIfNeeded() {
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
