import Foundation

public struct KeyboardShortcutModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

public struct KeyboardShortcut: Equatable, Sendable {
    public var key: String
    public var modifierFlags: Int

    public init(key: String, modifierFlags: Int) {
        self.key = key
        self.modifierFlags = modifierFlags
    }

    public var modifiers: KeyboardShortcutModifiers {
        KeyboardShortcutModifiers(rawValue: modifierFlags)
    }
}

public struct ScriptItemPresentation: Equatable, Sendable {
    /// Width in points. nil when the plugin did not ask for one, or asked for
    /// something that is not a positive number.
    public var length: Double?
    /// False only when the plugin says `dropdown=false`.
    public var showsDropdown: Bool
    public var shortcut: KeyboardShortcut?
    /// True only when the plugin says `refresh=true`.
    public var refreshesAfterAction: Bool

    public static let `default` = ScriptItemPresentation(
        length: nil,
        showsDropdown: true,
        shortcut: nil,
        refreshesAfterAction: false
    )

    public static func parse(parameters: [String: String]) -> ScriptItemPresentation {
        ScriptItemPresentation(
            length: parseLength(parameters["length"]),
            showsDropdown: parseShowsDropdown(parameters["dropdown"]),
            shortcut: parseShortcut(parameters["shortcut"]),
            refreshesAfterAction: parseRefreshes(parameters["refresh"])
        )
    }

    private static func parseLength(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else { return nil }
        guard let value = Int(trimmed), value >= 1, value <= 500 else { return nil }
        return Double(value)
    }

    private static func parseShowsDropdown(_ raw: String?) -> Bool {
        guard let raw else { return true }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.compare("false", options: .caseInsensitive) == .orderedSame {
            return false
        }
        return true
    }

    private static func parseRefreshes(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.compare("true", options: .caseInsensitive) == .orderedSame
    }

    private static let shortcutModifiers: [String: KeyboardShortcutModifiers] = [
        "cmd": .command,
        "command": .command,
        "alt": .option,
        "option": .option,
        "ctrl": .control,
        "control": .control,
        "shift": .shift,
    ]

    private static func parseShortcut(_ raw: String?) -> KeyboardShortcut? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let segments = trimmed.split(separator: "+", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let keyPart = segments.last, !keyPart.isEmpty else { return nil }
        guard keyPart.count == 1 else { return nil }

        var flags = KeyboardShortcutModifiers()
        for part in segments.dropLast() {
            guard let modifier = shortcutModifiers[part.lowercased()] else { return nil }
            flags.insert(modifier)
        }

        return KeyboardShortcut(key: keyPart.lowercased(), modifierFlags: flags.rawValue)
    }
}

public extension ScriptItem {
    var presentation: ScriptItemPresentation {
        ScriptItemPresentation.parse(parameters: parameters)
    }
}
