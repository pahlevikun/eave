# 01 — One app, four tools

**Status:** draft for review
**Codename:** Eave (final name = open decision, see plan 02)
**Basis:** research in `/root/.hermes/cache/scratch/menubar-research/` (Ice, Thaw, hidden, boring.notch, MTMR, xbar, Pock)

---

## 1. Thesis

Four tools, one engine.

```
                    ┌──────────────────────────┐
                    │      Script Engine       │
                    │    run · parse · cache   │
                    └────────────┬─────────────┘
                                 │  ScriptItem
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐      ┌─────────▼────────┐     ┌─────────▼─────────┐
│ Menu bar      │      │ Notch panel      │     │ Touch Bar         │
│ NSStatusItem  │      │ NSPanel          │     │ NSTouchBar modal  │
└───────────────┘      └──────────────────┘     └───────────────────┘
        ▲
        │  also used by
┌───────┴────────┐
│ Hide engine    │  basic (separator) · full (CGEvent)
└────────────────┘
```

One plugin, written once. Shows up in the menu bar, in the notch tray, and in
the Touch Bar. That's why this is one app, not four. Split into four apps, the
script engine gets written four times and plugins get installed four times.

---

## 2. Four tools, one app

| # | Tool | Main surface | Permission |
|---|------|--------------|------------|
| 1 | Hide menu bar | icon in menu bar + dropdown | Basic: none. Full: Accessibility |
| 2 | Custom script | items in menu bar + dropdown | none |
| 3 | Notch | panel below the notch | none (Screen Recording optional for preview) |
| 4 | Touch Bar | system modal Touch Bar | Accessibility (for per-app takeover) |

All share:
- one `ScriptEngine`
- one `PermissionStore`
- one Settings window with 4 panes
- one status item icon

---

## 3. Module map

Everything lives in one SPM library `EaveCore`, plus one thin app target.

```
EaveCore/
  Model/
    ScriptItem.swift        // id, title, icon, color, submenu, actions
    ScriptAction.swift      // .shell(path,args) .appleScript(src) .openURL(url)
    Section.swift           // visible / hidden / alwaysHidden
    Profile.swift           // name, display, item list, spacing
    RefreshInterval.swift   // n/seconds..hours, parsed from filename
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
    SectionController.swift // 3 sections, rehide timer
    SpacerController.swift  // spacer item, clamp 8...300
  Notch/
    NotchGeometry.swift     // auxiliaryTop* → CGRect
    NotchPanel.swift        // NSPanel .mainMenu+3, canBecomeKey=false
    NotchTrayModel.swift    // which items go in the tray
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
Eave/                       // app target — thin
  EaveApp.swift
  StatusItemController.swift
  SettingsWindow.swift
  SettingsPanes/  (4 panes)
```

Rule: `Model` may not import AppKit. `Script` may not import AppKit.
Everything that touches UI lives in `Render`, `MenuBar`, `Notch`, `TouchBar`.
This is what lets models and parsers run under `swift test` on a machine
without GUI.

---

## 4. When each tool is active

This decides whether the app feels like one product or four products taped
together.

**One status item.** The Eave icon. Click = dropdown. Not four separate icons;
someone with 20 menu bar icons doesn't need three more.

**Dropdown = tool switcher + content.**

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

Only active sections appear. On a MacBook without Touch Bar, the Touch Bar row
never shows. Detection: `NSTouchBar.isSupported` / device check, not OS check.

**Settings = 4 tabs, not one long tab.**

```
[ General ] [ Hide ] [ Scripts ] [ Notch ] [ Touch Bar ] [ About ]
```

Tabs whose hardware is missing are hidden. Touch Bar tab disappears on a Mac
without Touch Bar. Notch tab stays but shows "This display has no notch" and
falls back to preview mode.

---

## 5. Permission model (matters for App Store, and for users who refuse TCC)

Three tiers, chosen once by the user, never forced.

| Mode | Needs | Gets | Doesn't get |
|------|-------|------|-------------|
| Basic | none | hide all icons left of the separator, spacers, scripts, notch tray | move individual items, click hidden items |
| Standard | Accessibility | + move items, click hidden items, full notch tray | icon preview (needs Screen Recording) |
| Full | + Screen Recording | + real icon thumbnails in tray and search | — |

Every feature must have an answer in Basic, even a limited one. This is what
keeps the app useful when a user refuses the TCC dialog, and what lets the app
reach a wider audience.

Permission status is checked every 1 s while the app is running, the pattern
from Ice (`Permission.swift:63` `Timer.publish(every: 1)`), not just at launch.
Users often grant permission after the app is already running.

---

## 6. Distribution

Two builds from one codebase:

- **Direct** — Developer ID, notarized, Sparkle. Full mode.
- **App Store** — App Sandbox, no private CGS API, no Accessibility automation.
  Basic + script + notch (notch via public AX). Store build uses the
  `EAVE_APPSTORE` compile flag to disable disallowed paths.

If the App Store proves too costly to maintain, drop it. But the architecture
should be ready from the start so the decision can happen later without
refactoring.

---

## 7. Work checklist

### Phase A — foundation (one empty app that runs)
- [ ] Repo created, `Package.swift` with `EaveCore` target + test target
- [ ] `ScriptItem`, `ScriptAction`, `RefreshInterval` + round-trip tests
- [ ] App target: `LSUIElement = true`, one `NSStatusItem`, empty dropdown
- [ ] Empty Settings window with 6 tabs, Touch Bar tab auto-hides
- [ ] CI: `swift test` runs without GUI

### Phase B — Tool 2, script engine
- [ ] `ScriptRunner`: Process, 5 s default timeout, 1 MB output cap
- [ ] `XbarParser`: first line is the title, `---` separator, `--` submenu,
      `key=value` params
- [ ] `JSONParser`: `{"title","image"}` as an alternative
- [ ] `Scheduler`: per-item interval, coalesce, never two processes for the
      same item at once
- [ ] `MenuBarRenderer`: one script item = one `NSStatusItem`
- [ ] 3 sample plugins: clock, cpu, git status

### Phase C — Tool 1, hide basic
- [ ] `SeparatorEngine`: length clamp `max(500, min(widest * 2, 10_000))`
- [ ] Computed from `NSScreen.screens.map(\.frame.width).max()`, not
      `NSScreen.main`
- [ ] Re-apply on `didChangeScreenParametersNotification`
- [ ] Click/hover/scroll reveal + timer auto-rehide
- [ ] Manual spacers, clamp `8...300`, saved per profile

### Phase D — Tool 3, notch
- [ ] `NotchGeometry`: width `frame.width - auxiliaryTopLeft.width - auxiliaryTopRight.width + 4`, height `safeAreaInsets.top`, fallback 37 pt
- [ ] `NotchPanel`: `.mainMenu + 3`, `canBecomeKey = false`,
      `.fullScreenAuxiliary + .stationary + .canJoinAllSpaces + .ignoresCycle`
- [ ] State is `closed` / `open` only
- [ ] Notch click → open, outside click → close (global monitor, not window
      click)
- [ ] `NotchTrayModel`: items that don't fit right of the notch go to the
      tray, not gone
- [ ] Notch tab: picker position, height, whether tray mirrors to Touch Bar

### Phase E — Tool 1, hide full
- [ ] `WindowList`: `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)`, filter `kCGWindowLayer == 25`
- [ ] `ItemMover`: CGEvent cmd-drag, `windowID` field `0x33`, neutral cursor
      `(20_000, 20_000)`
- [ ] Verify: wait for frame change, timeout 50 ms
- [ ] Fallback mouseUp to original position on drag failure
- [ ] Three sections + always-hidden

### Phase F — Tool 4, Touch Bar
- [ ] `TouchBarPresenter`: `NSTouchBar.presentSystemModalTouchBar`
- [ ] `TouchBarItemFactory`: staticButton, shellScript, appleScript, group
- [ ] `AppBlacklist`: observer `didActivateApplicationNotification`, release
      takeover when a blacklisted app fronts
- [ ] 1-3 finger swipe between pages
- [ ] Touch Bar tab hidden absent device

### Phase G — release
- [ ] Final icon (plan 02)
- [ ] 3-screen onboarding: permission mode, plugin choice, notch choice
- [ ] Sparkle appcast
- [ ] Notarize + DMG
- [ ] Homebrew cask

---

## 8. Known limits

- **Touch Bar is sunsetting.** Only MacBook Pro 13". Still eligible for
  macOS 26: 13" M1 2020, 13" M2 2022, 13" 2020 four-port, 16" 2019. No new
  models after that. Build it as a removable module (Phase F can be abandoned
  without touching other phases).
- **Notch only on main display** if using Thaw-style overflow budget. For v1
  limit to main display. Expand later.
- **Basic mode can't click hidden items.** That's a physical limit of the
  separator trick. Don't promise it in the UI.

---

## 9. Still-open decisions

1. Product name (plan 02 §1)
2. Fork Thaw vs write from scratch → plan 03 chooses **from scratch**, with
   reasons.
3. App Store or direct-only → affects Phase E (private API) and Phase F
   (AX automation).
