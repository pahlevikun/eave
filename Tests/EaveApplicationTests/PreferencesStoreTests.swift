import Foundation
import Testing
import EaveCore
@testable import EaveApplication

#if os(macOS)
@Suite("PreferencesStore", .serialized)
@MainActor
struct PreferencesStoreTests {
    private func isolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "eave-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    @Test func roundTripThroughIsolatedSuite() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let custom = AppPreferences(
            schemaVersion: AppPreferences.currentSchemaVersion,
            hiddenSectionCollapsed: true,
            touchBarEnabled: false
        )
        #expect(store.save(custom))
        #expect(store.load() == custom)
    }

    @Test func garbageInSuiteReturnsDefaults() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        defaults.set(Data("garbage".utf8), forKey: "com.pahlevikun.eave.preferences")
        let store = PreferencesStore(defaults: defaults)
        #expect(store.load() == .default)
    }

    @Test func missingKeyReturnsDefaults() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        #expect(store.load() == .default)
    }

    @Test func savingTwiceKeepsLastValue() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let first = AppPreferences(
            schemaVersion: AppPreferences.currentSchemaVersion,
            hiddenSectionCollapsed: false,
            touchBarEnabled: true
        )
        let second = AppPreferences(
            schemaVersion: AppPreferences.currentSchemaVersion,
            hiddenSectionCollapsed: true,
            touchBarEnabled: false
        )
        #expect(store.save(first))
        #expect(store.save(second))
        #expect(store.load() == second)
    }
}
#endif
