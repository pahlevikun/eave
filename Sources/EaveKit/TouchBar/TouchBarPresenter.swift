#if canImport(AppKit)
import AppKit
import EaveCore

@MainActor
public final class TouchBarPresenter: NSResponder {
    public static let maxVisibleEntries = 14

    private let touchBar = NSTouchBar()
    private var lastEntries: [TouchBarEntry] = []
    private var hrefByID: [String: String] = [:]
    public var isEnabled = true {
        didSet { refreshBar() }
    }

    public init() {
        super.init()
        touchBar.defaultItemIdentifiers = []
        touchBar.principalItemIdentifier = .principalLabel
        touchBar.delegate = self
    }

    public func install() {
        NSApp?.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        if NSApp?.mainWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: true
            )
            window.isReleasedWhenClosed = false
            window.orderOut(nil)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp?.mainWindow?.makeFirstResponder(self)
    }

    public func update(scriptItems: [ScriptItem]) {
        guard isEnabled else {
            clearIfNeeded()
            return
        }

        let built = Self.entries(from: scriptItems)
        let plan = TouchBarPlan.plan(
            entries: built.entries,
            maxVisible: Self.maxVisibleEntries,
            widthOfEntry: Self.estimatedWidth
        )
        hrefByID = built.hrefByID
        apply(plan.shown)
    }

    public func clearIfNeeded() {
        hrefByID = [:]
        apply([])
    }

    private func apply(_ entries: [TouchBarEntry]) {
        guard entries != lastEntries else { return }
        lastEntries = entries
        refreshBar()
    }

    private func refreshBar() {
        let identifiers: [NSTouchBarItem.Identifier]
        if isEnabled, !lastEntries.isEmpty {
            identifiers = [.principalLabel] + lastEntries.map { NSTouchBarItem.Identifier($0.id) }
        } else {
            identifiers = [.principalLabel]
            lastEntries = []
        }
        touchBar.defaultItemIdentifiers = identifiers
        NSApp?.mainWindow?.touchBar = touchBar
    }

    private static func entries(from items: [ScriptItem]) -> (
        entries: [TouchBarEntry],
        hrefByID: [String: String]
    ) {
        var result: [TouchBarEntry] = []
        var hrefs: [String: String] = [:]
        for item in items {
            let isSpacer = item.parameters["spacer"] == "true" || item.title == "|"
            let entry = TouchBarEntry(id: item.id, title: item.title, isSpacer: isSpacer)
            result.append(entry)
            if let href = item.parameters["href"] {
                hrefs[entry.id] = href
            }
        }
        return (result, hrefs)
    }

    private static func estimatedWidth(for entry: TouchBarEntry) -> Double {
        if entry.isSpacer { return 16 }
        return max(48, Double(entry.title.count) * 8 + 24)
    }
}

extension TouchBarPresenter: NSTouchBarDelegate {
    public func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        if identifier == .principalLabel {
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSTextField(labelWithString: "Eave")
            return item
        }
        guard let entry = lastEntries.first(where: { $0.id == identifier.rawValue }) else {
            return nil
        }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: entry.title, target: self, action: #selector(touchBarButtonPressed(_:)))
        button.bezelStyle = .texturedRounded
        button.identifier = NSUserInterfaceItemIdentifier(entry.id)
        if hrefByID[entry.id] == nil {
            button.isEnabled = false
        }
        item.view = button
        return item
    }

    @objc private func touchBarButtonPressed(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let href = hrefByID[id],
              let url = URL(string: href)
        else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension NSTouchBarItem.Identifier {
    static let principalLabel = NSTouchBarItem.Identifier("com.eave.touchbar.principal")
}
#endif
