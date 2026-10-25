import Foundation
import Testing
@testable import EaveCore

@Suite("AppPreferences")
struct AppPreferencesTests {
    @Test func defaultsSurviveRoundTrip() throws {
        let encoded = try AppPreferencesCodec.encode(.default)
        let decoded = AppPreferencesCodec.decode(encoded)
        #expect(decoded == .default)
    }

    @Test func nilDataReturnsDefaults() {
        #expect(AppPreferencesCodec.decode(nil) == .default)
    }

    @Test func garbageBytesReturnDefaults() {
        let garbage = Data("not json at all".utf8)
        #expect(AppPreferencesCodec.decode(garbage) == .default)
    }

    @Test func higherSchemaVersionReturnsDefaults() throws {
        let payload = """
        {"schemaVersion":999,"hiddenSectionCollapsed":true,"touchBarEnabled":false}
        """
        let data = Data(payload.utf8)
        #expect(AppPreferencesCodec.decode(data) == .default)
    }

    @Test func touchBarDisabledDecodesExplicitly() throws {
        let payload = """
        {"schemaVersion":1,"hiddenSectionCollapsed":false,"touchBarEnabled":false}
        """
        let data = Data(payload.utf8)
        let decoded = AppPreferencesCodec.decode(data)
        #expect(decoded.touchBarEnabled == false)
        #expect(decoded.hiddenSectionCollapsed == false)
        #expect(decoded.schemaVersion == 1)
    }

    @Test func missingKeyReturnsDefaults() {
        let payload = """
        {"schemaVersion":1,"hiddenSectionCollapsed":false}
        """
        let data = Data(payload.utf8)
        #expect(AppPreferencesCodec.decode(data) == .default)
    }
}
