import Foundation

/// Geometri notch, murni supaya bisa diuji tanpa layar.
public enum NotchGeometry {
    /// Gap yang ditinggalkan macOS di kiri dan kanan notch.
    public static let gap: CGFloat = 24

    /// Lebar notch dari dua area di kiri dan kanannya.
    ///
    /// `+4` karena kedua area itu tidak menyentuh tepi notch, jadi tanpa
    /// pembulatan ini lebar notch meleset beberapa poin.
    public static func width(
        screenWidth: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGFloat {
        max(0, screenWidth - auxLeftWidth - auxRightWidth + 4)
    }

    /// Tinggi notch: pakai safe area, fallback ke tinggi menu bar.
    public static func height(
        safeAreaTop: CGFloat,
        isNotched: Bool,
        menuBarThickness: CGFloat
    ) -> CGFloat {
        if safeAreaTop > 0 { return safeAreaTop }
        return isNotched ? 37 : menuBarThickness
    }

    /// Lebar area yang bisa dipakai item di kanan notch.
    public static func usableWidthRightOfNotch(
        screenMaxX: CGFloat,
        notchMaxX: CGFloat
    ) -> CGFloat {
        max(0, screenMaxX - (notchMaxX + gap))
    }
}
