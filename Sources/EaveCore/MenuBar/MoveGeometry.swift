import Foundation

public struct Point: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum MoveGeometry {
    /// Where the cursor is parked while a drag is in flight.
    ///
    /// Far outside any display, so the synthetic movement is not drawn over
    /// a real screen and does not fight the user's own mouse.
    public static func parkingPoint() -> Point {
        // Same off-screen coordinates Ice and Thaw converged on.
        Point(x: -27_405, y: -27_405)
    }

    /// Point used when a press has to happen at the far right edge of a menu
    /// bar, which is where items are pushed when a section is hidden.
    public static func offscreenPoint(forBarWidth width: Double, barHeight: Double) -> Point {
        Point(x: width + 1_200, y: barHeight / 2)
    }

    /// Cursor travel for one move, from the item's frame to its destination.
    ///
    /// Steps are clamped: fewer than 4 makes AppKit treat it as a teleport and
    /// refuses the reorder, more than 24 wastes 60 ms per item for no gain.
    public static func dragPath(from: Point, to: Point, steps: Int) -> [Point] {
        let count = min(max(steps, 4), 24)
        if count == 1 {
            return [from]
        }
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            return Point(
                x: from.x + (to.x - from.x) * t,
                y: from.y + (to.y - from.y) * t
            )
        }
    }
}
