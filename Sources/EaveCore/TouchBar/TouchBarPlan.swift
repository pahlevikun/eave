import Foundation

public struct TouchBarEntry: Equatable, Sendable {
    public let id: String
    public let title: String
    public let isSpacer: Bool

    public init(id: String, title: String, isSpacer: Bool = false) {
        self.id = id
        self.title = title
        self.isSpacer = isSpacer
    }
}

public enum TouchBarPlan {
    public struct Plan: Equatable, Sendable {
        public let shown: [TouchBarEntry]
        public let overflowed: [TouchBarEntry]
        /// Width the shown entries need, for a test to assert the cap holds.
        public let usedWidth: Double

        public init(shown: [TouchBarEntry], overflowed: [TouchBarEntry], usedWidth: Double) {
            self.shown = shown
            self.overflowed = overflowed
            self.usedWidth = usedWidth
        }
    }

    /// Splits entries so no more than `maxVisible` non-spacer entries are
    /// shown. Spacers are dropped from the count but kept in order.
    ///
    /// A cap exists because AppKit silently truncates a Touch Bar that is too
    /// long, and truncation from the right looks like a bug in the plugin.
    ///
    /// `widthOfEntry` is injected so the test does not guess glyph widths.
    public static func plan(
        entries: [TouchBarEntry],
        maxVisible: Int,
        widthOfEntry: (TouchBarEntry) -> Double
    ) -> Plan {
        let cap = max(maxVisible, 0)
        var shown: [TouchBarEntry] = []
        var overflowed: [TouchBarEntry] = []
        var visibleCount = 0

        for entry in entries {
            if entry.isSpacer {
                shown.append(entry)
                continue
            }
            if visibleCount < cap {
                shown.append(entry)
                visibleCount += 1
            } else {
                overflowed.append(entry)
            }
        }

        let usedWidth = shown.reduce(0) { partial, entry in
            partial + widthOfEntry(entry)
        }

        return Plan(shown: shown, overflowed: overflowed, usedWidth: usedWidth)
    }
}
