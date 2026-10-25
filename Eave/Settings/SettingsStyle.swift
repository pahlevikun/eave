import AppKit
import Combine

@MainActor
enum SettingsStyle {
    enum Metric {
        static let inset: CGFloat = 20
        static let related: CGFloat = 8
        static let section: CGFloat = 12
        static let rowHeight: CGFloat = 32
        static let detailHeight: CGFloat = 112
    }

    @MainActor
    enum TypeRole {
        static let heading = NSFont.systemFont(ofSize: 17, weight: .semibold)
        static let section = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let body = NSFont.systemFont(ofSize: 13)
        static let metadata = NSFont.systemFont(ofSize: 11)
        static let diagnostic = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    }

    private enum Fieldstone {
        static let panelLight: UInt32 = 0xFBFCFB
        static let panelDark: UInt32 = 0x181C18
        static let surfaceLight: UInt32 = 0xEAEEEA
        static let surfaceDark: UInt32 = 0x212620
    }

    enum Surface { case panel, detail }

    private static let fieldstonePanel = adaptiveColor(
        name: "EaveSettingsPanel", light: Fieldstone.panelLight, dark: Fieldstone.panelDark
    )
    private static let fieldstoneDetail = adaptiveColor(
        name: "EaveSettingsDetail", light: Fieldstone.surfaceLight, dark: Fieldstone.surfaceDark
    )

    static func color(_ surface: Surface, increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast) -> NSColor {
        switch (surface, increaseContrast) {
        case (.panel, false): fieldstonePanel
        case (.detail, false): fieldstoneDetail
        case (.panel, true): .windowBackgroundColor
        case (.detail, true): .controlBackgroundColor
        }
    }

    private static func adaptiveColor(name: String, light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                           green: CGFloat((rgb >> 8) & 0xFF) / 255,
                           blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
        }
    }
}

@MainActor
class SettingsPane: NSView {
    private var displayObservation: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        displayObservation = NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        ).sink { [weak self] _ in
            Task { @MainActor in self?.refreshAppearance() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refreshAppearance() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        SettingsStyle.color(.panel).setFill()
        dirtyRect.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }
}
