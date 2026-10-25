import AppKit

@MainActor
final class SettingsTabController: NSView, NSTabViewDelegate {
    private var presented = false
    private let tabView = NSTabView()
    private let scriptsPane = ScriptsPane()
    private let hidePane = HidePane()
    private let notchPane = NotchPane()
    private let touchBarPane = TouchBarPane()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabView.delegate = self
        tabView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: topAnchor),
            tabView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        tabView.addTabViewItem(makeTab(label: "Scripts", view: scriptsPane))
        tabView.addTabViewItem(makeTab(label: "Menu Bar", view: hidePane))
        tabView.addTabViewItem(makeTab(label: "Overflow", view: notchPane))
        tabView.addTabViewItem(makeTab(label: "Touch Bar", view: touchBarPane))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(appState: AppState) {
        scriptsPane.bind(appState: appState)
        hidePane.bind(appState: appState)
        notchPane.bind(appState: appState)
        touchBarPane.bind(appState: appState)
    }

    func setPresented(_ presented: Bool) {
        self.presented = presented
        scriptsPane.setActive(presented && tabView.selectedTabViewItem?.view === scriptsPane)
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        scriptsPane.setActive(presented && tabViewItem?.view === scriptsPane)
    }

    private func makeTab(label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }
}
