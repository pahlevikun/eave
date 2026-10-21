# Eave

A macOS menu bar utility. Four tools, one engine.

- **Hide** — declutter menu bar icons, two permission tiers
- **Script** — run xbar/MTMR plugins in the menu bar
- **Notch** — the notch as a surface, not just a hole
- **Touch Bar** — take over the entire bar

Status: foundation. `EaveCore` exists and is tested. `EaveKit` and the app
target do not.

## Build

```sh
swift test        # 35 tests, runs on macOS and Linux
```

The app target needs Xcode 26 and macOS 14+. The library doesn't.

## Shape

```
Sources/EaveCore/       models, parsers, runner, geometry — no AppKit
Tests/EaveCoreTests/    35 tests
docs/plans/             plans: one app, icons, from scratch
```

Rule: `EaveCore` may not `import AppKit`. Anything that touches UI lives in
`EaveKit`. Not for tidiness — so the part that changes most can be tested in
0.5 s without Xcode.

## License

Not decided yet. If the App Store is on the table, GPL closes that door.
