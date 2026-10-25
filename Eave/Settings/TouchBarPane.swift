import AppKit
import Combine

@MainActor
final class TouchBarPane: SettingsPane {
    private let toggle = NSButton(checkboxWithTitle: "Show script items in Settings", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?
    private var observation: AnyCancellable?
    private var permissionObservation: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let heading = NSTextField(labelWithString: "Touch Bar")
        heading.font = SettingsStyle.TypeRole.heading
        let explanation = NSTextField(wrappingLabelWithString: "On Macs with a Touch Bar, show script items while Eave Settings is active. Items with a supported URL can open it. Other apps keep their own Touch Bar.")
        explanation.font = SettingsStyle.TypeRole.body
        explanation.textColor = .secondaryLabelColor
        status.font = SettingsStyle.TypeRole.metadata
        status.textColor = .secondaryLabelColor
        toggle.target = self
        toggle.action = #selector(toggleTouchBar)
        for child in [heading, explanation, toggle, status] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: topAnchor, constant: SettingsStyle.Metric.inset),
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsStyle.Metric.inset),
            explanation.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: SettingsStyle.Metric.section),
            explanation.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            explanation.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsStyle.Metric.inset),
            toggle.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: SettingsStyle.Metric.section * 2),
            toggle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            status.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: SettingsStyle.Metric.section),
            status.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: explanation.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(appState: AppState) {
        self.appState = appState
        observation = appState.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        permissionObservation = appState.permissionStore.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    private func refresh() {
        guard let appState else { return }
        toggle.state = appState.isTouchBarEnabled ? .on : .off
        status.stringValue = appState.isTouchBarEnabled ? "Enabled for the Eave Settings window. Requires Touch Bar hardware." : "Disabled for the Eave Settings window."
    }

    @objc private func toggleTouchBar() {
        appState?.setTouchBarEnabled(toggle.state == .on)
        refresh()
    }
}
