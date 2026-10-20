import Foundation

/// Satu baris output plugin, siap dirender ke menu bar, notch tray, atau
/// Touch Bar.
public struct ScriptItem: Equatable, Identifiable, Sendable {
    public var title: String
    public var namespace: String
    public var parameters: [String: String]
    public var children: [ScriptItem]
    public var isSeparator: Bool

    /// Identitas stabil lintas refresh: namespace plugin + judul baris.
    public var id: String { "\(namespace):\(title)" }

    public init(
        title: String,
        namespace: String,
        parameters: [String: String] = [:],
        children: [ScriptItem] = [],
        isSeparator: Bool = false
    ) {
        self.title = title
        self.namespace = namespace
        self.parameters = parameters
        self.children = children
        self.isSeparator = isSeparator
    }
}

/// Aksi yang bisa dipasang ke satu item.
public enum ScriptAction: Equatable, Sendable {
    case shell(path: String, arguments: [String])
    case appleScript(source: String)
    case openURL(String)
}

/// Interval refresh, diurai dari nama file plugin.
///
/// Konvensi xbar: `foo.5s.sh`, `bar.2m.sh`, `baz.1h.sh`, `qux.1d.sh`.
public struct RefreshInterval: Equatable, Sendable {
    public let seconds: Int

    public init(seconds: Int) {
        self.seconds = max(1, seconds)
    }

    public static let `default` = RefreshInterval(seconds: 60)

    /// Mengurai akhiran interval dari nama file, mengembalikan `nil` kalau
    /// tidak ada. Nama file tanpa akhiran tetap valid, hanya memakai default.
    public static func parse(fromFilename name: String) -> RefreshInterval? {
        // Buang ekstensi terakhir dulu: "foo.5m.sh" -> "foo.5m"
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
        return RefreshInterval(seconds: value * multiplier)
    }
}
