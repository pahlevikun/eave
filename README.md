# Eave

<p align="center"><img src=".github/header.png" width="760" alt="eave"></p>

A menu bar manager for macOS. It hides icons, runs scripts, and puts the notch to work.

**Status:** early. `EaveCore` is tested. There is no app yet.

## The four tools

**Hide.** Squeeze all icons left of a separator off-screen. Two permission tiers: a basic tier that needs no permissions at all, and a full tier that needs Accessibility to move individual icons.

**Script.** Runs existing xbar plugins, unchanged. A plugin prints a line, Eave turns it into a menu bar item. The refresh interval comes from the filename (`clock.5s.sh`). MTMR's JSON output (`{"title":"..."}`) works too.

**Notch.** Notched Macs run out of menu bar space the moment you have a few icons. Eave puts the overflow in a panel below the notch instead of dumping it in a hidden section.

**Touch Bar.** Takes over the entire bar with your items. Lets go when a blacklisted app is in front, because Xcode carries its own Touch Bar.

One script engine under all four. Write a plugin once. It renders in the menu bar, in the notch tray, and on the Touch Bar.

## Try it

```sh
git clone https://github.com/pahlevikun/eave
cd eave
swift test        # 35 tests, about 0.6 s, runs on macOS and Linux
```

## Layout

```
Sources/EaveCore/       models, parsers, runner, geometry
Tests/EaveCoreTests/    35 tests
```

`EaveCore` holds no AppKit code, by rule. Everything that touches the screen will live in `EaveKit`, which does not exist yet. The split means the part that changes most gets tested in half a second, on any machine.

The app target will need Xcode 26 and macOS 14+, and it does not exist yet.

## Design notes

The plans (local, not in the repo) came from reading the source of seven related projects: Ice, Thaw, hidden, boring.notch, MTMR, xbar, Pock. Three findings worth knowing before you contribute:

1. **`NSStatusItem.length` caps at 10,000 pt.** The hide trick inflates one item to push the rest off-screen: widest screen times two, clamped to that cap.
2. **Menu bar items live on window layer 25.** `CGWindowListCopyWindowInfo` plus that filter enumerates them without Accessibility.
3. **Moving icons takes synthetic CGEvents, not accessibility.** A command-drag names the target window through the private event field `0x33`, starting at `(20000, 20000)` so the user's cursor never moves.

## License

Undecided, on purpose. GPL would block an App Store build later, and the separator trick does work under App Store rules. The license decision waits for the store decision.
