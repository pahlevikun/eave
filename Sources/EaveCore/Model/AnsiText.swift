import Foundation

public enum AnsiText {
    /// Removes ANSI escape sequences so a title reads as text.
    ///
    /// Only removal. This app does not render colour codes, so keeping them
    /// would print garbage, and pretending to render them would be a lie.
    public static func strip(_ text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "\u{1B}" else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let afterEscape = text.index(after: index)
            if afterEscape == text.endIndex {
                break
            }

            let marker = text[afterEscape]
            if marker == "[" {
                if let end = skipCSI(from: text.index(after: afterEscape), in: text) {
                    index = end
                } else {
                    index = text.endIndex
                }
                continue
            }

            if marker == "\u{9B}" {
                if let end = skipCSI(from: text.index(after: afterEscape), in: text) {
                    index = end
                } else {
                    index = text.endIndex
                }
                continue
            }

            if marker == "]" {
                if let end = skipOSC(from: text.index(after: afterEscape), in: text) {
                    index = end
                } else {
                    index = text.endIndex
                }
                continue
            }

            if isFinalByte(marker) {
                index = text.index(after: afterEscape)
                continue
            }

            result.append(text[index])
            index = text.index(after: index)
        }

        return result
    }

    /// Strips escapes, then keeps the first line only.
    ///
    /// A status item is one line tall. A plugin that prints a newline in its
    /// title should not push half its text out of view.
    public static func stripAndFirstLine(_ text: String) -> String {
        let stripped = strip(text)
        guard let newline = stripped.firstIndex(of: "\n") else { return stripped }
        return String(stripped[..<newline])
    }

    private static func skipCSI(from start: String.Index, in text: String) -> String.Index? {
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if isFinalByte(character) {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func skipOSC(from start: String.Index, in text: String) -> String.Index? {
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == "\u{07}" {
                return text.index(after: index)
            }
            if character == "\u{1B}" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\\" {
                    return text.index(after: next)
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isFinalByte(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        let value = scalar.value
        return value >= 0x40 && value <= 0x7E
    }
}
