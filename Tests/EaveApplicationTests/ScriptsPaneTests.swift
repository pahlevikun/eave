import AppKit
import EaveCore
import Testing
@testable import EaveApplication

@Suite("Scripts native state", .serialized)
@MainActor
struct ScriptsPaneTests {
    private let plugin = Plugin(filename: "fixture.5s.sh", path: "/unused/fixture.5s.sh", interval: .default)

    private func descendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { descendant(of: type, in: $0) }.first
    }

    private func fixture() throws -> (NSWindow, ScriptsPane, NSTableView, NSTextView, PluginDiagnostics) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let pane = ScriptsPane(frame: window.contentView!.bounds)
        window.contentView = pane
        pane.layoutSubtreeIfNeeded()
        let table = try #require(descendant(of: NSTableView.self, in: pane))
        let detail = try #require(descendant(of: NSTextView.self, in: pane))
        let diagnostics = PluginDiagnostics(
            finishedAt: Date(timeIntervalSince1970: 1_700_000_000), exitCode: 7,
            stderr: (0..<45).map { "diagnostic line \($0)" }.joined(separator: "\n"),
            outputTruncated: false, failure: .exitedNonZero(code: 7, stderr: "failure")
        )
        pane.update(rows: [.init(plugin: plugin, diagnostics: diagnostics, running: false)])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        detail.layoutManager?.ensureLayout(for: detail.textContainer!)
        return (window, pane, table, detail, diagnostics)
    }

    @Test func periodicRefreshPreservesDiagnosticSelectionAndScroll() throws {
        let (window, pane, table, detail, diagnostics) = try fixture()
        defer { window.close() }
        let selection = (detail.string as NSString).range(of: "diagnostic line 12")
        detail.setSelectedRange(selection)
        let scroll = try #require(detail.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 100))
        let offset = scroll.contentView.bounds.origin
        #expect(offset.y > 0)
        let document = detail.string

        pane.update(rows: [.init(plugin: plugin, diagnostics: diagnostics, running: false)])

        #expect(table.selectedRow == 0)
        #expect(detail.selectedRange() == selection)
        #expect(scroll.contentView.bounds.origin == offset)
        #expect(detail.string == document)
        #expect(!detail.string.contains("ago"))
    }

    @Test func changedDiagnosticsPreserveValidSelectionAndScroll() throws {
        let (window, pane, _, detail, old) = try fixture()
        defer { window.close() }
        let selection = (detail.string as NSString).range(of: "diagnostic line 12")
        detail.setSelectedRange(selection)
        let scroll = try #require(detail.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 100))
        let offset = scroll.contentView.bounds.origin
        var updated = old
        updated.failure = .timedOut(seconds: 5)
        updated.outputTruncated = true

        pane.update(rows: [.init(plugin: plugin, diagnostics: updated, running: false)])

        #expect(detail.selectedRange() == selection)
        #expect(scroll.contentView.bounds.origin == offset)
        #expect(detail.string.contains("timeout after 5s"))
        #expect(detail.string.contains("output cut at 1 MB"))
        #expect(detail.string.contains("Exit code 7"))
        #expect(detail.string.contains(updated.finishedAt.formatted()))
    }

    @Test func shorterDiagnosticsClampSelectionAndScroll() throws {
        let (window, pane, _, detail, old) = try fixture()
        defer { window.close() }
        detail.setSelectedRange((detail.string as NSString).range(of: "diagnostic line 40"))
        let scroll = try #require(detail.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        var updated = old
        updated.stderr = "short"

        pane.update(rows: [.init(plugin: plugin, diagnostics: updated, running: false)])

        let length = (detail.string as NSString).length
        #expect(detail.selectedRange() == NSRange(location: length, length: 0))
        #expect(scroll.contentView.bounds.origin.y <= max(0, detail.bounds.height - scroll.contentView.bounds.height))
    }

    private func descendants<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    @Test func firstScriptPathHasOneInstructionAndNoEmptyDiagnostics() throws {
        let (window, pane, table, detail, _) = try fixture()
        defer { window.close() }

        pane.update(rows: [])
        pane.layoutSubtreeIfNeeded()

        #expect(table.isHiddenOrHasHiddenAncestor)
        #expect(detail.isHiddenOrHasHiddenAncestor)
        let labels = descendants(of: NSTextField.self, in: pane).filter { !$0.isHiddenOrHasHiddenAncestor }
        #expect(labels.contains { $0.stringValue.contains("clock.5s.sh") })
        let buttons = descendants(of: NSButton.self, in: pane)
        #expect(buttons.contains { $0.title == "Open Scripts Folder" && !$0.isHiddenOrHasHiddenAncestor })
        #expect(!buttons.contains { $0.title == "Retry scan" && !$0.isHiddenOrHasHiddenAncestor })
    }

    @Test func completeRecoveryCanBeReadWithoutLosingTheSelectedScript() throws {
        let (window, pane, table, detail, diagnostics) = try fixture()
        defer { window.close() }
        let rows = [ScriptsPane.Row(plugin: plugin, diagnostics: diagnostics, running: false)]
        let error = "Scripts Folder could not be read. Check folder access and try again."
        let rejections = (0..<60).map { "duplicate-\($0).5s.sh was rejected because its name conflicts." }.joined(separator: "\n")
        pane.update(rows: rows, scanError: error, rejection: rejections)
        let button = try #require(descendants(of: NSButton.self, in: pane).first { $0.title == "Show scan details" })

        button.performClick(nil)
        pane.layoutSubtreeIfNeeded()
        #expect(detail.string == error + "\n\n" + rejections)
        #expect(detail.isSelectable)
        #expect(detail.accessibilityLabel() == "Scan details")
        #expect(window.firstResponder === detail)
        #expect(table.selectedRow == 0)
        let selection = (detail.string as NSString).range(of: "duplicate-12.5s.sh")
        detail.setSelectedRange(selection)
        let scroll = try #require(detail.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 100))
        let origin = scroll.contentView.bounds.origin
        #expect(origin.y > 0)

        pane.update(rows: rows, scanError: error, rejection: rejections)

        #expect(detail.selectedRange() == selection)
        #expect(scroll.contentView.bounds.origin == origin)
        #expect(detail.string.hasSuffix("duplicate-59.5s.sh was rejected because its name conflicts."))
        button.performClick(nil)
        #expect(detail.accessibilityLabel() == "Last run details")
        #expect(detail.string.contains("diagnostic line 44"))
        #expect(table.selectedRow == 0)
        pane.update(rows: rows)
        #expect(button.isHiddenOrHasHiddenAncestor)
        #expect(!detail.string.contains("was rejected"))
    }

    @Test func emptyRecoveryShowsCompleteScanDetailsAndCollapsesAfterSuccess() throws {
        let (window, pane, _, detail, _) = try fixture()
        defer { window.close() }
        let error = "Unable to read Scripts Folder. " + String(repeating: "Long recovery instruction. ", count: 30)
        pane.update(rows: [], scanError: error)
        pane.layoutSubtreeIfNeeded()

        #expect(!detail.isHiddenOrHasHiddenAncestor)
        #expect(detail.string == error)
        let retry = try #require(descendants(of: NSButton.self, in: pane).first { $0.title == "Retry scan" })
        #expect(!retry.isHiddenOrHasHiddenAncestor)
        #expect(retry.action.map(NSStringFromSelector) == "retryScan")

        pane.update(rows: [])

        #expect(detail.isHiddenOrHasHiddenAncestor)
        #expect(retry.isHiddenOrHasHiddenAncestor)
    }

}
