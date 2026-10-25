import Foundation

public struct PanelRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var midX: Double { x + width / 2 }
    public var minY: Double { y }
    public var maxY: Double { y + height }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum NotchPanelGeometry {
    /// `notch` is absent on displays without auxiliary top areas.
    public static func frame(
        screen: PanelRect, visibleFrame: PanelRect, notch: PanelRect?,
        menuBarHeight: Double, contentHeight: Double
    ) -> PanelRect {
        let margin: Double = 8
        let width = min(280, max(0, screen.width - margin * 2))
        let top = min(visibleFrame.maxY, screen.maxY - max(menuBarHeight, notch?.height ?? 0)) - margin
        let bottom = max(screen.minY, visibleFrame.minY) + margin
        let height = min(max(0, top - bottom), min(360, max(88, contentHeight)))
        let center = notch?.midX ?? screen.midX
        let x = min(max(screen.minX + margin, center - width / 2), screen.maxX - margin - width)
        return PanelRect(x: x, y: max(bottom, top - height), width: width, height: height)
    }
}
