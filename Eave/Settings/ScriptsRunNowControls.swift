import AppKit

@MainActor
final class ScriptsRunNowControls {
    let button = NSButton(title: "Run now", target: nil, action: nil)
    let notice = NSTextField(labelWithString: "")
    private let row = NSStackView()

    init(target: AnyObject?, action: Selector) {
        button.target = target
        button.action = action
        button.bezelStyle = .rounded
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        notice.font = SettingsStyle.TypeRole.metadata
        notice.textColor = .secondaryLabelColor
        notice.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = SettingsStyle.Metric.related
        row.addArrangedSubview(button)
        row.addArrangedSubview(notice)
    }

    func embed(beside detailScroll: NSView, in group: NSStackView) {
        row.translatesAutoresizingMaskIntoConstraints = false
        detailScroll.translatesAutoresizingMaskIntoConstraints = false
        let detailRow = NSStackView(views: [detailScroll, row])
        detailRow.orientation = .horizontal
        detailRow.alignment = .top
        detailRow.spacing = SettingsStyle.Metric.related
        detailRow.translatesAutoresizingMaskIntoConstraints = false
        group.addArrangedSubview(detailRow)
        detailRow.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        detailScroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.setContentHuggingPriority(.required, for: .horizontal)
    }

    func update(pluginID: String?, running: Bool, scanMode: Bool) {
        let hasSelection = pluginID != nil
        row.isHidden = scanMode || !hasSelection
        button.isEnabled = hasSelection && !running
        if !hasSelection || running { notice.stringValue = "" }
    }

    func showAlreadyRunning() {
        notice.stringValue = "Already running"
    }

    func clearNotice() {
        notice.stringValue = ""
    }
}
