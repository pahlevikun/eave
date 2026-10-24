import Foundation

/// One plugin file on disk.
///
/// A plugin is an executable file whose name carries its refresh interval
/// (`clock.5s.sh`). That is the whole registration mechanism: no manifest, no
/// database. xbar works this way, so existing plugin folders work as-is.
///
/// Three names, and they are not the same thing:
///
/// | Name | Example | Used for | Unique because |
/// |---|---|---|---|
/// | `id` | `clock.5s.sh` | run state, diagnostics | two files in one folder cannot share a filename |
/// | `namespace` | `clock` | prefix of every item id | enforced by `PluginDiscovery` |
/// | `filename` | `clock.5s.sh` | what Finder and Settings show | same as `id` |
public struct Plugin: Equatable, Identifiable, Sendable {
    /// Identity for run state. The filename, because a directory cannot hold
    /// two files with the same name. A rename is a new plugin, which is why
    /// `namespace` exists separately: it survives an interval change.
    public var id: String { filename }

    public let filename: String
    public let path: String
    public let interval: RefreshInterval

    /// Prefix for every `ScriptItem.id` this plugin produces.
    ///
    /// Derived from the filename with the extension and the interval suffix
    /// removed: `clock.5s.sh` becomes `clock`. Renaming `clock.5s.sh` to
    /// `clock.1m.sh` therefore keeps the same namespace, which matches what a
    /// person means by editing the interval: same plugin, slower.
    public let namespace: String

    public init(filename: String, path: String, interval: RefreshInterval) {
        self.filename = filename
        self.path = path
        self.interval = interval
        self.namespace = Plugin.namespace(fromFilename: filename)
    }

    /// Strips the extension, then the interval suffix if there is one.
    ///
    /// Two explicit stages, each with its example:
    /// 1. `clock.5s.sh` -> `clock.5s` (drop the file extension)
    /// 2. `clock.5s` -> `clock` (drop the interval, because it parsed)
    ///
    /// `git-status.sh` keeps its dash and becomes `git-status`, since `status`
    /// is not an interval.
    public static func namespace(fromFilename filename: String) -> String {
        let withoutExtension = (filename as NSString).deletingPathExtension
        guard RefreshInterval.parse(fromFilename: filename) != nil else {
            return withoutExtension.isEmpty ? filename : withoutExtension
        }
        let withoutInterval = (withoutExtension as NSString).deletingPathExtension
        return withoutInterval.isEmpty ? filename : withoutInterval
    }
}

/// Finds plugin files in a directory.
public enum PluginDiscovery {
    public enum ScanError: Error, Equatable {
        case directoryMissing(String)
    }

    /// A plugin file that was found but not loaded, and why.
    ///
    /// Reported rather than thrown: one bad file must not hide the rest, and
    /// the Settings list needs a sentence to show next to the file.
    public struct Rejection: Equatable, Sendable {
        public let filename: String
        public let reason: Reason

        public enum Reason: Equatable, Sendable {
            /// Another file already claimed this namespace.
            case duplicateNamespace(kept: String)
        }
    }

    public struct ScanResult: Equatable, Sendable {
        public let plugins: [Plugin]
        public let rejections: [Rejection]
    }

    /// Lists executable files in `directory`, sorted by filename so the menu
    /// order is stable between launches.
    ///
    /// Skipped silently: non-executable files and dotfiles. A plugin folder
    /// normally holds READMEs, `.vars.json` files, and disabled copies.
    ///
    /// Two files that resolve to the same namespace are a real ambiguity:
    /// `clock.5s.sh` and `clock.1m.sh` claim to be the same plugin at two
    /// rates. The first in sort order wins and the second is reported. Guessing
    /// would be worse than refusing, because both would draw into one status
    /// item and overwrite each other.
    public static func scan(directory: String) throws -> ScanResult {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ScanError.directoryMissing(directory)
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        var plugins: [Plugin] = []
        var rejections: [Rejection] = []
        var namespaceOwner: [String: String] = [:]

        for name in names.filter({ !$0.hasPrefix(".") }).sorted() {
            let path = (directory as NSString).appendingPathComponent(name)
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }

            let interval = RefreshInterval.parse(fromFilename: name) ?? .default
            let plugin = Plugin(filename: name, path: path, interval: interval)

            if let owner = namespaceOwner[plugin.namespace] {
                rejections.append(
                    Rejection(filename: name, reason: .duplicateNamespace(kept: owner))
                )
                continue
            }
            namespaceOwner[plugin.namespace] = name
            plugins.append(plugin)
        }

        return ScanResult(plugins: plugins, rejections: rejections)
    }
}
