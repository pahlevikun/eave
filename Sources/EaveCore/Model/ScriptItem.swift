import Foundation

/// One line of plugin output, ready to render to the menu bar, the notch
/// tray, or the Touch Bar.
public struct ScriptItem: Equatable, Identifiable, Sendable {
    public var title: String
    public var namespace: String
    public var parameters: [String: String]
    public var children: [ScriptItem]

    /// Stable identity across refreshes: plugin namespace plus line title.
    public var id: String { "\(namespace):\(title)" }

    public init(
        title: String,
        namespace: String,
        parameters: [String: String] = [:],
        children: [ScriptItem] = []
    ) {
        self.title = title
        self.namespace = namespace
        self.parameters = parameters
        self.children = children
    }
}

/// Refresh interval, parsed from a plugin's filename.
///
/// xbar convention: `foo.5s.sh`, `bar.2m.sh`, `baz.1h.sh`, `qux.1d.sh`.
public struct RefreshInterval: Equatable, Sendable {
    public let seconds: Int

    public init(seconds: Int) {
        self.seconds = max(1, seconds)
    }

    public static let `default` = RefreshInterval(seconds: 60)

    /// Parses the interval suffix from a filename. Returns `nil` when there is
    /// none, which is not an error: a plugin without a suffix runs on the
    /// default interval.
    public static func parse(fromFilename name: String) -> RefreshInterval? {
        // Drop the real extension first: "foo.5m.sh" -> "foo.5m"
        let base = (name as NSString).deletingPathExtension
        let last = (base as NSString).pathExtension
        guard !last.isEmpty else { return nil }

        let unit = last.last
        let numberPart = String(last.dropLast())
        guard let value = Int(numberPart), value > 0 else { return nil }

        let multiplier: Int
        switch unit {
        case "s": multiplier = 1
        case "m": multiplier = 60
        case "h": multiplier = 3_600
        case "d": multiplier = 86_400
        default: return nil
        }
        let (seconds, overflow) = value.multipliedReportingOverflow(by: multiplier)
        guard !overflow else { return nil }
        return RefreshInterval(seconds: seconds)
    }
}
