import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var hiddenSectionCollapsed: Bool
    public var touchBarEnabled: Bool

    public static let `default` = AppPreferences(
        schemaVersion: currentSchemaVersion,
        hiddenSectionCollapsed: false,
        touchBarEnabled: true
    )

    public init(schemaVersion: Int, hiddenSectionCollapsed: Bool, touchBarEnabled: Bool) {
        self.schemaVersion = schemaVersion
        self.hiddenSectionCollapsed = hiddenSectionCollapsed
        self.touchBarEnabled = touchBarEnabled
    }
}

public enum AppPreferencesCodec {
    /// Decodes stored bytes, or returns defaults when the data is missing,
    /// truncated, of an unknown schema version, or not JSON at all.
    public static func decode(_ data: Data?) -> AppPreferences {
        guard let data, !data.isEmpty else {
            return .default
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(AppPreferences.self, from: data) else {
            return .default
        }

        if decoded.schemaVersion > AppPreferences.currentSchemaVersion {
            reportUnknownNewerSchema(decoded.schemaVersion)
            return .default
        }

        if decoded.schemaVersion < AppPreferences.currentSchemaVersion {
            return .default
        }

        return decoded
    }

    /// Encodes to JSON. Throws only for a value the type cannot represent,
    /// which for this shape means never. Do not swallow the throw silently.
    public static func encode(_ preferences: AppPreferences) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(preferences)
    }

    private static func reportUnknownNewerSchema(_ version: Int) {
        let message =
            "Eave: preferences schema \(version) is newer than supported "
            + "\(AppPreferences.currentSchemaVersion); using defaults\n"
        // `stderr` is a shared mutable global, so Swift 6 refuses to touch it
        // from a static function. The standard error handle is the safe door.
        FileHandle.standardError.write(Data(message.utf8))
    }
}
