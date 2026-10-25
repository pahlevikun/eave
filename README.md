<p align="center">
  <img src="assets/logo-animated.svg" alt="Eave, scripts in your menu bar" width="100%" />
</p>

# <img src="assets/icon.svg" alt="" width="28" height="28" align="top" /> Eave

Eave is a native macOS menu bar app for local scripts. It reads executable scripts from `~/.eave/plugins`, runs them on their filename interval and displays their output. Settings exposes script status and diagnostics, menu bar hiding, an informational overflow list and a Settings-scoped Touch Bar presenter.

Requires macOS 14 or later and Swift 6. The application uses AppKit and has no external package dependencies.

## Run from source

```sh
swift test
xcodegen generate
open Eave.xcodeproj
```

Choose the Eave scheme and run the app. The menu bar icon opens Settings, Scripts Folder and other available app actions. The repository does not provide a signed release or distribution setup.

## Add a script

Open **Settings → Scripts → Open Scripts Folder**. Place an executable script in that folder. A filename such as `clock.5s.sh` requests a five-second interval; `weather.5m.sh` requests five minutes. Eave discovers executable non-hidden files and reports rejected registrations in Settings.

A minimal script can print a status line and a menu link:

```sh
#!/bin/sh
printf 'Ready\n---\nProject website | href=https://example.com\n'
```

Make the file executable with `chmod +x`. Only install scripts you trust; scripts run as your user. This application is not a sandbox for untrusted code.

## Current behavior

- Script output supports the implemented xbar-style text subset and a small JSON title/image payload. It is not full xbar compatibility.
- Menu children can open `href` links. Top-level rendering uses the first item's title and optional image.
- Deleted registrations are removed from app presentation. Results from retired runs are rejected.
- Basic menu bar hiding uses a separator. Accessibility enables the implemented movement path; ordinary scripts do not require it.
- Overflow is a live informational list. It does not expose every plugin action or manage unrelated apps' icons.
- Touch Bar presentation is attached to Eave Settings. It is not a global Touch Bar replacement.

`ScriptRunner` caps returned stdout/stderr and has a timeout. The cap does not bound temporary-file growth while a script runs. Runtime output bounds and descendant cleanup have a dedicated [next-development task](docs/plans/2026-10-24-polish-and-next-development.md#next-0-bound-script-output-and-child-lifetime).

## Development references

- [Architecture](ARCHITECTURE.md) explains discovery, scheduling and native ownership.
- [Design system](DESIGN.md) defines layout, theme, interaction and motion rules.
- [Audit baseline](docs/audit-baseline.md) records reproduced issues and full-read coverage before this work.
- [Verification](docs/verification.md) records checks and outstanding runtime acceptance.
- [Development plan](docs/plans/2026-10-24-polish-and-next-development.md) details manual refresh, local preferences and actionable overflow.
- [Brand kit](assets/kit/preview_sheet_lite.html) includes concepts, original marks and platform/social exports. The banner is an illustration, not an app screenshot. A [static banner](assets/logo.svg) is also available.

## License

No license has been selected in this repository.
