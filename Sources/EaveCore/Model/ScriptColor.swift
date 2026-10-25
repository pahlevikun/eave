import Foundation

public enum ScriptColor: Equatable, Sendable {
    /// A named colour that follows the system palette, so it adapts to Dark
    /// Mode and Increase Contrast instead of fighting them.
    case named(Named)
    /// An explicit sRGB value from the plugin.
    case rgb(red: Double, green: Double, blue: Double, alpha: Double)

    public enum Named: String, CaseIterable, Sendable {
        case black, white, red, green, blue, yellow, orange, purple, gray, pink
    }

    /// Parses xbar's colour syntax. Returns nil for anything unknown, so the
    /// caller keeps the system colour rather than guessing.
    public static func parse(_ raw: String) -> ScriptColor? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let named = parseNamed(trimmed) {
            return .named(named)
        }
        if let rgb = parseHex(trimmed) {
            return rgb
        }
        return nil
    }

    private static func parseNamed(_ value: String) -> Named? {
        let key = value.lowercased()
        let normalized = key == "grey" ? "gray" : key
        return Named(rawValue: normalized)
    }

    private static func parseHex(_ value: String) -> ScriptColor? {
        var digits = value
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.allSatisfy(\.isHexDigit) else { return nil }

        let expanded: String
        switch digits.count {
        case 3:
            expanded = digits.map { String(repeating: $0, count: 2) }.joined()
        case 6, 8:
            expanded = digits
        default:
            return nil
        }

        let chars = Array(expanded)
        func byte(at start: Int) -> Double? {
            let hi = chars[start].hexValue
            let lo = chars[start + 1].hexValue
            guard let hi, let lo else { return nil }
            return Double(hi * 16 + lo) / 255.0
        }

        switch expanded.count {
        case 6:
            guard let red = byte(at: 0),
                  let green = byte(at: 2),
                  let blue = byte(at: 4)
            else { return nil }
            return .rgb(red: red, green: green, blue: blue, alpha: 1)
        case 8:
            guard let alpha = byte(at: 0),
                  let red = byte(at: 2),
                  let green = byte(at: 4),
                  let blue = byte(at: 6)
            else { return nil }
            return .rgb(red: red, green: green, blue: blue, alpha: alpha)
        default:
            return nil
        }
    }
}

private extension Character {
    var isHexDigit: Bool { hexValue != nil }

    var hexValue: Int? {
        switch self {
        case "0" ... "9":
            return wholeNumberValue
        case "a" ... "f":
            return Int(unicodeScalars.first!.value - UnicodeScalar("a").value + 10)
        case "A" ... "F":
            return Int(unicodeScalars.first!.value - UnicodeScalar("A").value + 10)
        default:
            return nil
        }
    }
}
