# Eave verification

The 2026-10-24 implementation and three independent review fixes form the historical baseline below. The [2026-10-25 calm interface record](plans/2026-10-25-calm-theme-and-journeys.md) tracks the current follow-up. Automated native fixtures are separate from desktop acceptance.

## Automated results

| Check | Result |
|---|---|
| Baseline at `c470903274ec80b030475f2cda34d2620e3800eb` | 98 tests passed |
| Final Swift suite | **116 passed; one explicitly skipped** |
| Application sources, Swift 6 typecheck | Passed |
| Independent source review and fix re-review | All three reported interaction defects closed |
| Whitespace check | Passed |

The final suite includes 103 Core, eight Kit and five passing Application tests. The skipped `removalClearsAllPresentationsAndFailures` fixture is opt-in through `EAVE_NATIVE_UI_TESTS=1`; its full native delivery path could not be established in this command-line host. It is not counted as a passing test.

Regression coverage includes checked interval overflow, actual completion time, retired/replaced registrations, in-flight exclusion, scan failure retention, watcher-start failure, truncation text and pure display geometry. Seven offscreen AppKit/SwiftUI tests verify diagnostic selection/scroll preservation, retained overflow scroll views and cached Touch Bar enabled-state changes. They execute no installed user plugins and open no URLs.

The native fixes were reproduced before repair: six focused tests failed, and the shorter-document clamp guard already passed. All seven then passed. Changed overflow coverage appends a row while existing items survive. It does not establish every list-removal or display-placement scenario.

## Reproduce the source checks

From the repository root:

```sh
swift test
```

This environment required explicit writable caches:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/eave-polish-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/eave-polish-module-cache \
swift test --disable-sandbox \
  --scratch-path /private/tmp/eave-polish-build \
  --cache-path /private/tmp/eave-polish-cache \
  -Xswiftc -module-cache-path -Xswiftc /private/tmp/eave-polish-module-cache

CLANG_MODULE_CACHE_PATH=/private/tmp/eave-app-clang-cache \
swiftc -typecheck -parse-as-library -swift-version 6 \
  -module-cache-path /private/tmp/eave-app-module-cache \
  -I /private/tmp/eave-polish-build/out/Products/Debug \
  Eave/*.swift Eave/Settings/*.swift
```

The module path above reflects this machine's SwiftPM/Xcode build layout. A different Swift toolchain can use a different scratch-product path.

## Build and desktop limits

XcodeGen generated a project in an isolated temporary copy. Standard `xcodebuild` stopped during local package resolution because it could not write the SwiftPM manifest cache under the user's Library/Caches. No signed build or release was attempted.

Standalone application typechecking passed, and offscreen native fixtures ran. An additional bitmap-render probe produced incomplete offscreen appearance/button rendering, so those images are not presented as product screenshots or visual acceptance.

The final window, permission-assisted movement, physical Touch Bar, keyboard/VoiceOver behavior and multiple-display placement need a usable macOS desktop session. The same-path script-content policy also remains explicit: an unchanged Plugin registration is retained; the next execution reads changed file contents. No file-content fingerprint is claimed.

## Brand evidence

Static and animated-fallback SVGs were rendered and inspected. Four core SVGs passed their audit and the medium kit passed validation. Eave's ICNS decoded successfully; the status PDF is transparent and 18 × 18 points. Independent asset review passed. Stale artwork, unused animation rules and unavailable handoff references were removed; README embeds resolve.

Isolated Chromium verified advancing CSS animation time, the settled reading hold, and a complete nonanimated final state under Reduced Motion for both animated assets. The rendered banners were also inspected. See [motion evidence](../assets/kit/qa/browser-motion.json). This validates SVG branding, not native application motion or accessibility.

## Before a release

Run the matrix in [the development plan](plans/2026-10-24-polish-and-next-development.md#release-acceptance-matrix). Record actual Light/Dark, keyboard, VoiceOver, Reduced Motion, notched/nonnotched and Touch Bar observations. The app still executes trusted local scripts with the user's privileges. Returned-output limits do not bound temporary-file growth or guarantee descendant cleanup; those have a dedicated next-development slice.
