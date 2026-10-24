import AppKit

@MainActor
final class HidePane: NSView {
    private let toggle = NSButton(checkboxWithTitle: "Hide icons left of separator", target: nil, action: nil)
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        explanation.stringValue =
            "Collapses a wide separator to push icons off-screen. With Accessibility, Eave can move hideable items first."
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor

        toggle.target = self
        toggle.action = #selector(toggleHide)

        toggle.translatesAutoresizingMaskIntoConstraints = false
        explanation.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toggle)
        addSubview(explanation)

        NSLayoutConstraint.activate([
            toggle.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            toggle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            explanation.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: 12),
            explanation.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            explanation.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(appState: AppState) {
        self.appState = appState
        toggle.state = appState.isHideSectionCollapsed ? .on : .off
    }

    @objc private func toggleHide() {
        appState?.toggleHiddenSection()
        toggle.state = appState?.isHideSectionCollapsed == true ? .on : .off
    }
}
