import AppKit
import Combine

@MainActor
final class NotchPane: SettingsPane {
    private let button = NSButton(title: "Show overflow preview", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?
    private var observation: AnyCancellable?
    private var permissionObservation: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let heading = NSTextField(labelWithString: "Overflow preview")
        heading.font = SettingsStyle.TypeRole.heading
        let explanation = NSTextField(wrappingLabelWithString: "See script titles that exceed the estimated available menu bar space. This informational preview does not move icons or control other apps. Press Esc or click outside to close it.")
        explanation.font = SettingsStyle.TypeRole.body
        explanation.textColor = .secondaryLabelColor
        status.font = SettingsStyle.TypeRole.metadata
        status.textColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(toggleTray)
        for child in [heading, explanation, button, status] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: topAnchor, constant: SettingsStyle.Metric.inset),
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsStyle.Metric.inset),
            explanation.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: SettingsStyle.Metric.section),
            explanation.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            explanation.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsStyle.Metric.inset),
            button.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: SettingsStyle.Metric.section * 2),
            button.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            status.topAnchor.constraint(equalTo: button.bottomAnchor, constant: SettingsStyle.Metric.section),
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
        status.stringValue = "\(appState.notchTrayPlan.overflowed.count) script items in the current preview."
        button.title = appState.isNotchTrayOpen ? "Close overflow preview" : "Show overflow preview"
    }

    @objc private func toggleTray() {
        appState?.toggleNotchTray()
        refresh()
    }
}
