import Foundation

/// Parses the JSON output shape that MTMR plugins use.
///
/// A plugin may print either plain text (xbar style) or a single JSON object
/// with a title and an optional image. Both are valid, and a plugin author
/// picks one. `ScriptOutputParser` decides which by looking at the first
/// non-space character.
public enum JSONOutputParser {
    public struct Payload: Decodable, Equatable, Sendable {
        public var title: String?
        public var image: String?
        public var color: String?
        public var href: String?

        public init(title: String? = nil, image: String? = nil, color: String? = nil, href: String? = nil) {
            self.title = title
            self.image = image
            self.color = color
            self.href = href
        }
    }

    /// Returns `nil` when the text is not a JSON object or does not decode.
    /// Callers fall back to the plain-text parser on `nil`, so a malformed
    /// payload degrades to reading the raw string as a title.
    public static func parse(_ text: String) -> Payload? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// Converts a decoded payload into one item. A payload with no title and
    /// no image yields `nil`, because there is nothing to draw.
    public static func item(from payload: Payload, namespace: String) -> ScriptItem? {
        var parameters: [String: String] = [:]
        if let color = payload.color { parameters["color"] = color }
        if let href = payload.href { parameters["href"] = href }
        if let image = payload.image { parameters["image"] = image }

        let title = payload.title ?? ""
        guard !title.isEmpty || payload.image != nil else { return nil }

        return ScriptItem(
            title: title,
            namespace: namespace,
            parameters: parameters,
            children: []
        )
    }
}

/// Picks the parser that fits the plugin's output.
public enum ScriptOutputParser {
    /// JSON first, plain text second. A plugin that prints `{...}` gets the
    /// JSON path, everything else goes through xbar's line format.
    public static func parse(_ output: String, namespace: String) -> [ScriptItem] {
        if let payload = JSONOutputParser.parse(output),
           let item = JSONOutputParser.item(from: payload, namespace: namespace) {
            return [item]
        }
        return XbarParser.parse(output, namespace: namespace)
    }
}
