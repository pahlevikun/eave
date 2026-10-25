# Eave audit

Read-only audit at baseline `c470903`, 24 October 2026. All tracked source, tests and behavior configuration were read in full. No application code changed, no app launched, no installed user plugin executed, no commit created. The codebase knowledge graph and persistent project knowledge source were unavailable. Findings use complete tracked source and local fixture probes. Throughput checkpoint is not applicable to this read-only investigation.

## Overview

Eave is a Swift 6, macOS 14+ menu bar application. It executes user-provided xbar-style scripts, parses output and publishes plugin status items. The app also has Hide, Notch and Touch Bar settings and adapters. The README incorrectly says there is no application, no status item and no EaveKit. Its later Round 2 section partially contradicts those claims.

The existing structure is small and useful. Keep the native macOS implementation and the EaveCore/EaveKit dependency direction. Reliability gaps and incomplete UI wiring matter more than another architectural layer.

## How it works

`Eave/EaveApp.swift` starts an accessory NSApplication. `Eave/AppDelegate.swift` creates the E status item and Settings/Quit menu, then starts AppState. `Eave/AppState.swift` constructs adapters, ensures `~/.eave/plugins`, discovers executable files, starts a filesystem watcher, polls permissions and ticks the scheduler once per second.

`PluginDiscovery.scan` sorts executable non-dotfiles, derives namespaces and refresh intervals, and rejects duplicate namespaces. `SchedulePlanner.due` decides what can run. The PluginScheduler actor tracks run state and launches detached tasks. ScriptRunner executes a child with a timeout and captures stdout/stderr in temporary files. ScriptOutput accepts a limited JSON object or delegates to XbarParser. Delivery returns plain ScriptItem values to AppState, which updates the status items, Touch Bar state and notch packing plan.

HidePlan chooses basic separator hiding or item movement with Accessibility. HiddenSectionController interprets that decision through SeparatorEngine and ItemMover. NotchTrayModel packs measured plugin items against the calculated space beside the notch. NotchPanel displays the overflow titles. TouchBarPlan limits non-spacer entries by count and TouchBarPresenter constructs an NSTouchBar, but the app never attaches it to a window.

## Architecture detection and evaluation

The primary structure is a native application with planning functions and imperative adapters. It also has a convention-based script extension interface. Confidence is high from imports, call paths and the SwiftPM target graph, rather than folder names alone.

- Package.swift declares EaveCore, EaveKit depending only on EaveCore, and two test targets. There are no external dependencies.
- All fourteen EaveCore source files import Foundation only. EaveKit imports EaveCore and AppKit/CoreGraphics/SwiftUI as required. AppState imports both packages and owns their construction.
- Planning code in SchedulePlanner, HidePlan, NotchTrayModel, TouchBarPlan and geometry files operates on plain values and is independently testable.
- The boundary is not a completely pure EaveCore module. PluginDiscovery uses FileManager, ScriptRunner performs process/file I/O and waiting, and PluginScheduler launches tasks and reads the clock. These are intentional portable shell responsibilities inside the library. README's actual rule is no AppKit in EaveCore, which holds. Avoid documenting the whole module as pure.
- The package dependency graph has no cycles. No EaveCore import points to EaveKit or the application. AppKit remains in EaveKit and Eave.

The architecture skill scanner ran but cannot validate Swift. Its language allowlist excludes .swift and its manifest detection excludes Package.swift. Direct CLI invocation returned no output because the script's entry-point equality check encountered the installed path layout. Invoking its exported functions produced `detect.files = 0`, `verdict = unclear`, `check.files = 0`, `violations = []`. Zero findings here do not mean zero violations. The import review above supplies the relevant evidence.

```sh
node /Users/farhan.pahlevi/.agents/skills/super-architecture/scripts/arch-scan.mjs detect . --json
node /Users/farhan.pahlevi/.agents/skills/super-architecture/scripts/arch-scan.mjs check . --json
node --input-type=module -e 'import { scanTree, detect, check } from "/Users/farhan.pahlevi/.agents/skills/super-architecture/scripts/arch-scan.mjs"; const m = scanTree(process.cwd()); console.log(JSON.stringify({ detect: detect(m), check: check(m) }, null, 2));'
```

The applicable quick diagnostic passes six questions. Business rules can run without UI, imports point inward, workflow signatures use plain values, GUI frameworks stay outside EaveCore, package dependencies have no cycles and AppState wires runtime dependencies. Database replacement is not applicable because there is no database. This diagnostic does not certify pure functional architecture or runtime correctness.

The domain maturity scale for aggregate-heavy business systems does not fit this desktop utility. The current structure is sufficient. Team fit, delivery cycle time and a normalized debt score cannot be measured from this snapshot, so no numerical health score is invented. The main debt is missing lifecycle tests around removal and in-flight results, thin AppKit test coverage and adapters whose user-facing feature is only partially wired.

## Confirmed correctness findings

Priorities express user impact and implementation order. P1 means a crash or a broken advertised interaction. P2 means incorrect state or behavior with a narrower impact. Runtime fixture probes are identified explicitly. UI consequences inferred from geometry are identified separately.

| ID | Priority | Finding and reproducible trigger | Evidence | Bounded correction |
|---|---|---|---|---|
| C1 | P1 | A sufficiently large refresh interval crashes parsing instead of rejecting the filename. `RefreshInterval.parse(fromFilename: "clock.9223372036854775807d.sh")` exited with SIGTRAP in an isolated Swift probe. An executable file with this name reaches the same code during discovery. | Sources/EaveCore/Model/ScriptItem.swift:60 multiplies a parsed Int by 86400 without overflow handling. | Use checked multiplication and return nil for overflow. Add boundary tests. |
| C2 | P1 | Removing a plugin while it is running still delivers its result and recreates its diagnostics after removal. Remove, then re-add during an old run can also allow an old completion to interfere with the new run's bookkeeping. | Sources/EaveCore/Script/PluginScheduler.swift:84 filters state, but :106 retains the detached run and :127 accepts any completion. A temporary fixture probe called setPlugins([]) during sleep and printed `removed plugin delivered = true` and `removed plugin diagnostics recreated = true`. | Associate runs with a per-plugin generation/token and accept completion only for the current registration/run. Preserve running exclusion for actual in-flight work. Test remove, replacement and remove/re-add races. |
| C3 | P1 | A successfully displayed plugin stays in the menu bar and cached Touch Bar state after its executable is deleted or disabled. A rescan only replaces the scheduler's plugin list. | Eave/AppState.swift:154 does not reconcile menuBarRenderer, touchBarItemsByNamespace or lastRunFailed. Rendering removal exists only inside handleDelivery at :181. | Reconcile removed namespaces and IDs during rescan, refresh downstream presentation and reject stale deliveries. Add app orchestration coverage. |
| C4 | P2 | Refresh intervals and status ages use run start time instead of completion time. A slow one-second plugin can run again immediately after it finishes. | Sources/EaveCore/Script/PluginScheduler.swift:107 assigns finishedAt before Self.run at :108, contrary to SchedulePlanner's completion-based contract. A fixture sleeping 0.4 seconds had a reported completion age of 0.709 seconds at delivery in the observed run. This is reproduction evidence, not a performance benchmark. | Capture completion time after execution. Test that a slow run waits its full interval after finishing. |
| C5 | P1 | The Touch Bar setting cannot display the presenter's Touch Bar through the current application path. | Sources/EaveKit/TouchBar/TouchBarPresenter.swift:33 defines attach(to:), but repository-wide search found no call. AppState only enables customization and updates items. SettingsWindow never sets window.touchBar. | Attach the existing presenter to an appropriate app window and describe the supported scope honestly. Whole-bar takeover and app blacklist behavior would require a separate product implementation. |
| C6 | P1 | The notch panel frame occupies the menu-bar/notch strip, rather than extending below it. Its height is only safe-area/menu-bar height and cannot hold multiple text rows. It is horizontally centered on notchMaxX, the notch's right edge. | Sources/EaveKit/Notch/NotchPanel.swift:47 through :67 sets originY = screen.maxY - height with that same height, so panel.maxY = screen.maxY. For the test geometry, width 190 centers at x = 853 rather than the notch midpoint x = 758. NotchTrayView adds 20 points of vertical padding before rows. The resulting clipping/occlusion is inferred from this geometry, not visually exercised. | Extract a pure panel frame calculation, center on the notch midpoint, place below the menu bar, size to bounded content and use scrolling. Cover both screen shapes and offsets. |
| C7 | P2 | A display without a notch receives a notch wider than its entire screen and a zero right-side budget. The panel can extend off the right edge. | Eave/AppState.swift:128 substitutes zero auxiliary widths. NotchGeometry.width(1920,0,0) returned 1924 and usableWidthRightOfNotch returned 0 in the fixture probe. NotchPanel repeats that calculation. | Model the no-notch case explicitly and clamp panel frames to the selected screen. |
| C8 | P2 | Opening a notch tray freezes its contents until it is closed and reopened. | NotchPanel.open constructs a value-based NotchTrayView once at :23. Later AppState deliveries only assign notchTrayPlan. There is no update method or observable plan binding. | Update the open panel when its current plan changes, or bind a dedicated observable presentation model. |
| C9 | P2 | The notch tray is a title list, without plugin actions, menus, actual status-item relocation or an empty state. The header's claim that the notch is a one-click overflow button is not wired. | Sources/EaveKit/Notch/NotchTrayView.swift contains Text only. AppDelegate's menu has Settings and Quit only. MenuBarRenderer never consumes plan.kept or plan.overflowed. | Treat current behavior as an informational prototype. A complete overflow interaction needs an explicit action-bearing model and an entry point accessible outside Settings. |
| C10 | P2 | APIs documented as preserving bar order use arbitrary dictionary iteration order. | MenuBarRenderer.orderedNamespaces at Sources/EaveKit/MenuBar/MenuBarRenderer.swift:117 returns Array(statusItems.keys). AppState.refreshTouchBar at :204 flattens dictionary values. Async delivery order also governs item creation. | Preserve a defined namespace sequence. If actual visual order matters, measure/sort screen coordinates rather than assume plugin filename order matches it. |
| C11 | P2 | Successful output truncation is invisible in Settings. Users can see a partial title labeled simply ok. | Sources/EaveCore/Settings/PluginStatusText.swift:26 returns the ok line before checking outputTruncated; the truncation suffix exists only in exitLine at :44. | Include truncation in successful status text and expose the diagnostic detail. |
| C12 | P2 | The documented 1 MB limit does not bound temporary-file growth while the process runs. | ScriptRunner redirects all output to files at Sources/EaveCore/Script/ScriptRunner.swift:62 through :77. readCapped only runs after execution at :85 and :86. Existing huge-output tests prove the returned data cap only. | Correct the claim immediately. A true disk-output bound requires runtime monitoring or a bounded draining strategy with child cleanup. Keep this separate from a UI-only change. |
| C13 | P2 | Watcher startup fallback ignores one documented failure result. | Eave/PluginFolderWatcher.swift:68 ignores FSEventStreamStart's Bool and returns true. AppState enables polling fallback only when start() returns false. | Release/invalidate the failed stream and return false when the start call fails. |
| C14 | P2 | Parser compatibility is narrower than the xbar-unchanged claim. bash/paramN/refresh parameters are parsed but no adapter handles them; root href and color are ignored. Plain menu leaves without href have no action. | XbarParser stores arbitrary parameters. MenuItemBuilder only handles href on leaf children, MenuBarRenderer only renders the first top-level title and image, and the Pipeline fixture's refresh=true has no rendering behavior. | Publish the supported parameter subset. Add actions as deliberate bounded features with behavior tests, rather than promise full compatibility. |

## UI and design audit

Current application styling is standard macOS. The Settings window uses NSTabView, native buttons, semantic label colors, native table selection and system fonts. Explanatory labels use 11-point type and 12/16-point edge spacing. Failure uses systemRed. The notch uses a transparent panel and 12-point SwiftUI text without its own background material. There are no custom in-app typefaces, accent definitions, asset catalog or design tokens in the tracked tree.

The README banner is different evidence. `.github/header.png` is an aspirational amber-on-near-black brand mock with a roof symbol, rounded dark panels and four tools. It says 35 tests while README says 60 and the measured suite contains 98. Its pictured Search, Hide and clickable notch are not an application screenshot. Retaining native adaptive appearance is consistent with the real app. Copying the banner's dark theme into every control would introduce a new product styling decision.

The settings experience has several source-confirmed gaps.

- An empty Scripts list gives no explanation and no way to open the plugin directory. The app creates ~/.eave/plugins silently. A first-time user cannot learn the installation path from the window.
- The settings table uses four fixed initial columns totaling 540 points inside a 560-point window with 24 points of outer margins, a vertical scroller and a tab frame. ScriptsPane sets no flexible sizing policy or horizontal scroller, and SettingsWindow sets no minimum size. Clipping at the initial size and severe shrinking are credible layout risks that still need an actual window check.
- The Failed column duplicates information already contained in status text and expresses failure as an unlabeled red dot. A selected-plugin detail area could expose the actual stderr already retained in PluginDiagnostics.
- Permissions appear as yes/no text on Scripts. There is no request button, explanation of which tool needs which permission, or link into System Settings. Basic hiding deliberately works without permission, so the UI should explain that progression.
- Hide, Notch and Touch Bar each have a single control and explanation, with no current state detail. Hide movement failures/skipped IDs are returned by HiddenSectionController but discarded by AppState. A user has no explanation when an operation fails.
- AppDelegate uses a literal E as the status item identity. Its menu lacks quick access to plugin folder, refresh or tray actions. The roof mark exists only in the banner.
- None of the feature toggles persists through launch. AppState starts Touch Bar enabled and hiding expanded each session. Preferences are a possible later improvement, not an undocumented existing capability.
- ScriptsPane starts a repeating refresh timer on bind and never stops it when the settings window closes or the Scripts tab becomes hidden. It reloads the entire table each second and re-creates cell labels. This is avoidable work and a source of future selection/focus instability. No CPU or accessibility regression was measured.
- NotchPanel installs only a global click monitor, so clicks inside another Eave window do not use that dismissal path. There is no Escape action or keyboard navigation in the tray. No runtime accessibility audit was performed.

## Code and slop audit

Keep the plain values, closed result enums and explicit adapter calls. They aid reading and testing. Avoid building a service layer or generic settings framework to solve these issues.

Concrete cleanup candidates are small.

- Remove the unreachable count==1 branch in MoveGeometry.dragPath. count is clamped to 4...24 immediately above it.
- NotchPanel stores self.plan but never reads it. Give it a real update purpose or remove that duplicate state.
- MenuBarRenderer.separateForHide has no repository call site. Its separatedForHide tracking and restoration closures currently do not implement the documented separation. Review public API compatibility before removal.
- SeparatorEngine.tearDown has no repository call site. It also omits stopObserving and does not reset isCollapsed. Do not present it as a complete lifecycle operation without reconciling those responsibilities.
- PermissionStore is ObservableObject, while AppState and the settings panes manually poll. ScriptsPane does not subscribe to appState changes. Avoid adding a second observation mechanism unless replacing the current timer coherently.
- AppState's `scheduler: PluginScheduler!` is initialized after other construction. A lazy property or explicit factory may remove the forced initialization state if touching this area for lifecycle fixes, but it is not a user-facing defect by itself.
- Documentation over-explains some trivial mappings while carrying stale factual claims. The misleading parts matter first. Examples include PipelineTests' assertion of the only pipeline today, PluginScheduler's claim to be the only EaveCore code knowing processes exist, and ScriptRunner's claim that its output cap prevents disk growth.
- Discovery, runner, pipeline and scheduler test helpers create fixture directories without removal. Add defer cleanup when those tests next change. OutcomeBox.wait never consumes recorded outcomes and has no timeout, so future multi-delivery tests cannot rely on it without adjustment.

## Bounded improvement candidates

| Candidate | Consumer result | Size and risk | Required evidence |
|---|---|---|---|
| Interval safety | An accidental extreme filename cannot crash Eave. | Small, pure core change. | Overflow and valid-boundary unit tests. |
| Scheduler lifecycle repair | Deleted/replaced plugins cannot redraw or corrupt later runs. | Medium concurrency change. Keep out of a visual-only patch unless tested carefully. | Removed-running, replaced-running, remove/re-add and completion-based interval tests. |
| Complete rescan reconciliation | Removing/disabled plugins disappear from all cached presentations. | Small-to-medium app orchestration change, depends on stale-result protection. | Controlled plugin list and delivery fixtures without user plugins. |
| Scripts first-run and diagnostics polish | A new user can find the plugin folder and understand failures. | High-value bounded UI work. Keep native controls and adaptive colors. | Empty list, installed plugins, nonzero stderr, timeout, truncation and resize states, plus keyboard/accessibility labels. |
| Honest capability copy | The visible controls and README match what actually works. | Small and reversible. | Source comparison and screenshot/copy review. |
| Notch geometry repair | The tray opens within the chosen display and below the notch. | Medium, ideally pure geometry first. | Notched/nonnotched/secondary display offsets, multiple rows, clamp tests and visual macOS check. |

The best visual scope is Scripts settings with an informative empty state, open-folder action, clear run statuses and selected diagnostic detail. It improves an implemented end-to-end path without pretending the unfinished notch/Touch Bar work is complete. Fix the filename overflow before encouraging users to install more plugins. Treat scheduler lifecycle repair as a separate bounded reliability task.

Potential next features grounded in current code are a manual per-plugin refresh action, persisted feature preferences, diagnostic stderr inspection/copy, clickable notch overflow using the existing ScriptItem action data, and native Touch Bar attachment for the settings window. Whole-bar takeover, application blacklists, third-party icon discovery and full xbar command compatibility need additional product and platform work. They are not already implemented by the existing APIs.

## Verification evidence

Available tools were Apple Swift 6.4 targeting arm64 macOS 27 SDK, Xcode selected at /Applications/Xcode.app/Contents/Developer, Node 20.13.1 and XcodeGen at /opt/homebrew/bin/xcodegen.

The first test invocation attempted to redirect Swift's module cache using `-Xswiftc -module-cache-path`, but manifest compilation still used the default clang cache. It failed with `Operation not permitted` opening `/var/folders/zk/7k7wv7_x12j3w89238lgqhfm0000gn/C/clang/ModuleCache/...swiftmodule`, then `unable to load standard library`. This was an environment/cache-path blocker, not a source compilation failure.

The following command succeeded from the repository root.

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/eave-audit-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/eave-audit-module-cache \
swift test --disable-sandbox \
  --scratch-path /private/tmp/eave-audit-build \
  --cache-path /private/tmp/eave-audit-cache \
  -Xswiftc -module-cache-path \
  -Xswiftc /private/tmp/eave-audit-module-cache
```

The package built successfully. Swift Testing reported 94 tests in 16 EaveCore suites passed and 4 tests in 1 EaveKit suite passed, for 98 tests total. The separate XCTest zero-test summaries are expected because these suites use Swift Testing. Reported build completion was 50.24 seconds. No performance conclusion follows from this environment-dependent build time. SwiftPM warned that user-level configuration/security cache folders were inaccessible and disabled those optional caches.

A temporary Swift executable compiled against all EaveCore files under /private/tmp and ran only its own shell fixture, `sleep 0.4; echo ready`, to reproduce scheduler timestamp/removal behavior and no-notch arithmetic. It printed the following results.

```text
completion timestamp age at delivery seconds = 0.7094030380249023
removed plugin delivered = true
removed plugin diagnostics recreated = true
nonnotched width at 1920 = 1924.0
nonnotched right budget = 0.0
```

A second temporary executable compiled ScriptItem.swift and called only RefreshInterval.parse with the extreme filename. Python subprocess reported return code -5, SIGTRAP. It did not execute a plugin or launch Eave.

An application bundle was not generated or built by this delegate. Standard XcodeGen generation can rewrite Eave/Info.plist, so it was deliberately left to the parent to run in an isolated copy/spec if needed. The package build verifies both libraries and their tests, but not the Eave application target. No claims about visual rendering, permission-gated movement, Touch Bar hardware behavior, real installed plugins, Linux execution or current CI status are made.

## Full-read manifest

Every listed text file was read in full with bounded outputs, without truncation of source files. Generated/build trees, .git and external dependencies were outside the read scope. `.github/header.png` was inspected visually as an image. It is the only tracked binary. The baseline contained 53 tracked files, 52 text files and 46 Swift files including Package.swift. Text line total is 3964 by newline count. Test source contains 98 @Test declarations. Hashes below identify the actual audited bytes and can detect later edits.

| Path | Lines | SHA-256 prefix | Read evidence |
|---|---:|---|---|
| `.cursorignore` | 4 | `6cd37bc7566b` | Full contents read |
| `.github/header.png` | binary | `4f99ad540843` | Visual inspection |
| `.github/workflows/ci.yml` | 70 | `15818d330124` | Full contents read |
| `.gitignore` | 6 | `e56d9fd21779` | Full contents read |
| `Eave/AppDelegate.swift` | 42 | `de393c00b8c6` | Full contents read |
| `Eave/AppState.swift` | 216 | `09b3fa79b6f9` | Full contents read |
| `Eave/EaveApp.swift` | 13 | `d1c82f179461` | Full contents read |
| `Eave/Info.plist` | 5 | `97704a8960b4` | Full contents read |
| `Eave/PluginFolderWatcher.swift` | 100 | `6a5e1089c49f` | Full contents read |
| `Eave/Settings/HidePane.swift` | 47 | `ca80e029561c` | Full contents read |
| `Eave/Settings/NotchPane.swift` | 45 | `538a990213d2` | Full contents read |
| `Eave/Settings/ScriptsPane.swift` | 152 | `1330993751c9` | Full contents read |
| `Eave/Settings/SettingsTabController.swift` | 47 | `f99bb0479e17` | Full contents read |
| `Eave/Settings/SettingsWindow.swift` | 36 | `ea2a8d7b8ffe` | Full contents read |
| `Eave/Settings/TouchBarPane.swift` | 47 | `fda881d64836` | Full contents read |
| `Package.swift` | 17 | `a2791a39930f` | Full contents read |
| `README.md` | 112 | `ef4252b4fed8` | Full contents read |
| `Sources/EaveCore/Geometry/NotchGeometry.swift` | 38 | `9c954783b586` | Full contents read |
| `Sources/EaveCore/Geometry/SeparatorWidth.swift` | 24 | `f5ced8bc20d8` | Full contents read |
| `Sources/EaveCore/MenuBar/HidePlan.swift` | 50 | `de3f38d7cc80` | Full contents read |
| `Sources/EaveCore/MenuBar/MoveGeometry.swift` | 46 | `1e940cc52cef` | Full contents read |
| `Sources/EaveCore/Model/ScriptItem.swift` | 62 | `9b1953061fe0` | Full contents read |
| `Sources/EaveCore/Notch/NotchTrayModel.swift` | 58 | `c257b7098b2d` | Full contents read |
| `Sources/EaveCore/Script/Plugin.swift` | 127 | `42546b62db10` | Full contents read |
| `Sources/EaveCore/Script/PluginScheduler.swift` | 196 | `820e0411b119` | Full contents read |
| `Sources/EaveCore/Script/SchedulePlanner.swift` | 28 | `8e21ba732d66` | Full contents read |
| `Sources/EaveCore/Script/ScriptOutput.swift` | 53 | `e7b4a2b14e5f` | Full contents read |
| `Sources/EaveCore/Script/ScriptRunner.swift` | 135 | `4c6aa418329a` | Full contents read |
| `Sources/EaveCore/Script/XbarParser.swift` | 128 | `5283a90f7ce9` | Full contents read |
| `Sources/EaveCore/Settings/PluginStatusText.swift` | 70 | `6e0654ccdf06` | Full contents read |
| `Sources/EaveCore/TouchBar/TouchBarPlan.swift` | 65 | `f1780bcc446b` | Full contents read |
| `Sources/EaveKit/MenuBar/HiddenSectionController.swift` | 94 | `b15d56fc1103` | Full contents read |
| `Sources/EaveKit/MenuBar/ItemMover.swift` | 203 | `e584d5cbd1f0` | Full contents read |
| `Sources/EaveKit/MenuBar/MenuBarRenderer.swift` | 154 | `f5c6c747333a` | Full contents read |
| `Sources/EaveKit/MenuBar/MenuItemBuilder.swift` | 45 | `0dcbfc96a714` | Full contents read |
| `Sources/EaveKit/MenuBar/SeparatorEngine.swift` | 88 | `75bf0ed12416` | Full contents read |
| `Sources/EaveKit/Notch/NotchPanel.swift` | 100 | `5afc23703100` | Full contents read |
| `Sources/EaveKit/Notch/NotchTrayView.swift` | 21 | `975e2e1ef55c` | Full contents read |
| `Sources/EaveKit/Permissions/PermissionStore.swift` | 42 | `688395b9edb7` | Full contents read |
| `Sources/EaveKit/TouchBar/TouchBarPresenter.swift` | 140 | `de807d39b5a1` | Full contents read |
| `Tests/EaveCoreTests/DiscoveryTests.swift` | 157 | `abea3310b6ac` | Full contents read |
| `Tests/EaveCoreTests/GeometryTests.swift` | 82 | `8a7ec1782426` | Full contents read |
| `Tests/EaveCoreTests/HidePlanTests.swift` | 53 | `d859c634e072` | Full contents read |
| `Tests/EaveCoreTests/MoveGeometryTests.swift` | 36 | `4417b4432113` | Full contents read |
| `Tests/EaveCoreTests/NotchTrayModelTests.swift` | 51 | `8997c408be70` | Full contents read |
| `Tests/EaveCoreTests/ParserTests.swift` | 89 | `27700df6b126` | Full contents read |
| `Tests/EaveCoreTests/PipelineTests.swift` | 59 | `88362b1d8254` | Full contents read |
| `Tests/EaveCoreTests/PluginStatusTextTests.swift` | 79 | `bc91cd635f19` | Full contents read |
| `Tests/EaveCoreTests/SchedulerTests.swift` | 220 | `ea193a8ac23e` | Full contents read |
| `Tests/EaveCoreTests/ScriptRunnerTests.swift` | 62 | `e94fb7178943` | Full contents read |
| `Tests/EaveCoreTests/TouchBarPlanTests.swift` | 50 | `47dcbc365d5e` | Full contents read |
| `Tests/EaveKitTests/MenuItemBuilderTests.swift` | 70 | `131e0e5b7fbe` | Full contents read |
| `project.yml` | 30 | `b8f54841ca34` | Full contents read |

The working tree was clean when the audit completed. Audit probes, Swift caches and build products live only under /private/tmp. This report lives outside the repository under ../.polish-work.
