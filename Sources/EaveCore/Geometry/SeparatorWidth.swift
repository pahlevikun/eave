import Foundation

// Lebar separator untuk mode basic (nol permission).
//
// Trik: satu NSStatusItem yang lebarnya digelembungkan ke ~2x lebar layar,
// sehingga semua ikon di kirinya terdorong keluar layar. AppKit membatasi
// panjang status item di 10.000pt.

public enum SeparatorWidth {
    /// Batas keras AppKit. Status item di atas ini tidak dirender.
    public static let maxLength: CGFloat = 10_000

    /// Lebar minimum supaya separator masih terlihat sebagai item.
    public static let expandedMin: CGFloat = 500

    /// Lebar saat section disembunyikan.
    ///
    /// Dihitung dari layar terlebar, bukan layar utama: menu bar diduplikasi
    /// ke setiap layar, dan separator yang sempit di layar ultrawide
    /// meninggalkan sebagian ikon tetap terlihat.
    public static func collapsed(widestScreenWidth: CGFloat) -> CGFloat {
        min(max(expandedMin, widestScreenWidth * 2), maxLength)
    }
}
