import AppKit
import Combine

@MainActor
final class HidePane: SettingsPane {
    private let toggle = NSButton(checkboxWithTitle: "Hide icons left of the separator", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let permissionStatus = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?
    private var observation: AnyCancellable?
    private var permissionObservation: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let heading = NSTextField(labelWithString: "Menu Bar")
        heading.font = SettingsStyle.TypeRole.heading
        let explanation = NSTextField(wrappingLabelWithString: "Keep your menu bar focused by hiding items to the left of Eave’s separator. Basic hiding works without permissions.")
        explanation.font = SettingsStyle.TypeRole.body
        explanation.textColor = .secondaryLabelColor
        status.font = SettingsStyle.TypeRole.metadata
        status.textColor = .secondaryLabelColor
        toggle.target = self
        toggle.action = #selector(toggleHide)
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
        let permissionHeading = NSTextField(labelWithString: "Optional Accessibility access")
        permissionHeading.font = SettingsStyle.TypeRole.section
        permissionStatus.font = SettingsStyle.TypeRole.metadata
        permissionStatus.textColor = .secondaryLabelColor
        let permissionExplanation = NSTextField(wrappingLabelWithString: "Lets Eave move its own hideable script items before hiding the section. Scripts and basic hiding work without it.")
        permissionExplanation.font = SettingsStyle.TypeRole.body
        permissionExplanation.textColor = .secondaryLabelColor
        for child in [permissionHeading, permissionExplanation, permissionStatus] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        let permission = NSButton(title: "Open Accessibility Settings…", target: self, action: #selector(openAccessibility))
        permission.bezelStyle = .rounded
        permission.translatesAutoresizingMaskIntoConstraints = false
        addSubview(permission)
        NSLayoutConstraint.activate([
            permissionHeading.topAnchor.constraint(equalTo: status.bottomAnchor, constant: SettingsStyle.Metric.section * 2),
            permissionHeading.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            permissionHeading.trailingAnchor.constraint(equalTo: explanation.trailingAnchor),
            permissionExplanation.topAnchor.constraint(equalTo: permissionHeading.bottomAnchor, constant: SettingsStyle.Metric.related),
            permissionExplanation.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            permissionExplanation.trailingAnchor.constraint(equalTo: explanation.trailingAnchor),
            permissionStatus.topAnchor.constraint(equalTo: permissionExplanation.bottomAnchor, constant: SettingsStyle.Metric.related),
            permissionStatus.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            permissionStatus.trailingAnchor.constraint(equalTo: explanation.trailingAnchor),
            permission.topAnchor.constraint(equalTo: permissionStatus.bottomAnchor, constant: SettingsStyle.Metric.related),
            permission.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
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
        toggle.state = appState.isHideSectionCollapsed ? .on : .off
        let access = appState.permissionStore.granted[.accessibility] == true
        status.stringValue = appState.hideStatus
        permissionStatus.stringValue = access ? "Accessibility access is granted." : "Accessibility access is not granted."
    }

    @objc private func toggleHide() {
        appState?.toggleHiddenSection()
        refresh()
    }
    @objc private func openAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
