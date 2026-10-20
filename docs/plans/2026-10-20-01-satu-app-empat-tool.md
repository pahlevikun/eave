# 01 — Satu app, empat tool

**Status:** draft untuk ditinjau
**Codename:** Eave (nama final = keputusan terbuka, lihat plan 02)
**Basis:** riset repo di `/root/.hermes/cache/scratch/menubar-research/` (Ice, Thaw, hidden, boring.notch, MTMR, xbar, Pock)

---

## 1. Tesis

Empat tool, satu mesin.

```
                    ┌──────────────────────────┐
                    │      Script Engine       │
                    │  jalankan · parse · cache │
                    └────────────┬─────────────┘
                                 │  ScriptItem
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐      ┌─────────▼────────┐     ┌─────────▼─────────┐
│ Menu bar      │      │ Notch panel      │     │ Touch Bar         │
│ NSStatusItem  │      │ NSPanel          │     │ NSTouchBar modal  │
└───────────────┘      └──────────────────┘     └───────────────────┘
        ▲
        │  dipakai juga oleh
┌───────┴────────┐
│ Hide engine    │  basic (separator) · full (CGEvent)
└────────────────┘
```

Satu plugin ditulis sekali. Muncul di menu bar, di notch tray, dan di Touch Bar. Itu alasan keempatnya satu app. Kalau dipisah empat app, mesin script harus ditulis empat kali dan plugin harus dipasang empat kali.

---

## 2. Empat tool, satu app

| # | Tool | Permukaan utama | Permission |
|---|------|-----------------|------------|
| 1 | Hide menu bar | ikon di menu bar + dropdown | Basic: nol. Full: Accessibility |
| 2 | Custom script | item di menu bar + dropdown | nol |
| 3 | Notch | panel bawah notch | nol (Screen Recording opsional untuk preview) |
| 4 | Touch Bar | Touch Bar modal sistem | Accessibility (untuk takeover per-app) |

Semua berbagi:
- satu `ScriptEngine`
- satu `PermissionStore`
- satu window Settings dengan 4 pane
- satu ikon status item

---

## 3. Peta modul

Semua di dalam satu SPM library `EaveCore`, plus satu app target tipis.

```
EaveCore/
  Model/
    ScriptItem.swift        // id, title, icon, color, submenu, actions
    ScriptAction.swift      // .shell(path,args) .appleScript(src) .openURL(url)
    Section.swift           // visible / hidden / alwaysHidden
    Profile.swift           // nama, display, daftar item, spacing
    RefreshInterval.swift   // n/detik..jam, parse dari nama file
  Script/
    ScriptRunner.swift      // Process + timeout + output cap
    XbarParser.swift        // stdout → [ScriptItem]
    JSONParser.swift        // {"title","image"} → ScriptItem
    AnsiColor.swift         // ANSI escape → attributed string
    Scheduler.swift         // timer per item, coalesce
  MenuBar/
    SeparatorEngine.swift   // basic: NSStatusItem.length = 10_000
    WindowList.swift        // CGWindowListCopyWindowInfo, layer 25
    ItemMover.swift         // CGEvent cmd-drag + windowID field
    SectionController.swift // 3 section, rehide timer
    SpacerController.swift  // spacer item, clamp 8...300
  Notch/
    NotchGeometry.swift     // auxiliaryTop* → CGRect
    NotchPanel.swift        // NSPanel .mainMenu+3, canBecomeKey=false
    NotchTrayModel.swift    // item mana masuk tray
  TouchBar/
    TouchBarPresenter.swift // presentSystemModalTouchBar
    TouchBarItemFactory.swift
    AppBlacklist.swift
  Render/
    MenuBarRenderer.swift
    NotchRenderer.swift
    TouchBarRenderer.swift
  Permissions/
    Permission.swift
    PermissionStore.swift
Eave/                       // app target, tipis
  EaveApp.swift
  StatusItemController.swift
  SettingsWindow.swift
  SettingsPanes/  (4 pane)
```

Aturan: `Model` tidak boleh import AppKit. `Script` tidak boleh import AppKit. Semua yang menyentuh UI ada di `Render`, `MenuBar`, `Notch`, `TouchBar`. Ini yang membuat model dan parser bisa diuji dengan `swift test` di mesin tanpa GUI.

---

## 4. Kapan tiap tool aktif

Ini yang menentukan apakah app terasa satu produk atau empat produk yang ditempel.

**Satu status item.** Ikon Eave. Klik = dropdown. Bukan empat ikon terpisah; user yang punya 20 ikon menu bar tidak butuh tiga tambahan.

**Dropdown = tool switcher + isi.**

```
┌──────────────────────────────────┐
│ Hide        ▸ Hidden (7)         │
│             ▸ Always hidden (3)  │
├──────────────────────────────────┤
│ Scripts     ▸ clock  14:22       │
│             ▸ cpu    12%         │
│             ▸ git    main*       │
├──────────────────────────────────┤
│ Notch       ▸ Show tray          │
│             ▸ 4 item overflow    │
├──────────────────────────────────┤
│ Touch Bar   ▸ Take over          │
├──────────────────────────────────┤
│ Settings…                    ⌘,  │
│ Quit                         ⌘Q  │
└──────────────────────────────────┘
```

Cuma section yang aktif yang tampil. Kalau user tidak punya MacBook ber-Touch Bar, baris Touch Bar tidak muncul sama sekali. Deteksi: `NSTouchBar.isSupported` / cek perangkat, bukan cek OS.

**Settings = 4 tab, bukan 1 tab panjang.**

```
[ General ] [ Hide ] [ Scripts ] [ Notch ] [ Touch Bar ] [ About ]
```

Tab yang perangkatnya tidak ada disembunyikan. Touch Bar tab hilang di Mac tanpa Touch Bar. Notch tab tetap ada tapi menampilkan "Layar ini tidak punya notch" dan pindah ke mode pratinjau.

---

## 5. Model izin (penting untuk App Store dan untuk user yang menolak TCC)

Tiga tingkat, dipilih user sekali, bukan dipaksa.

| Mode | Butuh | Dapat | Tidak dapat |
|------|-------|-------|-------------|
| Basic | nol | sembunyikan semua ikon di kiri separator, spacer, script, notch tray | pindah item individual, klik item tersembunyi |
| Standard | Accessibility | + pindah item, klik item tersembunyi, notch tray penuh | preview ikon (butuh Screen Recording) |
| Full | + Screen Recording | + thumbnail ikon asli di tray dan search | — |

Semua fitur harus punya jawaban di Basic, minimal versi terbatas. Ini yang membuat app tetap berguna saat user menolak dialog TCC, dan ini yang membuat app bisa didistribusikan lebih luas.

Status izin dicek tiap 1 detik saat app aktif, pola dari Ice (`Permission.swift:63` `Timer.publish(every: 1)`), bukan hanya saat launch. User sering memberi izin setelah app jalan.

---

## 6. Distribusi

Dua build dari satu kode:

- **Direct** — Developer ID, notarized, Sparkle. Full mode.
- **App Store** — App Sandbox, tanpa private CGS API, tanpa Accessibility automation. Basic + script + notch (notch pakai AX publik). Store build memakai flag kompilasi `EAVE_APPSTORE` untuk mematikan jalur yang tidak diizinkan.

Kalau App Store terlalu mahal untuk dirawat, drop. Tapi arsitekturnya harus disiapkan sejak awal supaya keputusan itu bisa diambil nanti tanpa refactor.

---

## 7. Checklist kerja

### Fase A — fondasi (1 app kosong yang jalan)
- [ ] Repo dibuat, `Package.swift` dengan target `EaveCore` + test target
- [ ] `ScriptItem`, `ScriptAction`, `RefreshInterval` + test round-trip
- [ ] App target: `LSUIElement = true`, satu `NSStatusItem`, dropdown kosong
- [ ] Settings window kosong dengan 6 tab, tab Touch Bar auto-hide
- [ ] CI: `swift test` jalan tanpa perlu GUI

### Fase B — Tool 2, script engine
- [ ] `ScriptRunner`: Process, timeout 5s default, output cap 1MB
- [ ] `XbarParser`: baris pertama judul, `---` pemisah, `--` submenu, `key=value` param
- [ ] `JSONParser`: `{"title","image"}` sebagai alternatif
- [ ] `Scheduler`: interval per item, coalesce, tidak pernah dua proses bareng untuk item yang sama
- [ ] `MenuBarRenderer`: satu item script = satu `NSStatusItem`
- [ ] 3 plugin contoh: jam, cpu, git status

### Fase C — Tool 1, hide basic
- [ ] `SeparatorEngine`: length clamp `max(500, min(widest * 2, 10_000))`
- [ ] Hitung dari `NSScreen.screens.map(\.frame.width).max()`, bukan `NSScreen.main`
- [ ] Re-apply saat `didChangeScreenParametersNotification`
- [ ] Klik/hover/scroll reveal + auto-rehide bertimer
- [ ] Spacer manual, clamp `8...300`, disimpan per profile

### Fase D — Tool 3, notch
- [ ] `NotchGeometry`: lebar `frame.width - auxiliaryTopLeft.width - auxiliaryTopRight.width + 4`, tinggi `safeAreaInsets.top`, fallback 37pt
- [ ] `NotchPanel`: `.mainMenu + 3`, `canBecomeKey = false`, `.fullScreenAuxiliary + .stationary + .canJoinAllSpaces + .ignoresCycle`
- [ ] State `closed` / `open` saja
- [ ] Klik notch → open, klik luar → close (global monitor, bukan window click)
- [ ] `NotchTrayModel`: item yang tidak muat di kanan notch masuk tray, bukan hilang
- [ ] Tab Notch: pilih posisi panel, tinggi, apakah tray ikut Touch Bar

### Fase E — Tool 1, hide full
- [ ] `WindowList`: `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)`, filter `kCGWindowLayer == 25`
- [ ] `ItemMover`: CGEvent cmd-drag, `windowID` field `0x33`, kursor netral `(20_000, 20_000)`
- [ ] Verifikasi: tunggu frame berubah, timeout 50ms
- [ ] Fallback mouseUp ke posisi asal kalau drag gagal
- [ ] Tiga section + always-hidden

### Fase F — Tool 4, Touch Bar
- [ ] `TouchBarPresenter`: `NSTouchBar.presentSystemModalTouchBar`
- [ ] `TouchBarItemFactory`: staticButton, shellScript, appleScript, group
- [ ] `AppBlacklist`: observer `didActivateApplicationNotification`, lepas takeover saat app di blacklist
- [ ] Swipe 1-3 jari antar halaman
- [ ] Tab Touch Bar hilang kalau perangkat tidak ada

### Fase G — rilis
- [ ] Ikon final (plan 02)
- [ ] Onboarding 3 layar: mode izin, pilih plugin, pilih notch
- [ ] Sparkle appcast
- [ ] Notarize + DMG
- [ ] Homebrew cask

---

## 8. Batas yang disadari

- **Touch Bar mati.** Hanya MacBook Pro 13". Yang masih dapat macOS 26: 13" M1 2020, 13" M2 2022, 13" 2020 four-port, 16" 2019. Setelah itu tidak ada model baru. Fitur ini punya umur. Bangun sebagai modul yang bisa dilepas (Fase F bisa dibatalkan tanpa menyentuh fase lain).
- **Notch hanya main display** kalau memakai budget overflow ala Thaw. Untuk versi pertama, batasi ke main display. Ekspansi nanti.
- **Basic mode tidak bisa mengklik item tersembunyi.** Itu batas fisik trik separator. Jangan janjikan di UI.

---

## 9. Keputusan yang masih terbuka

1. Nama produk (plan 02 §1)
2. Fork Thaw vs tulis dari nol → plan 03 memilih **tulis dari nol**, dengan alasan.
3. App Store atau direct saja → pengaruh ke Fase E (private API) dan Fase F (AX automation).
