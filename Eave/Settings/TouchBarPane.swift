import AppKit

@MainActor
final class TouchBarPane: NSView {
    private let toggle = NSButton(checkboxWithTitle: "Show plugin items on Touch Bar", target: nil, action: nil)
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        explanation.stringValue =
            "A Mac without a Touch Bar shows nothing. Eave steps aside when Touch Bar is disabled."
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor

        toggle.target = self
        toggle.action = #selector(toggleTouchBar)

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
        toggle.state = appState.isTouchBarEnabled ? .on : .off
    }

    @objc private func toggleTouchBar() {
        let enabled = toggle.state == .on
        appState?.setTouchBarEnabled(enabled)
    }
}
