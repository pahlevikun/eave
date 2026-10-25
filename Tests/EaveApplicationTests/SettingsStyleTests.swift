import AppKit
import Testing
@testable import EaveApplication

@Suite("Adaptive settings surfaces", .serialized)
@MainActor
struct SettingsStyleTests {
    private func components(_ color: NSColor, in appearance: NSAppearance) throws -> [CGFloat] {
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        let rgb = try #require(resolved)
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
    }

    @Test func surfacesResolveAgainWhenAppearanceChanges() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let panel = SettingsStyle.color(.panel, increaseContrast: false)
        let detail = SettingsStyle.color(.detail, increaseContrast: false)
        let lightPanel = try components(panel, in: light)
        let darkPanel = try components(panel, in: dark)
        let lightDetail = try components(detail, in: light)
        let darkDetail = try components(detail, in: dark)

        #expect(abs(lightPanel[0] - 251.0 / 255) < 0.001)
        #expect(abs(darkPanel[0] - 24.0 / 255) < 0.001)
        #expect(abs(lightDetail[1] - 238.0 / 255) < 0.001)
        #expect(abs(darkDetail[1] - 38.0 / 255) < 0.001)
        #expect(try components(panel, in: light) == lightPanel)
        #expect(try components(detail, in: light) == lightDetail)
    }

    @Test func increasedContrastUsesNativeSurfacesInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try #require(NSAppearance(named: name))
            let actualPanel = try components(SettingsStyle.color(.panel, increaseContrast: true), in: appearance)
            let nativePanel = try components(.windowBackgroundColor, in: appearance)
            let actualDetail = try components(SettingsStyle.color(.detail, increaseContrast: true), in: appearance)
            let nativeDetail = try components(.controlBackgroundColor, in: appearance)
            #expect(actualPanel == nativePanel)
            #expect(actualDetail == nativeDetail)
        }
    }
}
