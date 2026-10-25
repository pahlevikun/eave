#if canImport(AppKit)
import AppKit
import EaveCore

enum ScriptColorKit {
    static func nsColor(for color: ScriptColor) -> NSColor {
        switch color {
        case .named(let named):
            return nsColor(for: named)
        case .rgb(let red, let green, let blue, let alpha):
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    static func nsColor(for named: ScriptColor.Named) -> NSColor {
        switch named {
        case .black:
            return .black
        case .white:
            return .white
        case .red:
            return .systemRed
        case .green:
            return .systemGreen
        case .blue:
            return .systemBlue
        case .yellow:
            return .systemYellow
        case .orange:
            return .systemOrange
        case .purple:
            return .systemPurple
        case .gray:
            return .systemGray
        case .pink:
            return .systemPink
        }
    }

    static func attributedString(title: String, color: ScriptColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: nsColor(for: color),
        ]
        return NSAttributedString(string: title, attributes: attributes)
    }
}

extension NSButton {
    func applyMenuBarTitle(_ title: String, color: ScriptColor?) {
        if let color {
            attributedTitle = ScriptColorKit.attributedString(title: title, color: color)
            self.title = ""
        } else {
            attributedTitle = NSAttributedString()
            self.title = title
        }
    }
}

extension NSMenuItem {
    func applyRowTitle(_ title: String, color: ScriptColor?) {
        if let color {
            attributedTitle = ScriptColorKit.attributedString(title: title, color: color)
            self.title = ""
        } else {
            attributedTitle = NSAttributedString()
            self.title = title
        }
    }
}
#endif
