<h1 align="center">
  <img src="docs/images/icon.png" alt="Tinycast app icon" width="128" height="128"><br>
  Tinycast (personal fork)
</h1>

A personal build of Tinycast by Abue Ammar, the native macOS menu-bar launcher, trimmed to the
features its owner uses and cut off from the original developer's services.
It is built and installed on one Mac only; nobody else receives it.

SwiftUI + AppKit, Swift 6, macOS 26 or later (macOS 27 preferred). No third-party dependencies, no
telemetry, no auto-updates.

## What it does

- **Launcher**: fuzzy search over apps, System Settings panes, commands and everything below, with
  favorites, aliases, suggestions and fallbacks.
- **Hotkeys and Hyper Key**: global and per-app shortcuts, double-tap modifiers, a remapped Hyper key.
- **Calculator**: arithmetic, units, dates, time zones and currencies (rates from Coinbase's public API).
- **Quicklinks**, **Custom Commands** and **Apple Shortcuts**.
- **File Search**, **Menu Search**, **Switch Windows** and **Dictionary**.
- **System Actions**: volume, microphone mute, Bluetooth, sleep, lock and the rest.
- **Window management**: snapping commands, custom sizes, layouts and rooms.
- **Camera**: a mirror-style preview window (Open Camera).
- **Backup** and import, the opt-in `settings.json` mirror, and import from a Raycast `.rayconfig`.

## What this fork removed

Clipboard history, snippets, notes, emoji picker, calendar, uninstaller, Raycast extensions, AI chat and
Quick Actions, MCP, dictation, iCloud sync, deep links, auto-updates, the donation reminder, the website,
CI and release tooling, and every translation except English.

The only network request the app makes is the daily exchange-rate fetch from
`api.coinbase.com`. It never contacts `tinycast.dev` or the upstream GitHub repository.

## Build and install

```sh
./Scripts/install-local.sh
```

It builds Release, signs with the local `Tinycast Self-Signed` identity (see
[docs/signing.md](docs/signing.md)), verifies the signature, copies the app to
`/Applications/Tinycast.app` and relaunches it. For the day-to-day loop (Debug builds, tests, lint),
see [docs/development.md](docs/development.md) and [docs/testing.md](docs/testing.md).

## Upstream

Upstream changes are reviewed and cherry-picked one at a time, never merged; the workflow is in
[docs/upstream.md](docs/upstream.md). The `upstream-base` tag marks the upstream commit this fork
started from.

## License

Tinycast is licensed under the [AGPL-3.0 license](LICENSE), © 2026 Abue Ammar. Third-party notices are
in [NOTICE.md](NOTICE.md).
