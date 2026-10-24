import Foundation

/// The single entry point for turning plugin stdout into menu items.
///
/// A plugin may print xbar's line format or one JSON object. That choice is
/// the plugin author's, so the decision lives here rather than in every
/// caller. Callers see items, never a format.
public enum ScriptOutput {
    /// Parses plugin output. Returns an empty array for output that carries
    /// no item, which is a normal case: a plugin can print nothing.
    public static func parse(_ output: String, namespace: String) -> [ScriptItem] {
        if let payload = jsonPayload(in: output) {
            return item(from: payload, namespace: namespace).map { [$0] } ?? []
        }
        return XbarParser.parse(output, namespace: namespace)
    }

    // MARK: - JSON shape (MTMR)

    /// Decoded at the boundary, never re-exported. Callers get `ScriptItem`.
    private struct Payload: Decodable {
        var title: String?
        var image: String?
        var color: String?
        var href: String?
    }

    private static func jsonPayload(in text: String) -> Payload? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}"),
              let data = trimmed.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// A payload with neither title nor image draws nothing, so it yields
    /// nothing. That also makes `{}` fall back to no item instead of a blank
    /// gap in the menu bar.
    private static func item(from payload: Payload, namespace: String) -> ScriptItem? {
        guard payload.title?.isEmpty == false || payload.image != nil else { return nil }

        var parameters: [String: String] = [:]
        if let color = payload.color { parameters["color"] = color }
        if let href = payload.href { parameters["href"] = href }
        if let image = payload.image { parameters["image"] = image }

        return ScriptItem(
            title: payload.title ?? "",
            namespace: namespace,
            parameters: parameters
        )
    }
}
