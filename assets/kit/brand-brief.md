# Eave brand brief

Mode: one_shot. Tier: medium. Taste choices delegated by the user; no checkpoint required. Original geometry; no trademark paths reused. Banner column 3: product-card. No docs/images gallery requested. Mandatory iOS/Android/web and social exports included as identity handoff assets, not claims of supported product platforms.

Intent: Give Eave a quiet, legible identity for a small personal utility, with one clear metaphor, flat backgrounds, factual copy, and a brief draw/settle motion followed by a reading hold. The 904×256 banner has separate mark, copy, and illustrative product-card columns. The product illustration is not a runtime screenshot or acceptance proof.

## Evidence

- README.md: display name and product area; stale Eave claims are superseded by source and audit evidence.
- Eave/EaveApp.swift, Eave/AppDelegate.swift, Eave/Settings/ScriptsPane.swift: accessory app, menu bar, scripts and semantic AppKit colors.
- docs/audit-baseline.md: supported scope and limits. No full xbar compatibility or whole-notch-control claim.
- assets/brand-tokens.json: all brand roles and explicit provenance. Eave has no fixed native hex theme: this file defines the new brand palette under the user’s design grant, never an extracted native palette.

## Research

Local library searches: search_library.py --category oss_repo_mark --summary (20 matches); search_examples.py --has-animation true --summary (2 matches). Read library/stats.json (1,636 study marks). Studied opencollective for robust negative space, go for compact horizontal weight, gitlab for a bold silhouette. Read the actual library SVGs. These are composition references only; no geometry copied. Canonical animated examples inform pacing only.

Clichés avoided: terminal prompt as a universal devtools logo; generic orbit/rings; sparkle/AI flourish; letter inside a default squircle; decorative gradient. No fake diff or terminal story.

## Ten ideas before drawing

1. Roofline as an open E.
2. A signal suspended from a lintel.
3. An open menu bracket.
4. Two interleaved rafters.
5. A hanging tab under an overhang.
6. A quiet status dot under a beam.
7. An E carved from a folding plane.
8. A script notch in a roof beam.
9. Three window ticks under a canopy.
10. A corner folded into a lowercase e.

## Three black-first directions

1. Eave cut — selected: architectural overhang opens into an E, connecting the name to a place for useful status.
2. Signal lintel — a suspended status dot, but the generic signal reads less like the name.
3. Open bracket — a clean E/bracket, but less distinctive than the overhang.

## Copy and layout

Wordmark: Eave. Tagline: “Scripts in your menu bar.” (25 characters). Motto: “Small scripts. A useful menu bar.”. Cursor omitted intentionally: neither app is a terminal product. Pills use ceil(chars × 7.2 + 32), with an 8px gap. Copy stays left of x=432; product card begins at x=456. No semantic diff colors apply.

## Motion and fallback

4.6s icon, 6s banner; stroke draw and crossbar completion, then a finished reading hold through 88%. No opacity attributes hide content in the source. CSS-only, no scripts/external resources. Reduced-motion disables animation and restores all final positions, opacities and stroke offsets. Static SVG counterparts are explicit fallback assets.

## Adversarial self-review

Act on: kit exporter’s fill-only mono conversion would blacken the plate while retaining colored strokes; replace generated variants with transparent, truly mono/reversed marks. Adaptive foreground must omit the icon background, keeping the original mark in the 66dp safe zone. Social text must use actual foreground token rather than the kit builder default. These corrections are applied after kit_build.
Consider: system font metrics vary; long text is kept well away from card edges and the wordmark uses a wide clear column. No unsupported numerical feature/performance claim appears in artwork.
Noted: SVG playback and reduced-motion final states passed isolated Chromium checks; see qa/browser-motion.json. Platform packs are optional future identity exports, not live iOS/Android apps.

Final self-review corrections: social cards now inline original art, because secure SVG rasterizers omit relative sibling SVG images; all social PNGs were regenerated and visually checked. Theme-neutral board/preview defaults were replaced with each brand’s declared palette. Stroke paths carry explicit fill="none" so kit inlining cannot turn them into filled shapes. Native Eave exports include rounded transparent macOS icon artwork and an 18pt monochrome status template.
