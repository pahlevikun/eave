import EaveCore
import Foundation

@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "com.pahlevikun.eave.preferences") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AppPreferences {
        let data = defaults.data(forKey: key)
        return AppPreferencesCodec.decode(data)
    }

    /// Returns false when the write failed, so the caller can say so.
    @discardableResult
    func save(_ preferences: AppPreferences) -> Bool {
        do {
            let data = try AppPreferencesCodec.encode(preferences)
            defaults.set(data, forKey: key)
            return true
        } catch {
            return false
        }
    }
}
