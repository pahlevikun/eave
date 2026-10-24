import Foundation

/// Parser for the xbar output format.
///
/// The first line becomes the status item title. `---` starts the dropdown
/// content. `--` nests under the line above it. Parameters follow the first
/// `|`, space separated: `Title | key=val key2="val with space"`.
public enum XbarParser {
    public static func parse(_ output: String, namespace: String) -> [ScriptItem] {
        var topLevel: [ScriptItem] = []
        var dropdownRoot: [ScriptItem] = []
        var inDropdown = false

        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line == "---" {
                inDropdown = true
                continue
            }
            guard !line.isEmpty else { continue }

            let (depth, body) = stripDashes(line)
            let (text, params) = splitParams(body)
            guard !text.isEmpty else { continue }

            let item = ScriptItem(
                title: text,
                namespace: namespace,
                parameters: params,
                children: []
            )

            if inDropdown {
                insert(&dropdownRoot, item: item, depth: depth)
            } else if depth == 0 {
                topLevel.append(item)
            }
        }

        return topLevel.map { item in
            var copy = item
            copy.children = dropdownRoot
            return copy
        }
    }

    /// Counts the leading `--` pairs and returns the rest of the line.
    static func stripDashes(_ line: String) -> (depth: Int, body: String) {
        var depth = 0
        var rest = Substring(line)
        while rest.hasPrefix("--") {
            depth += 1
            rest = rest.dropFirst(2)
        }
        return (depth, String(rest).trimmingCharacters(in: .whitespaces))
    }

    /// Splits the title from its parameters. Only the first `|` separates the
    /// title, so a pipe inside the parameter list does not break it.
    static func splitParams(_ body: String) -> (title: String, params: [String: String]) {
        guard let pipe = body.firstIndex(of: "|") else {
            return (body.trimmingCharacters(in: .whitespaces), [:])
        }
        let title = String(body[..<pipe]).trimmingCharacters(in: .whitespaces)
        let paramString = String(body[body.index(after: pipe)...])
        return (title, parseParamString(paramString))
    }

    /// Splits the parameter list on spaces outside quotes, then reads
    /// `key=value` per token. A token with no `=` is skipped, so one broken
    /// parameter does not discard the rest.
    private static func parseParamString(_ s: String) -> [String: String] {
        var params: [String: String] = [:]
        for token in tokenize(s) {
            guard let eq = token.firstIndex(of: "=") else { continue }
            let key = String(token[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(token[token.index(after: eq)...])
            if value.count >= 2,
               let first = value.first, let last = value.last,
               (first == "\"" || first == "'"), first == last {
                value = String(value.dropFirst().dropLast())
            }
            guard !key.isEmpty else { continue }
            params[key] = value
        }
        return params
    }

    /// Splits on spaces, but not inside single or double quotes.
    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?

        for ch in s {
            if let q = quote {
                if ch == q {
                    quote = nil
                } else {
                    current.append(ch)
                }
                continue
            }
            switch ch {
            case "\"", "'":
                quote = ch
            case " ":
                if !current.isEmpty { tokens.append(current); current = "" }
            default:
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Inserts an item at the given depth. Depth 0 is the top level. A depth
    /// deeper than the tree allows clamps to the deepest level, so a broken
    /// plugin output never loses a line.
    private static func insert(_ items: inout [ScriptItem], item: ScriptItem, depth: Int) {
        if depth <= 0 || items.isEmpty {
            items.append(item)
            return
        }
        let last = items.indices.last!
        insert(&items[last].children, item: item, depth: depth - 1)
    }
}
