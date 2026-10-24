import Foundation

/// Notch geometry. Pure, so it can be tested without a screen.
public enum NotchGeometry {
    /// The gap macOS leaves on both sides of the notch.
    public static let gap: CGFloat = 24

    /// Notch width from the two areas beside it.
    ///
    /// `+4` because those areas don't touch the notch edge, so without this
    /// correction the notch width comes out a few points short.
    public static func width(
        screenWidth: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGFloat {
        max(0, screenWidth - auxLeftWidth - auxRightWidth + 4)
    }

    /// Notch height: the safe area when present, otherwise the menu bar
    /// height for the display's shape.
    public static func height(
        safeAreaTop: CGFloat,
        isNotched: Bool,
        menuBarThickness: CGFloat
    ) -> CGFloat {
        if safeAreaTop > 0 { return safeAreaTop }
        return isNotched ? 37 : menuBarThickness
    }

    /// Width available to items right of the notch, after the gap.
    public static func usableWidthRightOfNotch(
        screenMaxX: CGFloat,
        notchMaxX: CGFloat
    ) -> CGFloat {
        max(0, screenMaxX - (notchMaxX + gap))
    }
}
