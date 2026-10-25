# Eave design system

Eave is a native macOS utility. Settings should help someone install a local script, understand its result and recover from failure. The brand assets and the application appearance have separate roles.

## Sources and ownership

`Eave/Settings/` owns settings layout. `Sources/EaveKit/` owns native menu bar, overflow and Touch Bar presentation. `assets/brand-tokens.json` owns the new amber/ink identity palette. That palette is an explicit brand decision; it is not a set of colors extracted from AppKit.

`Eave/Settings/SettingsStyle.swift` owns the Fieldstone reference colors, semantic pane and detail backgrounds, typography, and repeated spacing. Its low-chroma sage colors apply only to app-owned backgrounds. Dynamic providers resolve Light and Dark from the supplied appearance. Increase Contrast selects native backgrounds and refreshes when macOS display options change. No layer retains a resolved `CGColor`.

Text, table selection, focus rings, accents, buttons, checkboxes, and tab rendering retain AppKit semantics. The overflow view keeps its native material. New controls use the shared settings metrics and native sizes. Eave does not add a custom control library.

## Native tokens

| Role | Value or native token |
|---|---|
| Window and native controls | `NSColor.windowBackgroundColor` and native control backgrounds |
| Settings pane | Fieldstone panel, Light `#fbfcfb`, Dark `#181c18` |
| Diagnostic and scan detail background | Fieldstone surface, Light `#eaeeea`, Dark `#212620` |
| Increase Contrast pane and details | `windowBackgroundColor` and `controlBackgroundColor` |
| Main text | `NSColor.labelColor` |
| Supporting text | `NSColor.secondaryLabelColor` |
| Dividers | `NSColor.separatorColor` |
| Interactive accent | `NSColor.controlAccentColor` |
| Failure | `NSColor.systemRed`, always with text |
| Warning/truncation | `NSColor.systemOrange`, always with text |
| Heading | System 17 pt, semibold |
| Body and table | System 13 pt |
| Metadata | System 11 pt |
| Diagnostic output | Monospaced system 11 pt |
| Outer inset | 20 pt |
| Related controls | 8 pt |
| Section separation | 12 pt, 24 pt between permission groups |
| Script row | 32 pt |

The settings window starts at 680 × 480 points and has a 600 × 420 minimum. Scripts uses a flexible name column, a 72-point interval column and a 180-point status column. The selected diagnostic region targets 112 points, with a separate section label. Native controls may impose larger fitting sizes; never force text to clip to preserve a nominal number.

## Patterns and states

Scripts groups **Open Scripts Folder**, its explanation, and the actual `~/.eave/plugins` path. A healthy empty folder shows one filename instruction and collapses the unused table, notice, and diagnostics. A populated folder shows **Last run details** beneath its table.

A scan failure or rejected registration adds a concise notice. **Show scan details** exposes the complete message in the existing selectable, scrollable text view. **Show last run** returns to diagnostics without changing table selection. An empty folder with a scan problem opens the scan details directly. **Retry scan** remains beside scan failures and uses the existing rescan action. Notices and details update without animation. A scan failure retains useful previous state. “Running” is shown only when the scheduler reports a current run. A successful truncated result is distinct from a complete result.

Selection survives status refresh. Diagnostic output is selectable and scrollable. Full filenames and error text remain available even when table cells truncate. A hidden settings window must not keep reloading its table.

Menu Bar explains basic separator hiding before optional Accessibility-assisted movement. The current hiding result stays with its checkbox. Optional Accessibility access has a separate explanation, status, and System Settings action. A permission request is never a first-run requirement for ordinary script execution.

Overflow is an informational list in this delivery. It uses an adaptive background, a bounded width and scrolling rather than transparent text over wallpaper. It updates while open and displays **Press Esc to close**. Escape and outside clicks dismiss it immediately. Touch Bar copy describes the Settings-window scope; neither pane advertises system-wide control.

## Keyboard, accessibility and motion

Keep native focus rings and Tab order. Tables support arrow-key selection. Buttons expose their text or an accessibility label. A red indicator supplements the status text; it never replaces it. Output text can be selected without a mouse.

Use native motion by default. The overflow preview uses a 100 ms opacity transition after its final content and geometry are set. Event monitors are active before opening. Closing and updates are immediate. Reduce Motion shows the final state immediately. A bounded fallback sets final opacity even when the compositor delivers no animation frames. New custom fades have a maximum of 120 ms and must respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. No decorative page transitions, animated status counters or moving backgrounds. The final-opacity and Reduce Motion branches have automated native coverage. A visible fade, system preference changes, keyboard traversal, and VoiceOver still require a usable desktop session. Semantic colors and control types alone do not certify accessibility.

## Identity and assets

The selected mark is an architectural overhang forming an E. Use [brand-mark.svg](assets/brand-mark.svg) for the transparent symbol, [icon.svg](assets/icon.svg) for the square identity and [logo.svg](assets/logo.svg) for the banner. [The brand brief](assets/kit/brand-brief.md) records alternatives and color provenance.

Native resources are `assets/Eave.icns` and the transparent 18-point `assets/status-mark.pdf`. The menu bar PDF is a template image so macOS supplies the foreground color. Do not use the colored square icon as a status item.

The animated icon uses a 4.6-second loop, and the banner a 6-second loop. Both draw, settle and hold the completed mark. Static SVG counterparts remain the fallback, and reduced-motion CSS presents the final state. Browser playback has a separate verification requirement from static raster inspection.

The [kit preview](assets/kit/preview_sheet_lite.html) includes concept studies, mono/reversed variants and social/platform exports. iOS and Android files are brand handoff assets. Eave remains a macOS app.

## Change acceptance

Before changing a token, inspect empty, populated, failed, long-name and truncated-output states in Light and Dark. Resize to the minimum window size and use only the keyboard. Inspect the overflow list on notched, nonnotched and offset displays. Record the result in [verification](docs/verification.md); do not claim pixel accuracy from compilation alone.
