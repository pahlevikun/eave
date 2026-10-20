import Foundation

/// Parser format xbar.
///
/// Format: baris pertama jadi judul status item, `---` memisahkan isi
/// dropdown, `--` per level submenu. Parameter mengikuti `|` pertama, lalu
/// dipisah spasi: `Title | key=val key2="val with space"`.
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

    /// Menghitung kedalaman dari awalan `--` dan mengembalikan sisa baris.
    static func stripDashes(_ line: String) -> (depth: Int, body: String) {
        var depth = 0
        var rest = Substring(line)
        while rest.hasPrefix("--") {
            depth += 1
            rest = rest.dropFirst(2)
        }
        return (depth, String(rest).trimmingCharacters(in: .whitespaces))
    }

    /// Memisah judul dari parameter. Hanya `|` pertama yang memisah judul.
    static func splitParams(_ body: String) -> (title: String, params: [String: String]) {
        guard let pipe = body.firstIndex(of: "|") else {
            return (body.trimmingCharacters(in: .whitespaces), [:])
        }
        let title = String(body[..<pipe]).trimmingCharacters(in: .whitespaces)
        let paramString = String(body[body.index(after: pipe)...])
        return (title, parseParamString(paramString))
    }

    /// Memecah isi parameter per spasi di luar kutip, lalu `key=value` per token.
    /// Token tanpa `=` dilewati, supaya satu parameter rusak tidak membuang
    /// sisanya.
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

    /// Memecah per spasi, tapi tidak di dalam kutip tunggal atau ganda.
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

    /// Menyisipkan item pada kedalaman tertentu. Kedalaman 0 berarti level
    /// teratas; kedalaman lebih dalam dari yang tersedia di-clamp ke level
    /// terdalam, supaya output plugin yang rusak tidak menghilangkan baris.
    private static func insert(_ items: inout [ScriptItem], item: ScriptItem, depth: Int) {
        if depth <= 0 || items.isEmpty {
            items.append(item)
            return
        }
        let last = items.indices.last!
        insert(&items[last].children, item: item, depth: depth - 1)
    }
}
