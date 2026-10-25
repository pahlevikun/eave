import Foundation

public enum ScriptItemAction: Equatable, Sendable {
    case openURL(URL)
    case unsupported(parameter: String)
    case none
}

public extension ScriptItem {
    /// What activating this item means. Only the parameters this app
    /// actually implements are reported as supported.
    var action: ScriptItemAction {
        if let bash = parameters["bash"], !bash.isEmpty {
            return .unsupported(parameter: "bash")
        }
        if parameters["href"] != nil {
            let href = parameters["href"] ?? ""
            if let url = ScriptItemAction.absoluteURL(from: href) {
                return .openURL(url)
            }
            return .unsupported(parameter: "href")
        }
        return .none
    }
}

extension ScriptItemAction {
    /// Parses only absolute URLs with an explicit scheme. Relative paths and bare
    /// words are rejected so the UI never offers a link that cannot open.
    static func absoluteURL(from href: String) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return nil }
        switch scheme {
        case "http", "https":
            guard url.host != nil else { return nil }
            return url
        case "mailto", "tel", "file":
            return url
        default:
            guard url.host != nil else { return nil }
            return url
        }
    }
}
