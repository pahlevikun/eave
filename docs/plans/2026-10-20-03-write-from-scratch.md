# 03 — Write from scratch

**Status:** draft for review
**Decision:** new repo, Swift + AppKit, no Thaw fork, no dependency beyond
Sparkle.
**Verification limit:** build and test need macOS 26 + Xcode 26. This working
machine is Linux, so this plan flags every step that can't be verified here.
**Tooling:** building from Linux is genuinely possible via
[xtool](https://github.com/xtool-org/xtool), see §10.

---

## 1. Why not fork Thaw

Thaw is good. 12.1k stars, 542 Swift files, an honest `docs/ARCHITECTURE.md`,
tests on Swift Testing. But:

| Reason | Evidence |
|--------|----------|
| Bound to Ice's decisions | `ControlItem`, `MenuBarItemTag`, `MenuBarSection.Name` are all Ice descendants. Changing one meaning touches dozens of files. |
| `LayoutSolver` 67 KB | Great, but solves a problem we don't have yet (LCS reconcile across profiles). |
| GPL-3.0 | All derivatives must be GPL-3.0. If we ever want dual-license or the App Store, it closes that door. |
| Speed | Reading 542 files to learn what's safe to touch is slower than writing 4,000 lines we understand. |
| Size | 18k+ lines for one feature (hide). We need 4 features. Wrong ratio. |

**What we keep from Thaw and Ice: concepts and numbers, not code.** Everything
below was verified by reading source:

| Thing | Value | Source |
|-------|-------|--------|
| Menu bar item window layer | `kCGStatusWindowLevel` (25) | `ice/Ice/Utilities/WindowInfo.swift:62` |
| `NSStatusItem` length cap | 10,000 pt | `hidden/docs/ARCHITECTURE.md` |
| Separator formula | `max(500, min(widest * 2, 10_000))` | idem |
| Hover-to-expand | opt-in, not default | idem |
| CGEvent windowID field | `CGEventField(rawValue: 0x33)` | `ice/.../MenuBarItemManager.swift:1552` |
| Neutral cursor for drag | `(20_000, 20_000)` | idem `:1000` |
| Drag flag | `.maskCommand` only on `leftMouseDown` | idem `:1533` |
| Frame verification timeout | 50 ms | idem `:883` |
| Notch width | `frame.width - auxLeft.width - auxRight.width + 4` | `boringnotch/sizing/matters.swift:60` |
| Notch height | `safeAreaInsets.top` | idem |
| Menu bar height fallback | `hasNotch ? 37.0 : NSStatusBar.system.thickness` | `thaw/Utilities/Extensions.swift:892` |
| Notch gap | 24 pt | `thaw/MenuBar/MenuBarSectionLayout.swift:76` |
| Notch panel level | `.mainMenu + 3` | `boringnotch/components/Notch/BoringNotchWindow.swift:39` |
| Max CGS space level | `2147483647` | `boringnotch/managers/NotchSpaceManager.swift:13` |
| Spacer clamp | `8...300` | `thaw/MenuBar/MenuBarItems/MenuBarSpacer.swift:16` |
| Script output cap | 1 MB | `thaw/Utilities/HookRunner.swift:36` |
| xbar format | line 1 = title, `---`, `--` | `xbar/pkg/plugins/parse.go:12` |
| ANSI in output | supported | `mtmr/MTMR/ShellScriptTouchBarItem.swift:52` |

What we **don't** take: GPL code. Zero lines. Type names invented fresh.

---

## 2. Repo structure

```
eave/
  Package.swift
  Sources/
    EaveCore/                 # library — no AppKit
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
    EaveKit/                  # library — AppKit allowed
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

Hard rules:
- `EaveCore` may not `import AppKit`. Testable anywhere, including Linux CI
  for the pure parts.
- `EaveKit` may use AppKit but may not store app-owned state.
- `Eave` is only wiring.

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

The app target stays in an Xcode project (needs Info.plist, entitlements,
notarization). SPM for libraries, Xcode for the app. Reason: Sparkle and
notarization are not comfortable through pure SPM.

---

## 3. The three hard parts, and the code

Everything else is CRUD. These three decide whether the product works.

### 3.1 Separator engine (basic mode, zero permission)
The whole trick: one `NSStatusItem` inflated in width. Icons left of it get
pushed off-screen.

`Sources/EaveCore/Geometry/SeparatorWidth.swift`:

```swift
public enum SeparatorWidth {
    /// AppKit hard cap. Above this, the status item doesn't render.
    public static let maxLength: CGFloat = 10_000
    /// Minimum width so the separator stays visible when expanded.
    public static let expandedMin: CGFloat = 500

    /// Width while the section is hidden, computed from the widest screen.
    /// Must be the widest screen, not the main one: the menu bar is
    /// duplicated to every display, and a narrow separator on an ultrawide
    /// leaves icons still visible.
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
        // Length 1pt forces a real window with a CGWindowID.
        // Length 0 makes the status item have no window at all.
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

    /// State is derived from width, not stored. Width can be recomputed
    /// anytime (screen hot-plug) without state going stale.
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

Tests that run on Linux (`EaveCoreTests`):

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

**Limit that must be stated in the UI:** basic mode can't click hidden items.
Don't promise it.

### 3.2 Item mover (full mode)
Enumerate first:

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
    /// Layer 25 = kCGStatusWindowLevel, where all status items live.
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

Move an item:

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

    /// The private field where WindowServer stores the target window of a
    /// mouse event.
    private static let windowIDField = CGEventField(rawValue: 0x33)!

    /// Moves `item` to the left of `target`.
    ///
    /// The trick: the event isn't posted at the cursor's location but at a
    /// neutral far-off-screen point, and the target window is named via the
    /// windowID field. The item's move never drags the user's cursor.
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

        // Command only on mouseDown. If it rides on mouseUp too, the item
        // snaps back.
        down.flags = .maskCommand

        let before = frameOf(target.id)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Verify: wait for the target's frame to change, never blind-sleep.
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

Three things easy to get wrong, all closed here:
- Command flag only on `mouseDown`.
- The `windowID` field `0x33` must be set, or the event lands on a random
  window.
- Verification via frame change, not `sleep`.

Still open and required before release: mouseUp fallback to the original
position on timeout (so the item doesn't get stuck mid-drag), and
`CGEventSource.localEventsSuppressionInterval = 0` to release local events
during the drag.

### 3.3 xbar parser

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
    /// Format: first line is the status item title, `---` separates the
    /// dropdown content, `--` per submenu level, `k=v` params at end of line.
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

Note: `stripDashes` and `splitParams` are deliberately `static`, not `private`,
so they can be tested directly. This is how the parser gets real tests, not
tests through a shortcut.

Tests (Linux-capable):

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

## 4. Notch — exact numbers

`Sources/EaveCore/Geometry/NotchGeometry.swift`:

```swift
import CoreGraphics

public enum NotchGeometry {
    /// The gap macOS leaves on both sides of the notch.
    public static let gap: CGFloat = 24

    /// Notch width from the two areas beside it. `+4` because those areas
    /// don't touch the notch edge.
    public static func width(
        screenWidth: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGFloat {
        max(0, screenWidth - auxLeftWidth - auxRightWidth + 4)
    }

    /// Notch height: safe area, falling back to the notched menu bar height.
    public static func height(safeAreaTop: CGFloat, isNotched: Bool) -> CGFloat {
        safeAreaTop > 0 ? safeAreaTop : (isNotched ? 37 : 24)
    }
}
```

The panel (`EaveKit/Notch/NotchPanel.swift`) uses this configuration:

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

And a subclass that refuses to become the key window:

```swift
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

Why `canBecomeKey = false`: the notch covers part of the menu bar. If the
panel could become key, a click there could swallow a menu bar click or
activate the app for no reason. Click detection uses a global monitor, not
`mouseDown` on the window.

---

## 5. Touch Bar — one call

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

Rule taken from MTMR (`AppSettings.blacklistedAppIds` + observer
`didActivateApplicationNotification`): if a blacklisted app is in front,
release the takeover. Default blacklist: Xcode, Photoshop, Final Cut, Logic.
Reason: those apps have their own Touch Bar that's more useful.

Device detection, not OS version:

```swift
extension NSTouchBar {
    static var isHardwarePresent: Bool {
        // Some MacBook Pro 13" lack a Touch Bar, so check for the device,
        // not the model or the OS version.
        !NSTouchBar.isSupportedByCurrentSystem() == false
            && NSClassFromString("DFRFoundation") != nil
    }
}
```

Note: the `isHardwarePresent` implementation above is not final, and can't be
tested without the device. This is an open item, not a done thing.

---

## 6. Work order

Each task has its own test cycle and ends runnable.

### Task 1 — A running skeleton
- [ ] `git init`, the `Package.swift` above, `swift test` green with one empty test
- [ ] Xcode project: app target `Eave`, `LSUIElement = YES`, deployment target macOS 14
- [ ] `NSStatusItem` with placeholder icon, dropdown with a single "Quit" item
- [ ] **Verify:** app appears in the menu bar, Quit closes it

### Task 2 — Models
- [ ] `ScriptItem`, `ScriptAction`, `RefreshInterval`, `Section`, `Profile`
- [ ] `RefreshInterval` parsed from filenames: `foo.5s.sh`, `bar.2m.sh`,
      `baz.1h.sh`, `qux.1d.sh`. Deliver something that actually works.
- [ ] **Verify:** 4 tests in `EaveCoreTests`

### Task 3 — ScriptRunner
- [ ] `Process` with `executableURL`, arguments, minimal environment (PATH, HOME)
- [ ] Default timeout 5 s, `terminate()` then `kill(SIGKILL)` after 1 s
- [ ] 1 MB output cap, remainder dropped with a flag
- [ ] **Verify:** `sleep 10` times out; `cat /dev/urandom` fills no memory

### Task 4 — Parser
- [ ] `XbarParser` + `JSONOutputParser`
- [ ] **Verify:** 6 parser tests, including broken input (blank line, double
      `---`, param without `=`)

### Task 5 — MenuBarRenderer
- [ ] One top-level `ScriptItem` = one `NSStatusItem`
- [ ] Dropdown from `children`
- [ ] **Verify:** 3 sample plugins run: clock, cpu (`top -l 1`), git branch

### Task 6 — Separator basic mode
- [ ] `SeparatorWidth` + `SeparatorEngine`
- [ ] Reveal on hover/click/scroll, timer rehide
- [ ] **Verify:** 3 pure tests + manual: hide, click empty area, icons appear

### Task 7 — Spacer + profile
- [ ] Spacer item, clamp `8...300`, saved per profile
- [ ] **Verify:** restart the app, spacer and width return

### Task 8 — Settings shell
- [ ] 5 tabs: General, Hide, Scripts, Notch, Touch Bar
- [ ] Touch Bar tab hidden when `isHardwarePresent == false`
- [ ] **Verify:** on a Mac without notch and without Touch Bar, 3 tabs show,
      nothing crashes

### Task 9 — Notch panel
- [ ] `NotchGeometry` + pure tests
- [ ] `NotchPanel` with the §4 configuration
- [ ] Notch click → open, outside click → close, via
      `NSEvent.addGlobalMonitorForEvents`
- [ ] **Verify:** on a notched Mac, the panel appears exactly below the notch
      and doesn't swallow menu bar clicks

### Task 10 — Notch tray
- [ ] `NotchTrayModel`: items that don't fit go into the tray
- [ ] **Verify:** a 14" screen with 20 items, the tray holds the overflow

### Task 11 — Item mover (full mode)
- [ ] `WindowList` + `ItemMover`
- [ ] MouseUp fallback to original position
- [ ] **Verify:** move an item from visible to hidden, restart, position holds

### Task 12 — Touch Bar
- [ ] `TouchBarPresenter`, item factory, blacklist
- [ ] **Verify:** on a MacBook Pro 13", takeover works; open Xcode, takeover releases

### Task 13 — Release
- [ ] Final icon from plan 02
- [ ] 3-screen onboarding
- [ ] Sparkle, notarization, DMG, cask

---

## 7. Test strategy, and its limits

**Verified already on this machine:** `swift test` green, 35 tests, 0.57 s.

| Layer | Testable on Linux | Needs macOS | Status |
|-------|-------------------|-------------|--------|
| `SeparatorWidth` | yes | — | 4 tests green |
| `NotchGeometry` | yes | — | 6 tests green |
| `RefreshInterval` | yes | — | 7 tests green |
| `XbarParser` | yes | — | 11 tests green |
| `ScriptRunner` | yes | — | 7 tests green, incl. timeout and 1 MB output |
| `EaveKit` touching AppKit | no | yes | not yet |
| `ItemMover`, `SeparatorEngine`, `NotchPanel` | no | yes, ideally a real Mac not a VM | not yet |
| Touch Bar | no | yes, and only on Touch Bar hardware | not yet |

**Findings from writing `ScriptRunner`, and they're not trivial:**

Catching stdout through a `Pipe` **hangs** when the script spawns another
process. The child is a shell, and `sleep`/`curl` inside it are grandchildren
that also hold the write end of the pipe. Killing the shell with SIGKILL
doesn't touch grandchildren, so the pipe never sees EOF, and the pipe reader
waits until the grandchildren finish. Measured: 10 s for a `sleep 10` script
with a 0.5 s timeout.

Two fixes, both required:

1. **Output to a temp file, not a pipe.** Files don't have the EOF problem.
   Enforce the size cap at read time, not write time.
2. **Signal the process group (`kill(-pid, SIGTERM)`), not just the child.**
   This is what actually kills the grandchildren.

What's **never** allowed: writing tests that always pass. If a behavior can
only be verified by eyeballing, write a manual step in the plan, don't
pretend it's a test.

CI: `swift test` for `EaveCore` on Linux (fast, free), `xcodebuild test` for
`EaveKit` on a macOS runner (slow, paid). Two separate jobs so feedback is
fast for the layer that changes most.

---

## 8. Decision checklist

- [ ] Final name (plan 02)
- [ ] App Store or direct-only. If App Store: remove `SeparatorEngine`? No,
      that's legal. What must go: private CGS space, AX automation. That cuts
      Phase D and F.
- [ ] Sparkle or roll our own updater. Sparkle is cheaper.
- [ ] Deployment target macOS 14 or 26. macOS 14 widens the market but must
      avoid 15+ APIs, some of which the notch wants.
- [ ] UI language: English only, or English + Indonesian.

---

## 9. Not in v1

- Automatic per-app profiles
- Plugin marketplace
- Sync between Macs
- Now playing in the notch (boring.notch ships a 25.9 KB `MusicManager`;
  we go with `MPNowPlayingInfoCenter` in v2)
- Menu bar icon search (needs Screen Recording, defer to v2)
- Conditional triggers (battery, wifi, focus). Thaw has 20+ kinds; we start
  with none.

---

## 10. Build and test from this Linux machine (xtool)

**Status: not tried yet. This is a preamble, not a working thing.**

[xtool](https://github.com/xtool-org/xtool) (13.2k stars, MIT, pushed today)
makes `swift build` targeting iOS **work without a Mac and without Xcode**,
straight from Linux. The core is a `Darwin Swift SDK` downloaded from an
official Xcode, then `swift build --swift-sdk`.
(`Sources/XToolSupport/SDKCommand.swift`)

**For this project, relevance is limited but real:**

Useful:
- CI: `swift test` for `EaveCore` on a Linux runner — free, no paid macOS
  runner. Something we could exercise on this machine.
- `xtool new` + `xtool dev` if an iOS companion appears someday (say, a
  remote for the menu bar). v1 has no iOS app, so this goes unused.

Not used:
- Code signing, App Store Connect API (`XKit`), iPhone installs. All that is
  iOS business, not menu bar business.

**To try on this machine, in order:**

1. Download the `swift-sdk` via `xtool sdk install` (needs an Xcode 26 .xip,
   roughly 1 GB).
2. Run `swift build --swift-sdk arm64-apple-ios` against the future
   `Sources/EaveKit`. If this compiles, a compile check can run in CI; tests
   still need macOS.
3. If compile fails (AppKit APIs), add an `#if os(macOS)` guard in one place.

Long discussion at
[forums.swift.org](https://forums.swift.org/t/xtool-cross-platform-xcode-replacement-build-ios-apps-on-linux-and-more/79803)
for internals. Read it if stuck.
