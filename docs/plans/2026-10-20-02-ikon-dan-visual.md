# 02 — Ikon dan sistem visual

**Status:** draft untuk ditinjau
**Masalah:** app utility menu bar hidup atau mati oleh ikonnya. Ikonnya satu, 22pt, dan harus bilang "ini alat untuk menu bar" dalam sekejap.

---

## 1. Nama dulu, karena ikon mengikuti nama

Nama harus memenuhi empat syarat:
1. Bisa diucapkan orang Indonesia dan orang luar.
2. Tidak tabrakan dengan Bartender, Ice, Thaw, Hidden Bar, Dozer, Pock, MTMR.
3. Bukan metafora menu bar yang sudah dipakai (ice, bar, hidden).
4. Satu kata, mudah jadi domain.

Kandidat, dengan alasan:

| Nama | Arti | Kenapa | Risiko |
|------|------|--------|--------|
| **Eave** | tepi atap yang menggantung | menaungi tanpa menutupi, persis fungsi menu bar manager | jarang dipakai, ejaan mudah |
| **Sill** | ambang jendela | tempat barang ditaruh | sudah ada `Saffsanity/sill` |
| **Nook** | sudut tersembunyi | cocok untuk hidden section | banyak dipakai produk lain |
| **Pelmet** | tirai tepi atas jendela | menutupi bagian atas | sudah ada `ismatBabirli/pelmet` |
| **Cornice** | lisplang atas | arsitektural, kuat | susah diucapkan |
| **Eaves** | jamak dari eave | — | Eave lebih bersih |

**Rekomendasi: Eave.** Satu kata, 4 huruf, tidak dipakai di kategori ini, artinya tepat: sesuatu yang menggantung di atas dan menaungi. Codename di dokumen lain memakai Eave; kalau nama final berubah, ganti di satu konstanta `Constants.displayName`.

---

## 2. Apa yang harus disampaikan ikon di 22×22pt

Tiga hal, hanya tiga:
1. Ini soal **menu bar**.
2. Ini **menyembunyikan / menata**, bukan menambah.
3. Ini **punya karakter**, bukan hasil generator.

Yang tidak boleh: huruf, gradien lima warna, glyph dari SF Symbols apa adanya, bentuk yang sama dengan app lain di kategori ini.

---

## 3. Arah visual

Bukan "ikon lucu", bukan "ikon korporat". Arah yang dipilih: **silhouette arsitektural yang sedikit melengkung**, satu warna, dengan satu potongan negatif yang jadi tanda.

Tiga konsep, siap digambar:

### Konsep A — Overhang
Bentuk atap miring yang menggantung melewati dinding. Potongan negatif horizontal di bawah overhang = ikon menu bar yang tersembunyi di bawahnya.

```
   ╱▔▔▔▔▔▔▔╲
  ╱         ╲___
  ▔▔▔▔▔▔▔▔▔▔│   │
            │   │
```

Kekuatan: langsung terbaca "menaungi". Cocok untuk template image (hitam transparan).

### Konsep B — Slat
Tiga garis horizontal tidak sama panjang, yang tengah paling pendek, seperti lisplang yang digeser. Yang pendek itu item yang disembunyikan.

```
▔▔▔▔▔▔▔▔▔▔▔▔
   ▔▔▔▔▔▔
▔▔▔▔▔▔▔▔▔▔▔▔
```

Kekuatan: paling terbaca di 16pt. Paling mudah di-animate jadi state loading.

### Konsep C — Notch
Bentuk U terbalik yang menutupi bagian tengah atas, dengan dua sayap tipis di kiri dan kanan.

```
▔▔▔╮      ╭▔▔▔
   │      │
```

Kekuatan: langsung mengomunikasikan notch, yang jadi pembeda utama. Risiko: mengunci produk ke satu fitur, padahal ada empat.

**Rekomendasi: A sebagai ikon app, B sebagai ikon status item.**

Alasan: ikon app (Dock, Finder, DMG) butuh bentuk yang punya massa, dan A punya itu. Ikon status item harus terbaca di 18pt monokrom, dan B paling tahan di ukuran itu. Dua ikon, satu keluarga.

---

## 4. Ikon status item: aturan teknis

- **Template image.** `isTemplate = true`. macOS yang mewarnai, jadi otomatis benar di light/dark dan di menu bar bertint.
- **Ukuran:** 18×18pt di layar 1x, siapkan 18, 36, 54.
- **Goresan:** 1.5pt konsisten. Bukan 1pt (hilang saat menu bar digelembungkan), bukan 2pt (terlihat tebal saat bar tipis).
- **Padding:** 2pt di tiap sisi, jadi isi efektif 14×14.
- **Tanpa warna.** Satu-satunya warna di status item datang dari state, bukan dari ikon.

**State ikon** (semua dari bentuk B, hanya beda jumlah garis):

| State | Tampilan |
|-------|----------|
| Idle | 3 garis penuh |
| Section hidden aktif | garis tengah putus, jadi titik-titik |
| Script item error | garis tengah diganti titik kecil di kanan |
| Notch tray terbuka | garis tengah menebal 0.5pt |
| Mode basic (tanpa izin AX) | garis luar lebih tipis 1pt |

Jangan pakai animasi di status item. Ikon menu bar yang bergerak mengganggu.

---

## 5. Ikon app

- **Bentuk:** konsep A, dalam rounded square 1024×1024, sudut mengikuti macOS 26 (superellipse, radius ~22.37%).
- **Warna:** satu warna dasar gelap, satu aksen. Bukan gradien lima titik.
  - Dasar: `#141A1F` (hampir hitam, sedikit biru)
  - Aksen: `#E8B84B` (kuning tua, bukan kuning terang)
  - Alternatif aksen: `#5FB3A1` (teal redup), kalau mau terasa lebih tenang
- **Kenapa bukan putih:** ikon menu bar utility berwarna terang semua. Gelap menonjol di Dock.
- **Satu detail:** potongan negatif di bawah overhang diberi warna dasar yang sama dengan latar, jadi terbaca sebagai lubang, bukan garis.

**Yang tidak boleh ada:** bayangan drop, refleksi, gradien metalik, ikon 3D, huruf kecil di bawah.

---

## 6. Ikon per tool di Settings

Tab Settings butuh ikon kecil. Jangan pakai SF Symbols mentah (semua app macOS memakainya, hasilnya tanpa wajah).

Empat ikon kustom 20×20, satu keluarga goresan 1.5pt, monokrom:

| Tool | Bentuk |
|------|--------|
| Hide | dua garis pendek di atas, satu garis panjang di bawah |
| Script | chevron `>` dengan garis di bawahnya (prompt tanpa kotak) |
| Notch | U terbalik dengan satu titik di tengah |
| Touch Bar | garis horizontal panjang dengan tiga titik di atasnya |

Semua digambar di grid 20pt yang sama, goresan 1.5pt, sudut 0.5pt (tidak tajam sempurna, tidak bulat penuh). Ini yang membuat empat ikon terbaca sebagai satu set.

---

## 7. Checklist kerja

### Nama
- [ ] Putuskan nama final dari tiga kandidat teratas (Eave / Cornice / Nook)
- [ ] Cek domain, GitHub org, nama cask Homebrew
- [ ] Cek tabrakan merek di App Store
- [ ] Tulis satu baris tagline: "___ hides what you don't need and keeps everything one click away."

### Ikon status item
- [ ] Konsep B digambar di grid 18pt, goresan 1.5pt
- [ ] Ekspor 18/36/54 sebagai template image (PNG + PDF vektor)
- [ ] Lima state digambar, bukan satu
- [ ] Uji di menu bar light, dark, dan dengan tint wallpaper
- [ ] Uji di menu bar dengan spacing 0 dan spacing 16

### Ikon app
- [ ] Konsep A digambar 1024×1024
- [ ] Ekspor set lengkap: 16, 32, 128, 256, 512 (1x dan 2x)
- [ ] Uji di Dock light dan dark
- [ ] Uji di Finder list view 16pt (masih terbaca?)
- [ ] Buat versi monokrom untuk notifikasi dan menu

### Ikon tool
- [ ] Empat ikon 20×20 digambar di grid yang sama
- [ ] Ekspor PDF vektor
- [ ] Uji di tab bar Settings

### Aset rilis
- [ ] DMG background (ukuran 660×420, warna dasar yang sama dengan ikon)
- [ ] Header README (1200×300, versi light dan dark)
- [ ] GIF demo 800×500: hide item → script item update → notch tray buka

---

## 8. Aturan yang tidak boleh dilanggar

1. **Tanpa SF Symbols di ikon utama.** Boleh di dalam Settings untuk hal generik (chevron, gear), tidak boleh untuk empat ikon tool.
2. **Tanpa gradien lebih dari dua warna.**
3. **Tanpa teks di ikon.**
4. **Satu keluarga goresan.** 1.5pt di semua tempat. Kalau satu ikon 1.4pt, seluruh set terlihat berantakan.
5. **Ikon status item selalu template.** Warna di status item dilarang, kecuali satu titik merah untuk error yang tidak bisa diabaikan.

---

## 9. Deliverable

Tiga file di `/root/designs/eave/`:
- `status-icon.pdf` — 5 state, vektor
- `app-icon-1024.png` — plus set lengkap
- `tool-icons.pdf` — 4 ikon, grid sama

Preview PNG untuk ditinjau di chat sebelum masuk repo.
