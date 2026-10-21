# 02 — Icons and visual system

**Status:** draft for review
**Problem:** a menu bar utility lives or dies by its icon. There is exactly
one icon, 22 pt, and it has to say "this is a tool for your menu bar" in one
glance.

---

## 1. Name first, because the icon follows the name

Four requirements for the name:
1. Pronounceable by Indonesians and foreigners.
2. Not colliding with Bartender, Ice, Thaw, Hidden Bar, Dozer, Pock, MTMR.
3. Not another menu bar metaphor already taken (ice, bar, hidden).
4. One word, easy to turn into a domain.

Candidates, with reasoning:

| Name | Meaning | Why | Risk |
|------|---------|-----|------|
| **Eave** | the edge of a roof that hangs over | shelters without covering — precisely what a menu bar manager does | uncommon, easy to spell |
| **Sill** | window ledge | a place to put things | already `Saffsanity/sill` |
| **Nook** | hidden corner | fits "hidden section" | widely used elsewhere |
| **Pelmet** | curtain rail above a window | covers the top area | already `ismatBabirli/pelmet` |
| **Cornice** | upper molding | architectural, strong | hard to pronounce |
| **Eaves** | plural of eave | — | Eave is cleaner |

**Recommendation: Eave.** One word, 4 letters, unused in this category, and
the meaning is exact: something hanging at the top that shelters. Other
documents use Eave as the codename; if the final name changes, change it in
one constant `Constants.displayName`.

---

## 2. What the icon must say at 22×22 pt

Three things, only three:
1. It's about the **menu bar**.
2. It **hides / arranges**, it doesn't add.
3. It has **character**, not generator output.

Not allowed: letters, five-color gradients, plain SF Symbols pasted in,
shapes indistinguishable from other apps in this category.

---

## 3. Visual direction

Not "cute icon", not "corporate icon". Direction: **an architectural
silhouette that slightly overhangs**, one color, with one negative-space cut
that acts as the mark.

Three concepts, ready to sketch:

### Concept A — Overhang
A pitched roof shape hanging past its wall. A horizontal negative cut below
the overhang = menu bar icons hidden underneath.

```
   ╱▔▔▔▔▔▔▔╲
  ╱         ╲___
  ▔▔▔▔▔▔▔▔▔▔│   │
            │   │
```

Strength: reads as "shelters above" immediately. Works as a template image
(black + transparency).

### Concept B — Slat
Three horizontal lines of unequal length, the middle one shortest, like
molding that's been shoved aside. The short line = the hidden item.

```
▔▔▔▔▔▔▔▔▔▔▔▔
   ▔▔▔▔▔▔
▔▔▔▔▔▔▔▔▔▔▔▔
```

Strength: most legible at 16 pt. Easiest to animate for loading states.

### Concept C — Notch
An upside-down U covering the top-center, with thin wings left and right.

```
▔▔▔╮      ╭▔▔▔
   │      │
```

Strength: reads as "notch", our main differentiator.
Risk: locks the product to one of four features.

**Recommendation: A for the app icon, B for the status item icon.**

Reasoning: the app icon (Dock, Finder, DMG) needs a shape with mass, and A
has it. The status item must read at 18 pt monochrome, and B survives that
best. Two icons, one family.

---

## 4. Status item icon: technical rules

- **Template image.** `isTemplate = true`. macOS colors it, so it's correct in
  light, dark, and tinted menu bars automatically.
- **Size:** 18×18 pt at 1x, ship 18, 36, 54.
- **Stroke:** consistent 1.5 pt. Not 1 pt (disappears when the bar expands),
  not 2 pt (reads heavy when the bar is thin).
- **Padding:** 2 pt on each side, effective content 14×14.
- **No color.** The only color in the status item comes from state, not the
  shape itself.

**States** (all derived from shape B, only the number of lines changes):

| State | Look |
|-------|------|
| Idle | 3 full lines |
| Section hidden active | middle line dashed (dots) |
| Script item error | middle line replaced by a small dot at the right |
| Notch tray open | middle line thickens 0.5 pt |
| Basic mode (no AX) | outer lines thin 1 pt |

Never animate in the status item. A moving menu bar icon is noise.

---

## 5. App icon

- **Shape:** concept A, inside a 1024×1024 rounded square, corner radius
  following macOS 26 (superellipse, ~22.37%).
- **Color:** one dark base, one accent. Not a five-stop gradient.
  - Base: `#141A1F` (near-black, slightly blue)
  - Accent: `#E8B84B` (dark gold, not bright yellow)
  - Alternative accent: `#5FB3A1` (muted teal), if we want calmer
- **Why not white:** menu bar utility icons are all bright. Dark stands out in
  the Dock.
- **One detail:** the negative cut below the overhang gets the base color, so
  it reads as a hole, not a line.

**Never:** drop shadows, reflections, metallic gradients, 3D icons, small text
underneath.

---

## 6. Per-tool icons in Settings

Settings tabs need small icons. Do not use raw SF Symbols (every macOS app
does that, none have a face).

Four custom icons at 20×20, one stroke family at 1.5 pt, monochrome:

| Tool | Shape |
|------|-------|
| Hide | two short lines on top, one long line below |
| Script | a `>` chevron with a line under it (a prompt without a box) |
| Notch | upside-down U with a dot in the middle |
| Touch Bar | one long horizontal line with three dots above |

All four drawn on the same 20 pt grid, 1.5 pt stroke, 0.5 pt corners (neither
razor-sharp nor fully round). This is what makes four icons read as one set.

---

## 7. Work checklist

### Name
- [ ] Final decision among top three (Eave / Cornice / Nook)
- [ ] Check domain, GitHub org, Homebrew cask name
- [ ] Check trademark collisions in the App Store
- [ ] Write one-line tagline: "___ hides what you don't need and keeps
      everything one click away."

### Status item icon
- [ ] Concept B drawn on an 18 pt grid, 1.5 pt stroke
- [ ] Export 18/36/54 as template images (PNG + vector PDF)
- [ ] Five states drawn, not one
- [ ] Test in light, dark, and wallpaper-tinted menu bars
- [ ] Test at spacing 0 and spacing 16

### App icon
- [ ] Concept A drawn at 1024×1024
- [ ] Full export set: 16, 32, 128, 256, 512 (1x and 2x)
- [ ] Test in Dock light and dark
- [ ] Test in Finder list view at 16 pt (still legible?)
- [ ] Monochrome version for notifications and menus

### Tool icons
- [ ] Four 20×20 icons drawn on the same grid
- [ ] Export as vector PDF
- [ ] Test in Settings tab bar

### Release assets
- [ ] DMG background (660×420, same base color as the icon)
- [ ] README header (1200×300, light and dark)
- [ ] 800×500 demo GIF: hide an item → script item updates → notch tray opens

---

## 8. Hard rules

1. **No SF Symbols in the main icons.** Fine inside Settings for generic
   things (chevron, gear), never for the four tool icons.
2. **No gradient with more than two colors.**
3. **No text in icons.**
4. **One stroke family.** 1.5 pt everywhere. One icon at 1.4 pt makes the
   whole set look broken.
5. **Status item icon is always a template.** Color in the status item is
   forbidden, except one red dot for an unforgivable error state.

---

## 9. Deliverables

Three files under `/root/designs/eave/`:
- `status-icon.pdf` — 5 states, vector
- `app-icon-1024.png` — plus the full export set
- `tool-icons.pdf` — 4 icons, same grid

PNG previews for review in chat before anything lands in the repo.
