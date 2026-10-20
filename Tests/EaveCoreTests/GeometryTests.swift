import Testing
@testable import EaveCore

@Suite("SeparatorWidth")
struct SeparatorWidthTests {
    @Test func neverExceedsAppKitLimit() {
        #expect(SeparatorWidth.collapsed(widestScreenWidth: 7_680) == 10_000)
    }

    @Test func coversUltrawide() {
        #expect(SeparatorWidth.collapsed(widestScreenWidth: 5_120) >= 5_120)
    }

    @Test func neverGoesBelowMinimum() {
        #expect(SeparatorWidth.collapsed(widestScreenWidth: 200) == 500)
    }

    @Test func doublesNormalScreen() {
        #expect(SeparatorWidth.collapsed(widestScreenWidth: 800) == 1_600)
    }
}

@Suite("NotchGeometry")
struct NotchGeometryTests {
    @Test func widthSubtractsBothAuxAreasAndNowhereIsNegative() {
        // MacBook Pro 14": layar 1512, area kiri ~663, kanan ~663
        let w = NotchGeometry.width(screenWidth: 1_512, auxLeftWidth: 663, auxRightWidth: 663)
        #expect(w == 190)
    }

    @Test func widthNeverNegativeOnBogusInput() {
        #expect(NotchGeometry.width(screenWidth: 100, auxLeftWidth: 400, auxRightWidth: 400) == 0)
    }

    @Test func heightPrefersSafeArea() {
        #expect(NotchGeometry.height(safeAreaTop: 38, isNotched: true, menuBarThickness: 24) == 38)
    }

    @Test func heightFallsBackTo37OnNotch() {
        #expect(NotchGeometry.height(safeAreaTop: 0, isNotched: true, menuBarThickness: 24) == 37)
    }

    @Test func heightFallsBackToMenuBarOnFlatScreen() {
        #expect(NotchGeometry.height(safeAreaTop: 0, isNotched: false, menuBarThickness: 24) == 24)
    }

    @Test func usableWidthAppliesGap() {
        let w = NotchGeometry.usableWidthRightOfNotch(screenMaxX: 1_512, notchMaxX: 851)
        #expect(w == 637.0)
    }
}

@Suite("RefreshInterval")
struct RefreshIntervalTests {
    @Test func parsesSeconds() {
        #expect(RefreshInterval.parse(fromFilename: "clock.5s.sh")?.seconds == 5)
    }

    @Test func parsesMinutes() {
        #expect(RefreshInterval.parse(fromFilename: "cpu.2m.sh")?.seconds == 120)
    }

    @Test func parsesHours() {
        #expect(RefreshInterval.parse(fromFilename: "git.1h.sh")?.seconds == 3_600)
    }

    @Test func parsesDays() {
        #expect(RefreshInterval.parse(fromFilename: "weather.1d.sh")?.seconds == 86_400)
    }

    @Test func returnsNilWhenNoInterval() {
        #expect(RefreshInterval.parse(fromFilename: "plain.sh") == nil)
    }

    @Test func returnsNilForUnknownUnit() {
        #expect(RefreshInterval.parse(fromFilename: "foo.5x.sh") == nil)
    }

    @Test func returnsNilForZero() {
        #expect(RefreshInterval.parse(fromFilename: "foo.0m.sh") == nil)
    }
}
