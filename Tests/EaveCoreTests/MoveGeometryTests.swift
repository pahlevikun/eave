import Foundation
import Testing
@testable import EaveCore

@Suite("MoveGeometry")
struct MoveGeometryTests {
    private let start = Point(x: 10, y: 20)
    private let end = Point(x: 100, y: 80)

    @Test func dragPathCountMatchesClampedSteps() {
        let path = MoveGeometry.dragPath(from: start, to: end, steps: 10)
        #expect(path.count == 10)
    }

    @Test func dragPathEndpointsMatchFromAndTo() {
        let path = MoveGeometry.dragPath(from: start, to: end, steps: 8)
        #expect(path.first == start)
        #expect(path.last == end)
    }

    @Test func dragPathClampsLowStepsToFour() {
        #expect(MoveGeometry.dragPath(from: start, to: end, steps: 0).count == 4)
        #expect(MoveGeometry.dragPath(from: start, to: end, steps: 1).count == 4)
    }

    @Test func dragPathClampsHighStepsToTwentyFour() {
        #expect(MoveGeometry.dragPath(from: start, to: end, steps: 100).count == 24)
    }

    @Test func dragPathWithIdenticalEndpointsRepeatsPoint() {
        let point = Point(x: 5, y: 5)
        let path = MoveGeometry.dragPath(from: point, to: point, steps: 6)
        #expect(path.count == 6)
        #expect(path.allSatisfy { $0 == point })
    }
}
