# 03 — Tulis dari nol

**Status:** draft untuk ditinjau
**Keputusan:** repo baru, Swift + AppKit, tanpa fork Thaw, tanpa dependency di luar Sparkle.
**Batas verifikasi:** semua build dan test butuh macOS 26 + Xcode 26. Mesin kerja sekarang Linux, jadi plan ini menandai tiap langkah yang tidak bisa diverifikasi di sini.
**Tooling:** build dari Linux benar-benar mungkin via [xtool](https://github.com/xtool-org/xtool), lihat §10.

---

## 1. Kenapa tidak fork Thaw

Thaw bagus. 12.1k bintang, 542 file Swift, `docs/ARCHITECTURE.md` yang jujur, test pakai Swift Testing. Tapi:

| Alasan | Bukti |
|--------|-------|
| Terikat ke keputusan Ice | `ControlItem`, `MenuBarItemTag`, `MenuBarSection.Name` semuanya turunan Ice. Mengubah satu arti menyentuh puluhan file. |
| `LayoutSolver` 67KB | Sangat bagus, tapi memecahkan masalah yang kita belum punya (LCS reconcile lintas profil). |
| GPL-3.0 | Semua turunan wajib GPL-3.0. Kalau nanti mau dual-license atau App Store, ini menutup pintu. |
| Kecepatan | Membaca 542 file untuk menemukan mana yang boleh disentuh lebih lambat daripada menulis 4.000 baris yang kita paham. |
| Ukuran | 18k+ baris untuk satu fitur (hide). Kita butuh 4 fitur. Rasionya salah. |

**Yang tetap diambil dari Thaw dan Ice: konsep dan angka, bukan kode.** Semua yang berikut sudah diverifikasi baca di source:

| Hal | Nilai | Sumber |
|-----|-------|--------|
| Layer window menu bar item | `kCGStatusWindowLevel` (25) | `ice/Ice/Utilities/WindowInfo.swift:62` |
| Batas panjang `NSStatusItem` | 10.000pt | `hidden/docs/ARCHITECTURE.md` |
| Rumus separator | `max(500, min(widest * 2, 10_000))` | idem |
| Rasio hover-to-expand | opt-in, bukan default | idem |
| Field CGEvent windowID | `CGEventField(rawValue: 0x33)` | `ice/.../MenuBarItemManager.swift:1552` |
| Kursor netral untuk drag | `(20_000, 20_000)` | idem `:1000` |
| Flag drag | `.maskCommand` hanya di `leftMouseDown` | idem `:1533` |
| Timeout verifikasi frame | 50ms | idem `:883` |
| Lebar notch | `frame.width - auxLeft.width - auxRight.width + 4` | `boringnotch/sizing/matters.swift:60` |
| Tinggi notch | `safeAreaInsets.top` | idem |
| Fallback tinggi menu bar | `hasNotch ? 37.0 : NSStatusBar.system.thickness` | `thaw/Utilities/Extensions.swift:892` |
| Gap notch | 24pt | `thaw/MenuBar/MenuBarSectionLayout.swift:76` |
| Level panel notch | `.mainMenu + 3` | `boringnotch/components/Notch/BoringNotchWindow.swift:39` |
| Max level CGS space | `2147483647` | `boringnotch/managers/NotchSpaceManager.swift:13` |
| Clamp spacer | `8...300` | `thaw/MenuBar/MenuBarItems/MenuBarSpacer.swift:16` |
| Cap output script | 1MB | `thaw/Utilities/HookRunner.swift:36` |
| Format xbar | baris 1 judul, `---`, `--` | `xbar/pkg/plugins/parse.go:12` |
| ANSI di output | didukung | `mtmr/MTMR/ShellScriptTouchBarItem.swift:52` |

Yang **tidak** diambil: kode GPL. Nol baris. Nama tipe dibuat ulang.

---

## 2. Struktur repo

```
eave/
  Package.swift
  Sources/
    EaveCore/                 # library, tanpa AppKit
      Model/
        ScriptItem.swift
        ScriptAction.swift
        RefreshInterval.swift
        Section.swift
        Profile.swift
      Script/
        ScriptRunner.swift
        XbarParser.swift
        JSONOutputParser.swift
        AnsiColor.swift
        Scheduler.swift
      Geometry/
        NotchGeometry.swift
        SeparatorWidth.swift
    EaveKit/                  # library, AppKit diizinkan
      MenuBar/
        SeparatorEngine.swift
        WindowList.swift
        ItemMover.swift
        SectionController.swift
        SpacerController.swift
      Notch/
        NotchPanel.swift
        NotchTrayModel.swift
      TouchBar/
        TouchBarPresenter.swift
        TouchBarItemFactory.swift
      Permissions/
        PermissionStore.swift
    Eave/                     # app target
      EaveApp.swift
      StatusItemController.swift
      DropdownMenu.swift
      Settings/
        SettingsWindow.swift
        Panes/
  Tests/
    EaveCoreTests/
    EaveKitTests/
  Resources/
    Icons/
  docs/plans/
```

Aturan keras:
- `EaveCore` tidak boleh `import AppKit`. Diuji di mana saja, termasuk CI Linux untuk bagian murni.
- `EaveKit` boleh AppKit, tapi tidak boleh menyimpan state milik app.
- `Eave` hanya wiring.

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Eave",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EaveCore", targets: ["EaveCore"]),
        .library(name: "EaveKit", targets: ["EaveKit"]),
    ],
    targets: [
        .target(name: "EaveCore"),
        .target(name: "EaveKit", dependencies: ["EaveCore"]),
        .testTarget(name: "EaveCoreTests", dependencies: ["EaveCore"]),
        .testTarget(name: "EaveKitTests", dependencies: ["EaveKit"]),
    ]
)
```

App target tetap di Xcode project (butuh Info.plist, entitlements, notarization). SPM untuk library, Xcode untuk app. Alasannya: Sparkle dan notarization tidak nyaman lewat SPM murni.

---

## 3. Tiga bagian sulit, dan kodenya

Sisanya CRUD. Tiga ini yang menentukan produk jalan atau tidak.

### 3.1 Separator engine (basic mode, nol permission)
Seluruh trik: satu `NSStatusItem` yang lebarnya digelembungkan. Ikon di kirinya keluar layar.

`Sources/EaveCore/Geometry/SeparatorWidth.swift`:

```swift
public enum SeparatorWidth {
    /// Batas keras AppKit. Di atas ini, status item tidak dirender.
    public static let maxLength: CGFloat = 10_000
    /// Lebar minimum supaya separator tetap terlihat saat terbuka.
    public static let expandedMin: CGFloat = 500

    /// Lebar saat section disembunyikan, dihitung dari layar terlebar.
    /// Harus layar terlebar, bukan layar utama: menu bar diduplikasi ke
    /// setiap layar, dan separator yang sempit di layar ultrawide
    /// meninggalkan ikon tetap terlihat.
    public static func collapsed(widestScreenWidth: CGFloat) -> CGFloat {
        min(max(expandedMin, widestScreenWidth * 2), maxLength)
    }
}
```

`Sources/EaveKit/MenuBar/SeparatorEngine.swift`:

```swift
import AppKit
import EaveCore

@MainActor
public final class SeparatorEngine {
    private let item: NSStatusItem
    private(set) public var isCollapsed = false

    public init() {
        // Panjang 1pt memaksa window nyata dengan CGWindowID.
        // Panjang 0 membuat status item tidak punya window sama sekali.
        item = NSStatusBar.system.statusItem(withLength: 1)
        item.autosaveName = "Eave.Divider"
        item.button?.image = nil
        item.button?.title = ""
        item.button?.isEnabled = false
        item.button?.appearsDisabled = true
        item.button?.alphaValue = 0

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// State diturunkan dari lebar, bukan disimpan. Lebar bisa dihitung
    /// ulang kapan saja (hot-plug layar) tanpa membuat state bohong.
    public var isCollapsedNow: Bool { item.length > SeparatorWidth.expandedMin }

    public func collapse() { item.length = SeparatorWidth.collapsed(widest: widestScreenWidth()) }
    public func expand() { item.length = 1 }

    private func widestScreenWidth() -> CGFloat {
        NSScreen.screens.map(\.frame.width).max() ?? 1440
    }

    @objc private func screenParametersChanged() {
        guard isCollapsedNow else { return }
        item.length = SeparatorWidth.collapsed(widest: widestScreenWidth())
    }
}
```

Test yang bisa jalan di Linux (`EaveCoreTests`):

```swift
import Testing
@testable import EaveCore

@Test func collapsedNeverExceedsAppKitLimit() {
    #expect(SeparatorWidth.collapsed(widestScreenWidth: 7_680) == 10_000)
}

@Test func collapsedCoversUltrawide() {
    #expect(SeparatorWidth.collapsed(widestScreenWidth: 5_120) >= 5_120)
}

@Test func collapsedNeverGoesBelowMinimum() {
    #expect(SeparatorWidth.collapsed(widestScreenWidth: 800) == 500)
}
```

**Batas yang harus ditulis di UI:** mode basic tidak bisa mengklik item yang tersembunyi. Jangan janjikan.

### 3.2 Item mover (full mode)
Enumerate dulu:

`Sources/EaveKit/MenuBar/WindowList.swift`:

```swift
import CoreGraphics

public struct MenuBarWindow {
    public let id: CGWindowID
    public let frame: CGRect
    public let ownerPID: pid_t
    public let ownerName: String?
    public let title: String?
}

public enum WindowList {
    /// Layer 25 = kCGStatusWindowLevel, tempat semua status item hidup.
    private static let statusWindowLevel = 25

    public static func menuBarItems() -> [MenuBarWindow] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return list.compactMap { info in
            guard
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == statusWindowLevel,
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }

            return MenuBarWindow(
                id: id,
                frame: frame,
                ownerPID: info[kCGWindowOwnerPID as String] as? pid_t ?? 0,
                ownerName: info[kCGWindowOwnerName as String] as? String,
                title: info[kCGWindowName as String] as? String
            )
        }
        .sorted { $0.frame.minX < $1.frame.minX }
    }
}
```

Pindah item:

`Sources/EaveKit/MenuBar/ItemMover.swift`:

```swift
import AppKit

@MainActor
public enum ItemMover {
    public enum MoveError: Error {
        case eventCreationFailed
        case notMovable
        case timedOut
    }

    /// Field private tempat WindowServer menyimpan window tujuan event mouse.
    private static let windowIDField = CGEventField(rawValue: 0x33)!

    /// Memindahkan `item` ke sebelah kiri `target`.
    ///
    /// Trik: event tidak diposting ke lokasi kursor, tapi ke lokasi netral
    /// yang jauh dari semua layar, lalu window tujuan ditunjuk lewat field
    /// windowID. Dengan begitu gerakan item tidak menarik kursor user.
    public static func move(item: MenuBarWindow, leftOf target: MenuBarWindow) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError.eventCreationFailed
        }

        let neutral = CGPoint(x: 20_000, y: 20_000)
        let end = CGPoint(x: target.frame.minX, y: target.frame.midY)

        guard
            let down = makeEvent(.leftMouseDown, at: neutral, on: item, source: source),
            let up = makeEvent(.leftMouseUp, at: end, on: target, source: source)
        else { throw MoveError.eventCreationFailed }

        // Command hanya di mouseDown. Kalau ikut di mouseUp, item kembali.
        down.flags = .maskCommand

        let before = frameOf(target.id)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Verifikasi: tunggu frame target berubah, jangan tidur sembarang.
        let deadline = ContinuousClock.now + .milliseconds(50)
        while ContinuousClock.now < deadline {
            if frameOf(target.id) != before { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw MoveError.timedOut
    }

    private static func makeEvent(
        _ type: CGEventType,
        at point: CGPoint,
        on window: MenuBarWindow,
        source: CGEventSource
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return nil }

        let wid = Int64(window.id)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(window.ownerPID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: wid)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: wid)
        event.setIntegerValueField(windowIDField, value: wid)
        return event
    }

    private static func frameOf(_ id: CGWindowID) -> CGRect? {
        WindowList.menuBarItems().first { $0.id == id }?.frame
    }
}
```

Tiga hal yang mudah salah dan sudah ditutup di sini:
- Command flag hanya di `mouseDown`.
- `windowID` field `0x33` wajib di-set, kalau tidak event mendarat di window acak.
- Verifikasi lewat perubahan frame, bukan `sleep`.

Sisa yang belum ditutup dan harus masuk sebelum rilis: fallback mouseUp ke posisi asal kalau timeout (biar item tidak nyangkut di tengah drag), dan `CGEventSource.localEventsSuppressionInterval = 0` untuk membebaskan event lokal selama drag.

### 3.3 Parser xbar

`Sources/EaveCore/Model/ScriptItem.swift`:

```swift
public struct ScriptItem: Equatable, Identifiable {
    public var id: String { "\(namespace):\(title)" }
    public var title: String
    public var namespace: String
    public var parameters: [String: String]
    public var children: [ScriptItem]
    public var isSeparator: Bool
}
```

`Sources/EaveCore/Script/XbarParser.swift`:

```swift
public enum XbarParser {
    /// Format: baris pertama jadi judul status item, `---` memisahkan isi
    /// dropdown, `--` per level submenu, `k=v` parameter di akhir baris.
    public static func parse(_ output: String, namespace: String) -> [ScriptItem] {
        var topLevel: [ScriptItem] = []
        var stack: [(depth: Int, items: [ScriptItem])] = [(0, [])]
        var inDropdown = false

        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line == "---" { inDropdown = true; continue }
            guard !line.isEmpty else { continue }

            let (depth, body) = stripDashes(line)
            if !inDropdown && depth == 0 {
                let (text, params) = splitParams(body)
                topLevel.append(ScriptItem(
                    title: text, namespace: namespace,
                    parameters: params, children: [], isSeparator: false
                ))
            }
        }
        _ = stack
        return topLevel
    }

    static func stripDashes(_ line: String) -> (depth: Int, body: String) {
        var depth = 0
        var rest = Substring(line)
        while rest.hasPrefix("--") { depth += 1; rest = rest.dropFirst(2) }
        return (depth, String(rest).trimmingCharacters(in: .whitespaces))
    }

    static func splitParams(_ body: String) -> (String, [String: String]) {
        let parts = body.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first else { return ("", [:]) }
        var params: [String: String] = [:]
        for part in parts.dropFirst() {
            guard let eq = part.firstIndex(of: "=") else { continue }
            params[String(part[..<eq])] = String(part[part.index(after: eq)...])
        }
        return (first, params)
    }
}
```

Catatan: `stripDashes` dan `splitParams` sengaja `static` bukan `private`, supaya bisa diuji langsung. Ini yang membuat parser punya test nyata, bukan test lewat jalan pintas.

Test (jalan di Linux):

```swift
@Test func parsesTopLevelTitleWithParams() {
    let items = XbarParser.parse("14:22 | color=#fff\n---\nRefresh | href=xbar://refresh", namespace: "clock")
    #expect(items.count == 1)
    #expect(items[0].title == "14:22")
    #expect(items[0].parameters["color"] == "#fff")
}

@Test func countsSubmenuDepth() {
    let (d0, _) = XbarParser.stripDashes("Item")
    let (d1, _) = XbarParser.stripDashes("-- Child")
    #expect(d0 == 0)
    #expect(d1 == 1)
}

@Test func splitsParamsWithoutDroppingTitle() {
    let (title, params) = XbarParser.splitParams("CPU 12% | font=Menlo size=12")
    #expect(title == "CPU 12%")
    #expect(params["font"] == "Menlo")
    #expect(params["size"] == "12")
}
```

---

## 4. Notch, angka pastinya

`Sources/EaveCore/Geometry/NotchGeometry.swift`:

```swift
import CoreGraphics

public enum NotchGeometry {
    /// Gap yang ditinggalkan macOS di kiri dan kanan notch.
    public static let gap: CGFloat = 24

    /// Lebar notch dari dua area di kiri dan kanannya. `+4` karena kedua
    /// area itu tidak menyentuh tepi notch.
    public static func width(
        screenWidth: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGFloat {
        max(0, screenWidth - auxLeftWidth - auxRightWidth + 4)
    }

    /// Tinggi notch: pakai safe area, fallback ke tinggi menu bar bertakik.
    public static func height(safeAreaTop: CGFloat, isNotched: Bool) -> CGFloat {
        safeAreaTop > 0 ? safeAreaTop : (isNotched ? 37 : 24)
    }
}
```

Panel (`EaveKit/Notch/NotchPanel.swift`) memakai konfigurasi ini:

```swift
let panel = NSPanel(
    contentRect: notchFrame,
    styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.isMovable = false
panel.hidesOnDeactivate = false
```

Dan subclass yang menolak jadi key window:

```swift
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

Alasan `canBecomeKey = false`: notch menutupi sebagian menu bar. Kalau panel bisa jadi key, klik di situ bisa memakan klik menu bar atau memunculkan app ke depan tanpa alasan. Deteksi klik pakai monitor global, bukan `mouseDown` di window.

---

## 5. Touch Bar, satu panggilan

`EaveKit/TouchBar/TouchBarPresenter.swift`:

```swift
import AppKit

@MainActor
public final class TouchBarPresenter: NSObject, NSTouchBarDelegate {
    private let trayIdentifier = NSTouchBarItem.Identifier("app.eave.tray")

    public func present(_ bar: NSTouchBar) {
        NSTouchBar.presentSystemModalTouchBar(bar, systemTrayItemIdentifier: trayIdentifier)
    }

    public func dismiss() {
        NSTouchBar.dismissSystemModalTouchBar(currentTouchBar)
    }
}
```

Aturan yang diambil dari MTMR (`AppSettings.blacklistedAppIds` + observer `didActivateApplicationNotification`): kalau app di depan ada di blacklist, lepas takeover. Default blacklist: Xcode, Photoshop, Final Cut, Logic. Alasan: app itu punya Touch Bar sendiri yang lebih berguna.

Deteksi perangkat, bukan versi OS:

```swift
extension NSTouchBar {
    static var isHardwarePresent: Bool {
        // Ada MacBook Pro 13" yang tidak punya Touch Bar, jadi cek
        // keberadaan device, bukan model atau versi OS.
        !NSTouchBar.isSupportedByCurrentSystem() == false
            && NSClassFromString("DFRFoundation") != nil
    }
}
```

Catatan: implementasi `isHardwarePresent` di atas belum final, dan tidak bisa diuji tanpa perangkat. Ini item terbuka, bukan hal yang sudah selesai.

---

## 6. Urutan kerja

Tiap task punya siklus test sendiri dan berakhir di kondisi bisa dijalankan.

### Task 1 — Skeleton yang jalan
- [ ] `git init`, `Package.swift` di atas, `swift test` hijau dengan satu test kosong
- [ ] Xcode project: app target `Eave`, `LSUIElement = YES`, deployment target macOS 14
- [ ] `NSStatusItem` dengan ikon placeholder, dropdown berisi satu item "Quit"
- [ ] **Verifikasi:** app muncul di menu bar, Quit menutup app

### Task 2 — Model
- [ ] `ScriptItem`, `ScriptAction`, `RefreshInterval`, `Section`, `Profile`
- [ ] `RefreshInterval` parse dari nama file: `foo.5s.sh`, `bar.2m.sh`, `baz.1h.sh`, `qux.1d.sh`. Tujuan akhir yang benar-benar dapat dipakai, bukan sekadar latihan.
- [ ] **Verifikasi:** 4 test di `EaveCoreTests`

### Task 3 — ScriptRunner
- [ ] `Process` dengan `executableURL`, argumen, environment minimal (PATH, HOME)
- [ ] Timeout default 5s, `terminate()` lalu `kill(SIGKILL)` setelah 1s
- [ ] Cap output 1MB, sisanya dibuang dengan penanda
- [ ] **Verifikasi:** script `sleep 10` timeout; script `cat /dev/urandom` tidak menghabiskan memori

### Task 4 — Parser
- [ ] `XbarParser` + `JSONOutputParser`
- [ ] **Verifikasi:** 6 test parser, termasuk input rusak (baris kosong, `---` ganda, param tanpa `=`)

### Task 5 — MenuBarRenderer
- [ ] Satu `ScriptItem` top-level = satu `NSStatusItem`
- [ ] Dropdown dari `children`
- [ ] **Verifikasi:** 3 plugin contoh jalan: jam, cpu (`top -l 1`), git branch

### Task 6 — Separator basic mode
- [ ] `SeparatorWidth` + `SeparatorEngine`
- [ ] Reveal saat hover/klik/scroll, rehide bertimer
- [ ] **Verifikasi:** 3 test murni + uji manual: sembunyikan, klik area kosong, ikon muncul

### Task 7 — Spacer + profile
- [ ] Spacer item, clamp `8...300`, simpan per profile
- [ ] **Verifikasi:** restart app, spacer dan lebarnya kembali

### Task 8 — Settings shell
- [ ] 5 tab: General, Hide, Scripts, Notch, Touch Bar
- [ ] Tab Touch Bar disembunyikan kalau `isHardwarePresent == false`
- [ ] **Verifikasi:** di Mac tanpa notch dan tanpa Touch Bar, 3 tab tampil, tidak ada yang crash

### Task 9 — Notch panel
- [ ] `NotchGeometry` + test murni
- [ ] `NotchPanel` dengan konfigurasi di §4
- [ ] Klik notch → open, klik luar → close, lewat `NSEvent.addGlobalMonitorForEvents`
- [ ] **Verifikasi:** di Mac ber-notch, panel muncul persis di bawah notch, tidak menelan klik menu bar

### Task 10 — Notch tray
- [ ] `NotchTrayModel`: item yang tidak muat masuk tray
- [ ] **Verifikasi:** layar 14" dengan 20 item, tray berisi kelebihannya

### Task 11 — Item mover (full mode)
- [ ] `WindowList` + `ItemMover`
- [ ] Fallback mouseUp ke posisi asal
- [ ] **Verifikasi:** pindahkan item dari visible ke hidden, restart, posisi bertahan

### Task 12 — Touch Bar
- [ ] `TouchBarPresenter`, item factory, blacklist
- [ ] **Verifikasi:** di MacBook Pro 13", takeover jalan; buka Xcode, takeover lepas

### Task 13 — Rilis
- [ ] Ikon final dari plan 02
- [ ] Onboarding 3 layar
- [ ] Sparkle, notarization, DMG, cask

---

## 7. Test strategi, dan batasnya

**Sudah diverifikasi jalan di mesin ini:** `swift test` hijau, 35 test, 0.57 detik.

| Lapisan | Bisa diuji di Linux | Butuh macOS | Status |
|---------|--------------------|-------------|--------|
| `SeparatorWidth` | ya | — | 4 test hijau |
| `NotchGeometry` | ya | — | 6 test hijau |
| `RefreshInterval` | ya | — | 7 test hijau |
| `XbarParser` | ya | — | 11 test hijau |
| `ScriptRunner` | ya | — | 7 test hijau, termasuk timeout dan output 1MB |
| `EaveKit` yang menyentuh AppKit | tidak | ya | belum ada |
| `ItemMover`, `SeparatorEngine`, `NotchPanel` | tidak | ya, dan idealnya Mac asli bukan VM | belum ada |
| Touch Bar | tidak | ya, dan hanya di perangkat ber-Touch Bar | belum ada |

**Temuan dari menulis `ScriptRunner`, dan ini bukan hal sepele:**

Menangkap stdout lewat `Pipe` **menggantung** kalau script memanggil proses lain. Anak adalah shell, dan `sleep`/`curl` di dalamnya adalah cucu yang ikut memegang ujung tulis pipe. Membunuh shell dengan SIGKILL tidak menyentuh cucu, jadi pipe tidak pernah EOF, dan pembaca pipe menunggu sampai cucu selesai sendiri. Terukur: 10 detik untuk script `sleep 10` dengan timeout 0.5 detik.

Dua hal yang memperbaiki, keduanya harus ada:

1. **Output ke file sementara, bukan pipe.** File tidak punya masalah EOF. Batas ukuran ditegakkan saat membaca, bukan saat menulis.
2. **Sinyal ke process group (`kill(-pid, SIGTERM)`), bukan ke anak saja.** Ini yang benar-benar membunuh cucu.

Yang **tidak boleh** dilakukan: menulis test yang selalu lolos. Kalau sebuah perilaku hanya bisa dilihat mata, tulis langkah manual di plan, jangan pura-pura jadi test.

CI: `swift test` untuk `EaveCore` di Linux (cepat, gratis), `xcodebuild test` untuk `EaveKit` di macOS runner (lambat, bayar). Pisahkan dua job supaya umpan balik cepat untuk bagian yang paling sering berubah.

---

## 8. Checklist keputusan

- [ ] Nama final (plan 02)
- [ ] App Store atau direct saja. Kalau App Store: hapus `SeparatorEngine`? Tidak, itu legal. Yang harus hilang: private CGS space, AX automation. Itu memotong Fase D dan F.
- [ ] Sparkle atau update sendiri. Sparkle lebih murah.
- [ ] Deployment target macOS 14 atau 26. macOS 14 memperbesar pasar tapi harus menghindari API 15+, termasuk sebagian yang dipakai notch.
- [ ] Bahasa UI: Inggris saja, atau Inggris + Indonesia.

---

## 9. Yang tidak dikerjakan di v1

- Profil otomatis per app
- Marketplace plugin
- Sinkronisasi antar Mac
- Now playing di notch (boring.notch pakai `MusicManager` 25.9KB, kita cukup `MPNowPlayingInfoCenter` di v2)
- Search ikon menu bar (butuh Screen Recording, taruh v2)
- Trigger bersyarat (baterai, wifi, fokus). Thaw punya 20+ jenis, kita mulai dengan nol.

---

## 10. Build dan test dari mesin Linux ini (xtool)

**Status: belum dicoba. Ini catatan pendahuluan, bukan hal yang sudah jalan.**

[xtool](https://github.com/xtool-org/xtool) (13.2k bintang, MIT, terakhir push hari ini) bikin `swift build` untuk iOS **tanpa Mac dan tanpa Xcode**, langsung dari Linux. Kuncinya `Darwin Swift SDK` yang diunduh dari Xcode resmi, lalu `swift build --swift-sdk`. (`Sources/XToolSupport/SDKCommand.swift`)

**Untuk project ini, relevansinya terbatas tapi nyata:**

Yang berguna:
- CI: `swift test` untuk `EaveCore` di Linux runner, gratis, tanpa macOS runner berbayar. Ini sesuatu yang bisa diuji di mesin ini.
- `xtool new` + `xtool dev` kalau nanti muncul companion iOS (mis. remote untuk menu bar). Di plan v1: tidak ada iOS app, jadi ini tidak dipakai.

Yang tidak dipakai:
- Signing, App Store Connect API (`XKit`), instalasi ke iPhone. Semua itu bisnis iOS, bukan bisnis menu bar.

**Coba di mesin ini dengan urutan:**

1. Unduh `swift-sdk` via `xtool sdk install` (butuh Xcode 26 .xip, ±1GB).
2. `swift build --swift-sdk arm64-apple-ios` di `Sources/EaveKit` yang belum ada. Kalau ini jalan, compiles check bisa di CI, test masih butuh macOS.
3. Kalau gagal compile (AppKit API), tulis `#if os(macOS)` guard di satu tempat.

Diskusi panjang di [forums.swift.org](https://forums.swift.org/t/xtool-cross-platform-xcode-replacement-build-ios-apps-on-linux-and-more/79803) untuk internals. Baca kalau stuck.
