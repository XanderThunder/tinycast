# Tinycast (personal fork)

A native macOS menu-bar launcher: fuzzy app launcher, global and per-app hotkeys with a Hyper Key, an
inline calculator, quicklinks, custom commands, Apple Shortcuts, file and menu search, window
switching, a dictionary, system actions, window management with layouts and rooms, and a camera
preview. SwiftUI + AppKit, running as an accessory with no Dock icon (`LSUIElement`). Zero
third-party dependencies.

## Why this fork exists

This is a personal fork of [Tinycast](https://github.com/abue-ammar/tinycast), built for one Mac. These
reasons settle judgement calls:

- **Personal build**, installed only on the owner's Mac with `Scripts/install-local.sh`. Nothing is
  packaged, notarized or distributed.
- **No telemetry and no auto-updates.**
- **Zero dependence on the original developer**: no requests, links, support page or changelog that
  reach `tinycast.dev` or the upstream GitHub. The only network request is the currency fetch.
- **Only features the owner uses.** Clipboard, snippets, notes, emoji, calendar, uninstall, Raycast
  extensions, AI, MCP, quick actions, dictation, iCloud sync, deep links, updates and support were
  removed. When unsure whether something is still needed, ask rather than guess.
- **Coinbase** supplies currency rates.
- **Camera stays**: a mirror-style preview, no calendar.
- **Window management stays**, and is meant to replace Rectangle Pro.
- **English only.**
- **One commit per removal**, and upstream changes arrive only by cherry-pick from the
  `upstream-base`/`upstream-reviewed` tags, never a merge ([upstream.md](docs/upstream.md)).

## Posture: modern-first, always

**Tinycast supports macOS 26 and later, with macOS 27 strongly preferred.** Swift 6+ with complete
strict concurrency is required. Prefer the latest Swift patterns and modern Apple APIs.

Prefer current APIs and language features:

- **Prefer the modern Apple API**, always. Observation over `ObservableObject`. `SMAppService` over
  login-item shims.
- **Prefer synchronous code.** Keep short UI and state operations synchronous on `@MainActor`.
  Introduce concurrency only for genuinely asynchronous operations or blocking work that must leave
  the main actor. Shared state alone does not justify `async`, a `Task`, or an actor. Preserve
  synchronous callback returns and event ordering. When concurrency is needed, prefer structured
  concurrency with clear ownership and cancellation. Strict concurrency checking enforces safety;
  it does not require making operations asynchronous.
- **Migrate, never wrap.** Adopt modern replacements directly and delete obsolete call sites. Do not
  keep wrappers that only preserve an old spelling.
- **A deprecated API is a defect**, not a warning to live with.
- **Verify API and language-feature availability** against the SDK and compiler used by the build
  and CI. Use direct availability checks where macOS 27+ APIs require them to preserve macOS 26 support.
- **No compatibility layers, legacy workarounds or obsolete patterns.** No support below macOS 26 or
  speculative fallbacks. Keep the implementation direct. Migration code lives only in
  `Tinycast/Migrations/` and is deleted after one stable release ([migrations.md](docs/migrations.md)).

Carbon is a deliberate capability-gap dependency rather than inertia: nothing modern registers a
system-wide chord, and HIToolbox's TIS APIs remain the public input-source mechanism. Full reasoning in
[standards.md](docs/standards.md#posture).

## Where things are

| Folder                   | Holds                                                                                   |
| ------------------------ | --------------------------------------------------------------------------------------- |
| `Tinycast/App/`          | `@main`, `AppDelegate`, `AppCore` (the composition root)                                |
| `Tinycast/DesignSystem/` | shared visual primitives; `Theme.swift` is the only design-token source                 |
| `Tinycast/Platform/`     | system shims: `Permissions`, `AppPaths`, `Signposts`, `NotificationToken`, …            |
| `Tinycast/Palette/`      | the palette shell: panel, window controller, `RootPaletteView`, `PaletteScreen`         |
| `Tinycast/Windows/`      | the non-palette AppKit surfaces: `Dialog/`, `HUD/`, `About/`, `AppWindowController`     |
| `Tinycast/Features/`     | one folder per feature; larger ones split `Model/` `Service/` `UI/` `Settings/`         |
| `Tinycast/Migrations/`   | one-shot repairs of state an older release left behind, each deleted after one release  |
| `Tests/`                 | the standalone harnesses: one Swift file each, no XCTest target                         |
| `Scripts/`               | every executable script: test runner, data generators, install, linting, editor setup   |

| Read it before you                                         | Doc                                                          |
| ---------------------------------------------------------- | ------------------------------------------------------------ |
| change how anything is wired or owned                      | [architecture.md](docs/architecture.md)                      |
| write Swift: naming, style, concurrency, budgets, comments | [standards.md](docs/standards.md)                            |
| claim a change is done                                     | [testing.md](docs/testing.md)                                |
| build, run or regenerate data                              | [development.md](docs/development.md)                        |
| add or restyle any view                                    | [ui.md](docs/ui.md)                                          |
| touch one feature's internals                              | [features/](docs/features/) (each opens with its invariants) |
| remove or rename anything persisted                        | [migrations.md](docs/migrations.md)                          |
| install a build, or touch signing                          | [signing.md](docs/signing.md)                                |
| bring in an upstream change                                | [upstream.md](docs/upstream.md)                              |

## Non-negotiables

Never break these without an explicit task to do so. Anything feature-specific lives in that
feature's doc, under its own `## Invariants`.

- **`AppCore` is the sole owner.** New long-lived state goes on `AppCore`, wired in `start()`, never a
  competing singleton. Views reach a feature's **coordinator** through `@Environment`, not `AppCore`.
- **A file under `Features/*/Model/` may not import AppKit or SwiftUI**, and takes every environment
  fact (clock, filesystem, home directory, rates) as an injected parameter. The harnesses compile the
  shipped sources, so this is enforced by compilation rather than convention.
- **Swift 6 language mode: data-race violations are hard errors.** `@MainActor` is the default,
  model values shared across isolation boundaries are `Sendable`, and exclusive ownership transfer
  uses `sending`. Heavy or IO-bound work goes off-main. Prefer `@concurrent` async functions when work
  must leave the caller's actor; use `Task.detached` when an independent task is needed. Do not add a
  second actor.
- **Async results can become stale across suspension.** Before applying them, validate cancellation,
  operation identity and destination where they can change. Long-lived work has an owner and teardown;
  detached or callback-backed work owned by a caller follows that caller's cancellation.
- **Dark is the baseline, and a colour's dark branch is the literal it always was.** `Theme.Colors`
  resolves per appearance through `ramp`/`adaptive`; every dark value is the `Color.white.opacity(…)`
  the forced-dark build shipped, restated rather than re-derived. Retune a light branch freely; change
  a dark one only when the task is to change Dark. `AppAppearance` drives `NSApp.appearance`, and
  `.system` maps to `nil` so AppKit follows macOS on its own.
- **Tinycast presents its own dialogs, never `NSAlert` or a system popover.** A question
  goes through `DialogController`, a report through a HUD via `HUDPresenter`. The Settings window is
  the one exception: a stock titled window, its panes ask with SwiftUI's `confirmationDialog` or
  `alert`, which present as a sheet on it.
- **A networked feature fetches on a private `.ephemeral`, `urlCache = nil` session**, never
  `URLSession.shared`, so its own cache file stays the only copy on disk. `CurrencyRateStore` is the
  reference: copy it rather than inventing a second shape. A flag that grants a capability is never
  carried by a backup or by `settings.json`: `settingsFileEnabled` is excluded from settings backups
  so an import cannot let a file change another Mac's settings.
- **`AppEntry.Kind` is the only thing that says what an entry is.** One case per launcher section and
  per `VisibilityStore` category; never re-derive a category by sniffing an entry ID. Which _pane_
  lists a command is a separate fact, and `SettingsTab.ownedCommands` is the only place that states it.
- **Generated files are never hand-edited.** `CurrencyData.generated.swift` comes from
  `node Scripts/gen-currencies.js` and `CountryZoneData.generated.swift` from
  `node Scripts/gen-countries.js`; both are committed so building the app never needs Node.
- **`DesignSystem/Scrolling/EdgeDissolve.swift` and `ThinScrollbar.swift` are off-limits.** Both are
  tuned by eye against the palette's floating bars, so any edit is a visual regression. Needing to touch
  one to fix a scroll bug means the real fix belongs elsewhere.

## Conventions worth knowing up front

- **User-facing text goes through `Localizable.xcstrings`, English only**: SwiftUI literals as they
  are, `String(localized:)` wherever text travels as a `String`, one literal per sentence. Run
  `./Scripts/sync-strings.sh` after changing any; it adds new keys and prunes stale ones. No
  translations. See [standards.md](docs/standards.md#localization).
- **Every symbol icon comes from the icon pack.** Settings tabs, system actions and built-in commands
  pair an SF Symbol with an `IconTint` in their catalog; a user-made item keeps its symbol and takes its
  feature tab's tint. All draw as `IconTile`. To add one, follow
  [ui.md#adding-an-icon](docs/ui.md#adding-an-icon), which includes updating the artifact.
- **A new preference also gets a `SettingsFileKey`** and its binding in `SettingsFileSchema`, so the
  opt-in `settings.json` mirror carries it; the exhaustive switch fails the build until it is bound.
  See [settings-file.md](docs/features/settings-file.md).
- **A type's suffix says what it _is_**: `Store`, `Coordinator`, `Controller`, `Manager`, `Engine`,
  `Policy` and the rest each name a specific responsibility. **Semantic correctness always wins over
  suffix consistency:** pick the suffix that describes the type honestly, add a new one when none fits,
  and never rename a well-named type just to match the table.
  Full table: [standards.md#naming](docs/standards.md#naming).
- **Comments are rare, one line, and explain the _why_**: the gotcha or invariant, never the what.
  **Never two in a row, never extended into a block**: if one line can't carry it, name a function,
  constant or type instead. Cap 100 characters, delete rather than update, and never comment a change
  you just made. Nothing lints this; get it right the first time.
  Full rules: [standards.md#comments](docs/standards.md#comments).
- **Debug builds are their own channel** (`Tinycast Dev.app` / `com.xanderthunder.tinycast.dev`), so a
  local run never shares prefs, caches, TCC grants or the login item with an installed copy. Anything
  newly persisted must stay keyed by `Bundle.main.bundleIdentifier`.
- **XcodeGen owns the project.** `Tinycast.xcodeproj` is committed but generated from `project.yml`;
  after editing it, run `xcodegen generate` and commit both. No SwiftPM, and never `Bundle.module`.

## Before you finish

Each item is explained in [testing.md](docs/testing.md#definition-of-done).

- `./Scripts/run-tests.sh` passes.
- The Debug build compiles with **no new warnings**.
- `./Scripts/lint.sh` is clean.
- `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Tinycast/Features/*/Model/` returns nothing.
- Any doc your change made wrong is fixed in the same commit.
