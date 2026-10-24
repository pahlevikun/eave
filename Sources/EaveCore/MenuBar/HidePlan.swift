import Foundation

public struct SectionMembership: Equatable, Sendable {
    public let id: String
    public let isMovable: Bool
    public let isHideable: Bool

    public init(id: String, isMovable: Bool, isHideable: Bool) {
        self.id = id
        self.isMovable = isMovable
        self.isHideable = isHideable
    }
}

public enum HidePlan {
    public enum Decision: Equatable, Sendable {
        /// Toggle the separator length. No per-item work, no permissions.
        case separator
        /// Move these items, then toggle the separator.
        case separateThenMove(movable: [String], skipped: [String])
    }

    /// Chooses the cheapest way to hide a section.
    ///
    /// With no accessibility permission, only the separator is available, so
    /// items stay where they are. With permission, movable and hideable items
    /// get separated first and the rest are reported as skipped rather than
    /// retried forever.
    public static func decide(
        members: [SectionMembership],
        hasAccessibility: Bool
    ) -> Decision {
        guard hasAccessibility else {
            return .separator
        }

        var movable: [String] = []
        var skipped: [String] = []

        for member in members {
            if member.isMovable, member.isHideable {
                movable.append(member.id)
            } else {
                skipped.append(member.id)
            }
        }

        return .separateThenMove(movable: movable, skipped: skipped)
    }
}
