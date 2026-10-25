import Foundation

public enum ScriptItemAction: Equatable, Sendable {
    case openURL(URL)
    /// Run a shell command. Arguments come from the item's `param1`..`param9`.
    case runShell(command: String, arguments: [String])
    case unsupported(parameter: String)
    case none
}

public extension ScriptItem {
    /// What activating this item means. Only the parameters this app
    /// actually implements are reported as supported.
    var action: ScriptItemAction {
        if let bash = parameters["bash"] {
            if bash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .none
            }
            return .runShell(command: bash, arguments: Self.shellArguments(from: parameters))
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

    static func shellArguments(from parameters: [String: String]) -> [String] {
        var arguments: [String] = []
        for index in 1...9 {
            let key = "param\(index)"
            if let value = parameters[key] {
                arguments.append(value)
            }
        }
        return arguments
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
