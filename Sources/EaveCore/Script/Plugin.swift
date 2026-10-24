import Foundation

/// One plugin file on disk.
///
/// A plugin is an executable file whose name carries its refresh interval
/// (`clock.5s.sh`). That is the whole registration mechanism: no manifest, no
/// database. xbar works this way, so existing plugin folders work as-is.
public struct Plugin: Equatable, Identifiable, Sendable {
    /// Stable identity across rescans: the file's last path component.
    public var id: String { filename }

    public let filename: String
    public let path: String
    public let interval: RefreshInterval

    /// Namespace used to keep two plugins' item ids apart. Filename minus
    /// extension minus interval, so `clock.5s.sh` becomes `clock`.
    public let namespace: String

    public init(filename: String, path: String, interval: RefreshInterval) {
        self.filename = filename
        self.path = path
        self.interval = interval
        self.namespace = Plugin.namespace(fromFilename: filename)
    }

    /// Strips the extension and a trailing interval marker.
    ///
    /// `clock.5s.sh` -> `clock`, `git-status.sh` -> `git-status`,
    /// `weather.1d.sh` -> `weather`.
    public static func namespace(fromFilename filename: String) -> String {
        var base = (filename as NSString).deletingPathExtension
        let tail = (base as NSString).pathExtension
        if RefreshInterval.parse(fromFilename: filename) != nil, !tail.isEmpty {
            base = (base as NSString).deletingPathExtension
        }
        return base.isEmpty ? filename : base
    }
}

/// Finds plugin files in a directory.
public enum PluginDiscovery {
    public enum ScanError: Error, Equatable {
        case directoryMissing(String)
    }

    /// Lists executable files in `directory`, sorted by filename so the menu
    /// order is stable between launches.
    ///
    /// Non-executable files are skipped rather than reported: a plugin folder
    /// commonly holds READMEs, `.vars.json` files, and disabled copies named
    /// `.disabled`.
    public static func scan(directory: String) throws -> [Plugin] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ScanError.directoryMissing(directory)
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return names
            .filter { !$0.hasPrefix(".") }
            .sorted()
            .compactMap { name -> Plugin? in
                let path = (directory as NSString).appendingPathComponent(name)
                guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
                let interval = RefreshInterval.parse(fromFilename: name) ?? .default
                return Plugin(filename: name, path: path, interval: interval)
            }
    }
}
