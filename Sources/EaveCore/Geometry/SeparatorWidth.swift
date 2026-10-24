import Foundation

// Separator width for basic mode, which needs no permissions.
//
// The trick: one NSStatusItem inflated to roughly twice the widest screen, so
// every icon to its left is pushed off-screen. AppKit caps a status item at
// 10,000 pt.

public enum SeparatorWidth {
    /// AppKit hard cap. A status item above this is not rendered.
    public static let maxLength: CGFloat = 10_000

    /// Minimum width so the separator still reads as an item.
    public static let expandedMin: CGFloat = 500

    /// Width while the section is hidden.
    ///
    /// Computed from the widest screen, not the main one: the menu bar is
    /// duplicated to every display, and a narrow separator on an ultrawide
    /// leaves part of the row still visible.
    public static func collapsed(widestScreenWidth: CGFloat) -> CGFloat {
        min(max(expandedMin, widestScreenWidth * 2), maxLength)
    }
}
