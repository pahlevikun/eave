# Eave

Menu bar utility untuk macOS. Empat tool, satu mesin.

- **Hide** — sembunyikan ikon menu bar, dua tingkat izin
- **Script** — plugin xbar/MTMR jalan di menu bar
- **Notch** — notch sebagai permukaan, bukan cuma lubang
- **Touch Bar** — seluruh bar diambil alih

Status: fondasi. `EaveCore` sudah ada dan teruji. `EaveKit` dan app target
belum.

## Bangun

```sh
swift test        # 35 test, jalan di macOS dan Linux
```

App target butuh Xcode 26 dan macOS 14+. Library-nya tidak.

## Bentuk

```
Sources/EaveCore/       model, parser, runner, geometri — tanpa AppKit
Tests/EaveCoreTests/    35 test
docs/plans/             rencana: app, ikon, dari nol
```

Aturan: `EaveCore` tidak boleh `import AppKit`. Semua yang menyentuh UI hidup
di `EaveKit`. Alasannya bukan kerapian, tapi supaya bagian yang paling sering
berubah bisa diuji dalam 0.5 detik tanpa Xcode.

## Lisensi

Belum ditetapkan. Kalau App Store masuk rencana, GPL menutup pintu itu.
