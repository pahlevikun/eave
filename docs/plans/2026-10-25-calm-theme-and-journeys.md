# Calm theme and script recovery

The 2026-10-25 update refines the four native settings tabs and the existing overflow preview. It preserves the local script directory, scheduler, static app capabilities, permission policy, and prior uncommitted lifecycle fixes.

## Source audit and chosen direction

The audit inspected current `Eave/Settings`, `AppState`, the overflow pair in `EaveKit`, and existing application and native presentation tests. No code graph index was available for Eave. The source confirmed a two-line recovery notice with a fixed 30-point height, repeated empty-state instructions, unnamed diagnostics, mixed Scripts and Plugins action names, and combined feature and permission status.

The shared target was `eave-scripts-light.png`, inspected before UI edits. Its actual dimensions are 1492 by 1054 pixels. It is a generated grouping reference, not a native screenshot. The application retains a 680 by 480 point window and a 600 by 420 minimum. Native controls, the real `~/.eave/plugins` path, and readable recovery take priority over the target's texture, decorative dots, and oversized chrome. No pixel-parity claim is made.

The palette comparison considered anchor-derived OKLCH ramps, extraction from the prior brand palette, and hue-cycling schemes. Fieldstone provides quiet sage backgrounds through two semantic roles. It retains the warm brand assets. Exact role values are documented in `DESIGN.md`; native text, selection, focus, and controls keep their system semantics. Increase Contrast uses native backgrounds. This change adds no color dependency or theme preference.

## Implemented journeys

- **First script.** Open Scripts Folder and the real path lead the pane. A healthy empty folder shows the executable `clock.5s.sh` example. Unused table and diagnostic regions collapse.
- **Inspect a run.** Last run details names the existing selectable and scrollable output. Refresh keeps the selected script, valid text selection, and scroll origin. Shorter output still clamps selection and scroll.
- **Recover from a scan problem.** A compact notice keeps Retry scan available for errors. Show scan details exposes the complete error and rejection text in the existing output region. Show last run returns to the selected script. An empty failed scan shows full details directly. A successful scan removes the notice.
- **Menu Bar.** The current hiding result stays beside the existing checkbox. Optional Accessibility access has a separate explanation, status, and System Settings button. Permission behavior is unchanged.
- **Overflow.** The preview remains informational and displays Press Esc to close. It opens with a 100 ms opacity transition after final geometry is set. It closes and updates immediately. Reduce Motion shows full opacity immediately.
- **Touch Bar.** Copy states that the feature applies to the Settings window on supported Macs. Capabilities are unchanged.

`SettingsStyle` owns the background reference values, semantic mappings, repeated spacing, and native typography. Light and Dark colors use `NSColor` dynamic providers. The native Increase Contrast preference is read through `NSWorkspace` and display-option notifications refresh existing panes. No background uses a frozen `CGColor`.

## Verification record

The final full Swift suite passed with 123 tests and one existing GUI-delivery test skipped. Swift Testing reports 124 total because its total includes the skip. The suite contains 103 passing Core tests, 10 passing Kit tests, and 10 passing Application tests. All application sources also passed Swift 6 typechecking. `git diff --check` passed.

The rerun commands used writable scratch caches.

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/eave-calm-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/eave-calm-module-cache \
swift test --disable-sandbox \
  --scratch-path /private/tmp/eave-calm-build \
  --cache-path /private/tmp/eave-calm-cache \
  -Xswiftc -module-cache-path -Xswiftc /private/tmp/eave-calm-module-cache

CLANG_MODULE_CACHE_PATH=/private/tmp/eave-calm-app-clang-cache \
swiftc -disable-sandbox -typecheck -parse-as-library -swift-version 6 \
  -module-cache-path /private/tmp/eave-calm-app-module-cache \
  -I /private/tmp/eave-calm-build/out/Products/Debug \
  Eave/*.swift Eave/Settings/*.swift
```

The first standalone typecheck exited zero but emitted subprocess sandbox warnings. The documented rerun disables that compiler subprocess sandbox and completed with no output. Both commands leave personal cache directories unchanged.

Focused checks passed for full recovery text, recovery clearing, empty onboarding, periodic diagnostic selection and scrolling, shorter-output clamping, light-to-dark-to-light resolution, explicit increased-contrast mappings, overflow final opacity, and the Reduce Motion branch. Increase Contrast mappings are tested with injected preference values under valid Aqua and Dark Aqua appearances. They do not change personal preferences or establish the live system toggle behavior.

The native verifier ran 102 independent AppKit object, layout, and action checks with no failures. The fixture covered both window sizes and both base appearances, complete 60-rejection messages, selected scripts, retained text selections and scroll offsets, and cleared recovery state. This run preceded the final increased-contrast implementation. The layout and recovery code did not change afterward.

An initial opacity test stayed at zero in the command-line host. That host also failed to create a drawable native window. The observed failure supports a final-state fallback for this environment; it does not establish an animation failure in a normal desktop session. The final implementation reaches full opacity after 100 ms even in that condition. Native tests and the independent `NSApplication.run` fixture verify the final state and the immediate Reduce Motion branch. They do not establish the visual quality of the fade.

The attempt to capture the task's own native window failed. AppKit returned window number zero and the window could not become key. `screencapture` returned `could not create image from window`; the host also reported an invalid `com.apple.hiservices-xpcservice` connection. No native product screenshot or visual acceptance is claimed.

## Remaining desktop proof

A usable macOS desktop session is still required for actual Light and Dark rendering, rendered native text and selection contrast, keyboard-only traversal, VoiceOver, live Increase Contrast changes, visible reduced-motion behavior, multi-display placement, and physical Touch Bar hardware. The generated target and successful source checks do not replace those observations.

No installed user plugins were executed. No personal preferences, permissions, dependencies, branches, commits, or releases were created. The existing opt-in native status-delivery test remains explicitly skipped in this host. Independent source review found no additional Eave defects. The unavailable desktop checks above remain open.

Saved evidence: [Swift tests](../evidence/2026-10-25-calm/swift-tests.log), [clean typecheck output](../evidence/2026-10-25-calm/typecheck.log), [independent native checks](../evidence/2026-10-25-calm/native-checks.log), and [failed window-capture probe](../evidence/2026-10-25-calm/capture-probe.log).
