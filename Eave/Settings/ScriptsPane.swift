import AppKit
import Combine
import EaveCore

@MainActor
final class ScriptsPane: SettingsPane, NSTableViewDataSource, NSTableViewDelegate {
    struct Row {
        let plugin: Plugin
        let diagnostics: PluginDiagnostics?
        let running: Bool
        var status: String {
            running ? "Running…" : diagnostics.map { PluginStatusText.describe(diagnostics: $0, now: Date()) } ?? "Waiting for first run"
        }
    }

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let path = NSTextField(labelWithString: "")
    private let notice = NSTextField(labelWithString: "")
    private let noticeRow = NSStackView()
    private let detailGroup = NSStackView()
    private let detailHeading = NSTextField(labelWithString: "Last run details")
    private lazy var runControls = ScriptsRunNowControls(target: self, action: #selector(runNowClicked))
    private let showDetails = NSButton(title: "Show scan details", target: nil, action: nil)
    private enum DetailMode { case lastRun, scan }
    private var detailMode = DetailMode.lastRun
    private var scanDetails = ""
    private let empty = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextView()
    private let retry = NSButton(title: "Retry scan", target: nil, action: nil)
    private var rows: [Row] = []
    private weak var appState: AppState?
    private var observation: AnyCancellable?
    private var timer: Timer?
    private var active = false
    private var refreshGeneration = 0
    private var updatingRows = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let heading = NSTextField(labelWithString: "Your scripts")
        heading.font = SettingsStyle.TypeRole.heading
        let open = NSButton(title: "Open Scripts Folder", target: self, action: #selector(openFolder))
        open.bezelStyle = .rounded
        path.font = SettingsStyle.TypeRole.metadata
        path.textColor = .secondaryLabelColor
        path.isSelectable = true
        path.lineBreakMode = .byTruncatingMiddle
        path.setAccessibilityLabel("Scripts Folder path")
        notice.font = SettingsStyle.TypeRole.metadata
        notice.lineBreakMode = .byTruncatingTail
        notice.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        retry.target = self
        retry.action = #selector(retryScan)
        retry.bezelStyle = .rounded
        showDetails.target = self
        showDetails.action = #selector(toggleDetails)
        showDetails.bezelStyle = .rounded
        showDetails.setContentCompressionResistancePriority(.required, for: .horizontal)
        retry.setContentCompressionResistancePriority(.required, for: .horizontal)
        noticeRow.orientation = .horizontal
        noticeRow.alignment = .centerY
        noticeRow.spacing = SettingsStyle.Metric.related
        for child in [notice, showDetails, retry] { noticeRow.addArrangedSubview(child) }
        table.rowHeight = SettingsStyle.Metric.rowHeight
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.allowsEmptySelection = true
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Installed scripts")
        for (name, width) in [("Name", 260.0), ("Interval", 72.0), ("Status", 180.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
            column.title = name
            column.width = width
            column.minWidth = name == "Name" ? 100 : width
            column.maxWidth = name == "Name" ? 10_000 : width
            column.resizingMask = name == "Name" ? [.autoresizingMask] : []
            table.addTableColumn(column)
        }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        empty.font = SettingsStyle.TypeRole.body
        empty.alignment = .center
        empty.textColor = .secondaryLabelColor
        let list = NSView()
        for child in [scroll, empty] {
            child.translatesAutoresizingMaskIntoConstraints = false
            list.addSubview(child)
        }
        let detailScroll = NSScrollView()
        detailScroll.documentView = detail
        detailScroll.hasVerticalScroller = true
        detailScroll.borderType = .bezelBorder
        detail.isEditable = false
        detail.isSelectable = true
        detail.font = SettingsStyle.TypeRole.diagnostic
        detail.textColor = .labelColor
        detail.backgroundColor = SettingsStyle.color(.detail)
        detail.textContainerInset = NSSize(width: 8, height: 8)
        detail.autoresizingMask = [.width]
        detail.textContainer?.widthTracksTextView = true
        detailHeading.font = SettingsStyle.TypeRole.section
        detailGroup.orientation = .vertical
        detailGroup.alignment = .leading
        detailGroup.spacing = SettingsStyle.Metric.related
        detailGroup.addArrangedSubview(detailHeading)
        runControls.embed(beside: detailScroll, in: detailGroup)
        let body = NSTextField(wrappingLabelWithString: "Executable scripts run automatically at their filename interval.")
        body.font = SettingsStyle.TypeRole.body
        body.textColor = .secondaryLabelColor
        let lower = NSStackView(views: [noticeRow, detailGroup])
        lower.orientation = .vertical
        lower.alignment = .leading
        lower.spacing = SettingsStyle.Metric.related
        for child in [heading, open, path, body, list, lower] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: topAnchor, constant: SettingsStyle.Metric.inset),
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsStyle.Metric.inset),
            open.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            open.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsStyle.Metric.inset),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: open.leadingAnchor, constant: -SettingsStyle.Metric.related),
            body.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: SettingsStyle.Metric.related),
            body.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: open.trailingAnchor),
            path.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 4),
            path.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            path.trailingAnchor.constraint(equalTo: open.trailingAnchor),
            list.topAnchor.constraint(equalTo: path.bottomAnchor, constant: SettingsStyle.Metric.section),
            list.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: open.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: lower.topAnchor, constant: -SettingsStyle.Metric.related),
            scroll.topAnchor.constraint(equalTo: list.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: list.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: list.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: list.trailingAnchor),
            empty.centerYAnchor.constraint(equalTo: list.centerYAnchor),
            empty.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: SettingsStyle.Metric.inset),
            empty.trailingAnchor.constraint(equalTo: list.trailingAnchor, constant: -SettingsStyle.Metric.inset),
            lower.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            lower.trailingAnchor.constraint(equalTo: open.trailingAnchor),
            lower.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SettingsStyle.Metric.inset),
            noticeRow.widthAnchor.constraint(equalTo: lower.widthAnchor),
            detailGroup.widthAnchor.constraint(equalTo: lower.widthAnchor),
            detailScroll.widthAnchor.constraint(equalTo: detailGroup.widthAnchor),
            detailScroll.heightAnchor.constraint(equalToConstant: SettingsStyle.Metric.detailHeight),
        ])
        update(rows: [])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func refreshAppearance() {
        super.refreshAppearance()
        detail.backgroundColor = SettingsStyle.color(.detail)
    }

    func bind(appState: AppState) {
        self.appState = appState
        path.stringValue = appState.pluginsDirectory
        path.toolTip = appState.pluginsDirectory
        observation = appState.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func setActive(_ active: Bool) {
        self.active = active
        timer?.invalidate()
        timer = nil
        refreshGeneration += 1
        guard active else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        guard active, window?.isVisible == true, let appState else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let plugins = appState.plugins
        Task { @MainActor in
            var built: [Row] = []
            for plugin in plugins {
                let diagnostics = await appState.diagnostics(for: plugin)
                let running = await appState.isRunning(plugin)
                built.append(Row(plugin: plugin, diagnostics: diagnostics, running: running))
            }
            guard active, generation == refreshGeneration, appState.plugins == plugins else { return }
            update(rows: built, scanError: appState.scanError, rejection: appState.rejectionFooterText())
        }
    }

    func update(rows: [Row], scanError: String? = nil, rejection: String = "") {
        let selected = self.rows.indices.contains(table.selectedRow) ? self.rows[table.selectedRow].plugin.id : nil
        updatingRows = true
        self.rows = rows
        table.reloadData()
        if let selected, let index = rows.firstIndex(where: { $0.plugin.id == selected }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else { table.deselectAll(nil) }
        updatingRows = false
        scanDetails = [scanError, rejection.isEmpty ? nil : rejection].compactMap { $0 }.joined(separator: "\n\n")
        if scanDetails.isEmpty { detailMode = .lastRun }
        else if rows.isEmpty { detailMode = .scan }
        notice.stringValue = scanError == nil ? "Some scripts were skipped." : "Scripts Folder could not be read."
        notice.toolTip = scanDetails
        notice.textColor = scanError == nil ? .secondaryLabelColor : .systemRed
        retry.isHidden = scanError == nil
        noticeRow.isHidden = scanDetails.isEmpty
        empty.isHidden = !rows.isEmpty
        scroll.isHidden = rows.isEmpty
        if scanError != nil {
            empty.stringValue = "Scripts Folder is unavailable.\nRead the scan details below, then retry when the folder is available."
        } else if !rejection.isEmpty {
            empty.stringValue = "No runnable scripts found.\nRead the scan details below and check the files in Scripts Folder."
        } else {
            empty.stringValue = "Add your first script\nOpen Scripts Folder and add an executable file, such as clock.5s.sh."
        }
        detailGroup.isHidden = rows.isEmpty && scanDetails.isEmpty
        updateDetail()
    }

    private func updateDetail() {
        detailHeading.stringValue = detailMode == .scan ? "Scan details" : "Last run details"
        detail.setAccessibilityLabel(detailHeading.stringValue)
        showDetails.title = detailMode == .scan ? "Show last run" : "Show scan details"
        showDetails.isHidden = rows.isEmpty
        if detailMode == .scan {
            runControls.update(pluginID: nil, running: false, scanMode: true)
            setDetailText(scanDetails)
            return
        }
        guard rows.indices.contains(table.selectedRow) else {
            runControls.update(pluginID: nil, running: false, scanMode: false)
            setDetailText("Select a script to inspect its last run.")
            return
        }
        let row = rows[table.selectedRow]
        runControls.update(pluginID: row.plugin.id, running: row.running, scanMode: false)
        guard let diagnostics = row.diagnostics else {
            setDetailText("\(row.plugin.filename)\n\(row.status)")
            return
        }
        let exit = diagnostics.exitCode.map { "Exit code \($0)" } ?? "No exit code recorded"
        let failure: String?
        switch diagnostics.failure {
        case .notExecutable: failure = "not executable"
        case .timedOut:
            failure = PluginStatusText.describe(diagnostics: diagnostics, now: diagnostics.finishedAt)
        case .exitedNonZero: failure = "Run failed."
        case nil: failure = nil
        }
        let status = [row.running ? "Running…" : nil, failure,
                      diagnostics.outputTruncated ? "output cut at 1 MB" : nil]
            .compactMap { $0 }.joined(separator: "\n")
        let stderr = diagnostics.stderr.isEmpty ? "No stderr captured." : diagnostics.stderr
        setDetailText("\(row.plugin.filename)\nCompleted \(diagnostics.finishedAt.formatted()) · \(exit)\n\(status)\nStderr, up to \(PluginDiagnostics.stderrLimit) characters\n\(stderr)")
    }

    private func setDetailText(_ text: String) {
        guard detail.string != text else { return }
        let selections = detail.selectedRanges.map(\.rangeValue)
        let scroll = detail.enclosingScrollView
        let origin = scroll?.contentView.bounds.origin
        detail.string = text
        let length = (text as NSString).length
        detail.selectedRanges = selections.map { range in
            let location = min(range.location, length)
            return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
        }
        if let container = detail.textContainer { detail.layoutManager?.ensureLayout(for: container) }
        if let scroll, let origin {
            let bounds = NSRect(origin: origin, size: scroll.contentView.bounds.size)
            scroll.contentView.scroll(to: scroll.contentView.constrainBoundsRect(bounds).origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    @objc private func toggleDetails() {
        detailMode = detailMode == .scan ? .lastRun : .scan
        updateDetail()
        detail.setSelectedRange(NSRange(location: 0, length: 0))
        detail.scrollRangeToVisible(NSRange(location: 0, length: 0))
        window?.makeFirstResponder(detail)
    }

    @objc private func openFolder() { appState?.openPluginsFolder() }
    @objc private func retryScan() { appState?.rescanPlugins() }

    @objc private func runNowClicked() {
        guard rows.indices.contains(table.selectedRow), let appState else { return }
        let pluginID = rows[table.selectedRow].plugin.id
        runControls.clearNotice()
        Task { @MainActor in
            let result = await appState.runNow(pluginID: pluginID)
            switch result {
            case .queued:
                refresh()
            case .alreadyRunning:
                runControls.showAlreadyRunning()
            case .unavailable:
                break
            }
            if rows.indices.contains(table.selectedRow) {
                let row = rows[table.selectedRow]
                runControls.update(pluginID: row.plugin.id, running: row.running, scanMode: false)
            }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableViewSelectionDidChange(_ notification: Notification) {
        if !updatingRows {
            runControls.clearNotice()
            updateDetail()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let item = rows[row]
        let label = NSTextField(labelWithString: "")
        label.font = SettingsStyle.TypeRole.body
        label.lineBreakMode = .byTruncatingTail
        switch column?.identifier.rawValue {
        case "Name": label.stringValue = item.plugin.filename
        case "Interval": label.stringValue = "\(item.plugin.interval.seconds)s"
        default:
            label.stringValue = item.status
            if item.diagnostics?.failure != nil { label.textColor = .systemRed }
            else if item.diagnostics?.outputTruncated == true { label.textColor = .systemOrange }
        }
        label.toolTip = label.stringValue
        label.setAccessibilityLabel(label.stringValue)
        return label
    }
}
