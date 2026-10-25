import Foundation

public struct NotchTrayItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let width: CGFloat
    public let scriptItem: ScriptItem

    public init(id: String, title: String, width: CGFloat, scriptItem: ScriptItem) {
        self.id = id
        self.title = title
        self.width = width
        self.scriptItem = scriptItem
    }
}

public enum NotchTrayModel {
    public struct Plan: Equatable, Sendable {
        /// Items that fit in the bar, left to right, in input order.
        public let kept: [NotchTrayItem]
        /// Items moved to the tray, in input order.
        public let overflowed: [NotchTrayItem]

        public init(kept: [NotchTrayItem], overflowed: [NotchTrayItem]) {
            self.kept = kept
            self.overflowed = overflowed
        }
    }

    /// Packs items into `availableWidth`, keeping input order.
    ///
    /// Items are taken left to right until the next one would not fit. That
    /// item and everything after it overflow. Skipping a wide item to fit a
    /// narrow one behind it would reorder the bar behind the user's back,
    /// which is worse than one item moving to the tray.
    ///
    /// A non-positive or non-finite `availableWidth` keeps nothing, so a
    /// broken measurement never silently claims the bar is fine.
    public static func plan(items: [NotchTrayItem], availableWidth: CGFloat) -> Plan {
        guard availableWidth > 0, availableWidth.isFinite else {
            return Plan(kept: [], overflowed: items)
        }

        var kept: [NotchTrayItem] = []
        var used: CGFloat = 0

        for item in items {
            let next = used + item.width
            if next > availableWidth {
                let overflowStart = kept.count
                let overflowed = Array(items[overflowStart...])
                return Plan(kept: kept, overflowed: overflowed)
            }
            kept.append(item)
            used = next
        }

        return Plan(kept: kept, overflowed: [])
    }
}
