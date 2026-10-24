import AppKit
import EaveCore

@MainActor
final class ScriptsPane: NSView {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let permissionsLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")
    private weak var appState: AppState?
    private var refreshTimer: Timer?

    private struct Row {
        let plugin: Plugin
        var statusLine: String
        var failed: Bool
    }

    private var rows: [Row] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTable()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(appState: AppState) {
        self.appState = appState
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRows()
            }
        }
        refreshRows()
    }

    private func configureTable() {
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 22

        let columns: [(String, CGFloat)] = [
            ("Filename", 180),
            ("Interval", 70),
            ("Status line", 240),
            ("Failed", 50),
        ]
        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = width
            tableView.addTableColumn(column)
        }

        tableView.dataSource = self
        tableView.delegate = self
    }

    private func configureLayout() {
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        permissionsLabel.font = .systemFont(ofSize: 11)
        permissionsLabel.lineBreakMode = .byWordWrapping
        permissionsLabel.maximumNumberOfLines = 2
        permissionsLabel.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.lineBreakMode = .byWordWrapping
        footerLabel.maximumNumberOfLines = 3
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(permissionsLabel)
        addSubview(scrollView)
        addSubview(footerLabel)

        NSLayoutConstraint.activate([
            permissionsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            permissionsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            permissionsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: permissionsLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            footerLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            footerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            footerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            footerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),
        ])
    }

    private func refreshRows() {
        guard let appState else { return }
        let access = appState.permissionStore.granted[.accessibility] == true ? "yes" : "no"
        let screen = appState.permissionStore.granted[.screenRecording] == true ? "yes" : "no"
        permissionsLabel.stringValue =
            "Accessibility: \(access)   Screen Recording: \(screen)"

        Task { @MainActor in
            var built: [Row] = []
            let now = Date()
            for plugin in appState.plugins {
                let diag = await appState.diagnostics(for: plugin)
                let line = PluginStatusText.describe(diagnostics: diag, now: now)
                let failed = appState.lastOutcomeFailed(for: plugin)
                built.append(Row(plugin: plugin, statusLine: line, failed: failed))
            }
            rows = built
            footerLabel.stringValue = appState.rejectionFooterText()
            tableView.reloadData()
        }
    }
}

extension ScriptsPane: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }
}

extension ScriptsPane: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowData = rows[row]
        let id = tableColumn?.identifier.rawValue ?? ""
        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail

        switch id {
        case "Filename":
            textField.stringValue = rowData.plugin.filename
        case "Interval":
            textField.stringValue = "\(rowData.plugin.interval.seconds)s"
        case "Status line":
            textField.stringValue = rowData.statusLine
        case "Failed":
            textField.stringValue = rowData.failed ? "●" : ""
            textField.textColor = rowData.failed ? .systemRed : .labelColor
        default:
            break
        }

        return textField
    }
}
