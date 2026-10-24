#if canImport(AppKit)
import AppKit
import CoreGraphics
import EaveCore

private extension CGEventField {
    static let menuBarWindowID = CGEventField(rawValue: 0x33)!
}

@MainActor
public final class ItemMover {
    public struct Item: Equatable, Sendable {
        public let id: String
        public let frame: CGRect
        public let ownerPID: pid_t

        public init(id: String, frame: CGRect, ownerPID: pid_t) {
            self.id = id
            self.frame = frame
            self.ownerPID = ownerPID
        }
    }

    public typealias FrameProvider = (String) -> CGRect?

    private let frameProvider: FrameProvider

    public init(frameProvider: @escaping FrameProvider = { _ in nil }) {
        self.frameProvider = frameProvider
    }

    /// Returns true when the item's frame actually changed.
    @discardableResult
    public func move(_ item: Item, toX targetX: CGFloat) -> Bool {
        let before = item.frame
        parkCursor()

        guard let windowID = windowID(for: item) else {
            parkCursor()
            return false
        }

        let source = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let destination = CGPoint(x: targetX, y: item.frame.midY)
        let path = MoveGeometry.dragPath(
            from: Point(x: source.x, y: source.y),
            to: Point(x: destination.x, y: destination.y),
            steps: 12
        )

        guard postCommandDrag(
            item: item,
            windowID: windowID,
            path: path
        ) else {
            parkCursor()
            return false
        }

        parkCursor()

        guard let after = frameProvider(item.id) else {
            return false
        }
        return abs(after.midX - before.midX) > 0.5
    }

    private func parkCursor() {
        let parked = MoveGeometry.parkingPoint()
        let point = CGPoint(x: parked.x, y: parked.y)
        guard let move = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        move.post(tap: .cgSessionEventTap)
    }

    private func postCommandDrag(
        item: Item,
        windowID: CGWindowID,
        path: [Point]
    ) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        guard let first = path.first, let last = path.last else { return false }

        let start = CGPoint(x: first.x, y: first.y)
        let end = CGPoint(x: last.x, y: last.y)

        postCommandKeyDown(source: source)

        guard let press = mouseEvent(
            source: source,
            type: .leftMouseDown,
            location: start,
            windowID: windowID,
            pid: item.ownerPID
        ) else {
            postCommandKeyUp(source: source)
            return false
        }
        press.setIntegerValueField(.mouseEventClickState, value: 1)
        press.post(tap: .cgSessionEventTap)

        for point in path.dropFirst() {
            let location = CGPoint(x: point.x, y: point.y)
            guard let drag = mouseEvent(
                source: source,
                type: .leftMouseDragged,
                location: location,
                windowID: windowID,
                pid: item.ownerPID
            ) else { continue }
            drag.post(tap: .cgSessionEventTap)
            usleep(2_500)
        }

        guard let release = mouseEvent(
            source: source,
            type: .leftMouseUp,
            location: end,
            windowID: windowID,
            pid: item.ownerPID
        ) else {
            postCommandKeyUp(source: source)
            return false
        }
        release.post(tap: .cgSessionEventTap)
        postCommandKeyUp(source: source)
        return true
    }

    private func mouseEvent(
        source: CGEventSource,
        type: CGEventType,
        location: CGPoint,
        windowID: CGWindowID,
        pid: pid_t
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else { return nil }
        event.flags = .maskCommand
        let wid = Int64(windowID)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: wid)
        event.setIntegerValueField(
            .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
            value: wid
        )
        event.setIntegerValueField(.menuBarWindowID, value: wid)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        return event
    }

    private func postCommandKeyDown(source: CGEventSource) {
        guard let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x37,
            keyDown: true
        ) else { return }
        down.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
    }

    private func postCommandKeyUp(source: CGEventSource) {
        guard let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x37,
            keyDown: false
        ) else { return }
        up.post(tap: .cgSessionEventTap)
    }

    private func windowID(for item: Item) -> CGWindowID? {
        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for info in list {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int32,
                  owner == item.ownerPID,
                  let wid = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            if let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
               let x = bounds["X"], let y = bounds["Y"],
               let w = bounds["Width"], let h = bounds["Height"]
            {
                let rect = CGRect(x: x, y: y, width: w, height: h)
                if rect.contains(point) {
                    return wid
                }
            }
        }
        return nil
    }
}
#endif
