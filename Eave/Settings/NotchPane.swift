import AppKit

@MainActor
final class NotchPane: NSView {
    private let button = NSButton(title: "Toggle notch tray", target: nil, action: nil)
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private weak var appState: AppState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        explanation.stringValue =
            "Opens a panel under the notch for icons that no longer fit beside it."
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor

        button.target = self
        button.action = #selector(toggleTray)

        button.translatesAutoresizingMaskIntoConstraints = false
        explanation.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        addSubview(explanation)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            explanation.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 12),
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
    }

    @objc private func toggleTray() {
        appState?.toggleNotchTray()
    }
}
