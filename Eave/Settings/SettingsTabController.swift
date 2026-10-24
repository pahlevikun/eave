import AppKit

@MainActor
final class SettingsTabController: NSView {
    private let tabView = NSTabView()
    private let scriptsPane = ScriptsPane()
    private let hidePane = HidePane()
    private let notchPane = NotchPane()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: topAnchor),
            tabView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        tabView.addTabViewItem(makeTab(label: "Scripts", view: scriptsPane))
        tabView.addTabViewItem(makeTab(label: "Hide", view: hidePane))
        tabView.addTabViewItem(makeTab(label: "Notch", view: notchPane))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(appState: AppState) {
        scriptsPane.bind(appState: appState)
        hidePane.bind(appState: appState)
        notchPane.bind(appState: appState)
    }

    private func makeTab(label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }
}
