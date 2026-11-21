# Testing and verification

How to check that a change holds up. Tinycast has no XCTest target and no UI tests: the automated half
is a set of standalone harnesses, and the manual half is the sweep at the bottom of this file.

## Definition of done

The mechanical bar, in one place so it cannot drift. All five pass before a change is finished.

| Check                                              | Command                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------------------ |
| The harnesses                                      | `./Scripts/run-tests.sh`                                                             |
| Lint, settings search and migrations               | `./Scripts/lint.sh`                                                                  |
| Pure-layer purity                                  | `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Tinycast/Features/*/Model/` |
| A clean build                                      | `xcodebuild … -configuration Debug CODE_SIGNING_ALLOWED=NO`, zero **new** warnings   |
| Docs still true                                    | any doc your change made wrong, fixed in the same commit                             |

There is no CI: every item is on you, run locally. Each is expanded below; the manual sweep at the
end of this file is the sixth, judged by what you touched.

## The harnesses

```sh
./Scripts/run-tests.sh              # all of them
./Scripts/run-tests.sh CalcTests    # just one, while iterating
```

The suite runs four harnesses at a time by default to reduce CPU usage. `TINYCAST_TEST_JOBS` overrides
that limit; `TINYCAST_TEST_JOBS=1` runs one at a time. Each result is numbered
against the total and shows its run and compile time, a quiet stretch names the harnesses still running, and a harness that runs longer
than `TINYCAST_TEST_TIMEOUT` seconds (default 300) is killed and reported as timed out. Parallelism is safe
because each harness already roots its scratch state somewhere of its own (a UUID-suffixed
`temporaryDirectory`, a `UserDefaults(suiteName:)`, or `NSPasteboard.withUniqueName()`), and a new
harness must keep doing that rather than reach for a fixed path. The runner's own queue, logs and
verdicts do live at a fixed path, so a second suite started in the same `$TMPDIR` waits for the first,
and a run that reports fewer results than it queued fails rather than passing.

Two consequences worth knowing. Status lines arrive in **completion order**, not the order the `run`
lines are written; and a failing harness's compiler diagnostics or assertion output are replayed
together at the bottom, under its name, rather than streamed where they happened. That is deliberate:
a compiler diagnostic is far longer than `PIPE_BUF`, so eleven workers streaming at once would
interleave into nonsense.

A `run` line takes optional markers before the harness name. `-O` compiles that harness optimised,
which is worth it only where the run dominates the compile: `RaycastTests` spends 47 seconds in
scrypt at `-Onone` and one second at `-O`. `slow` dispatches it in the first wave, so the longest
harnesses are not still running after everything else has finished.

The script is the **only** place the harness set is written down. Nothing runs it for you, so run it
before you open a PR. Adding a harness means adding one `run` line.

A harness is `Tests/<Subject>Tests.swift`, and its `@main` type has the same name, which is also what
`run` and `./Scripts/run-tests.sh` call it. A benchmark is `<Subject>PerformanceTests`, stubs shared
by harnesses are `<Subject>Fixtures`, and a file that extends another harness is `<Harness>+<Topic>`.

Each harness compiles the **shipped sources** it guards rather than a copy of them, which is what makes
the pure-layer boundary real: a harness that stops _compiling_ means AppKit or SwiftUI has leaked into a
`Model/` folder, or an effect has leaked into a decision. That is a more common failure than a broken
assertion, and it is the more important one.

A harness also runs in your own login session against the real system, with no sandbox and no fixture
world, so it must never mutate state the machine shares with the apps you use. `NSPasteboard.general`
is the trap: another app's clipboard history records every write to it as a genuine copy. Anything
that writes a pasteboard takes the board as a parameter (`TextInjector.copySelection(from:pasteboard:)`
is the shape), so a harness passes `NSPasteboard.withUniqueName()` instead.

Never join a compile to its run with `&&` in a `set -e` script. `set -e` is specified to ignore a
failing command in a non-final AND-OR list member, so `swiftc … && /tmp/x` swallows a compile error and
the script sails on. CI reported success over a harness that had not compiled for twenty-five phases
because of exactly this; `run-tests.sh` keeps the two steps separate and records both kinds of failure.

### What to run when

If a change touches anything in the right column, the harness on the left is mandatory.

| Harness                     | Guards                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FuzzTests`                 | `Launcher/Model/LauncherMatch.swift`, `LauncherOrder.swift`, `LauncherSuggestions.swift`, `EntryNaming.swift`, `ScriptRomanization.swift`, `SearchRelevance.swift`, `LauncherRankingStore.swift`: **a new ranking complaint is a new case in its `denseIndex`**                                                                                                                                                                                                                                                                                                                              |
| `FileSearchTests`           | `FileSearch/Model/`: folding, masks, scoring, ignore rules, priors, scopes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `FileIndexTests`            | `FileIndexCrawler`, `FileIndexSnapshot`, `FileIndex`: a real fixture crawled, written, mapped, searched and live-updated                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `FileSearchSessionTests`    | serialized query execution, coalescing, cancellation and refresh                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `MenuSearchTests`           | `MenuSearch/Model/` decisions, `MenuSearch/Service/` session filtering, the shared `FuzzyMatch` scorer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `ActionMenuSearchTests`     | Action-menu query normalization and shared fuzzy matching                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `AppInstallationTests`      | Multiple app copies and app-wide preferences; file-favorite persistence, mixed ordering, hidden slots and restoration through the existing favorite key list                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `RankingTests`              | `Launcher/Model/LauncherRankingStore.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `ScopesTests`               | `Launcher/Model/SearchScopes.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `AppNameTests`              | `Platform/AppDisplayName.swift`: every path that names a scanned bundle                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `LocalizedResourceTests`    | `Platform/LocalizedResource.swift`: `resolved()` matches `String(localized:)` in English, for plain, contextual, interpolated, plural and missing keys                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `CalcTests`                 | all of `Calculator/Model/`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `CommandEscapeTapTests`     | `Palette/CommandEscapeTap.swift`: dedicated run-loop dispatch while main is blocked, timeout recovery, stale actions, installation cancellation and teardown; private ports and unposted events only                                                                                                                                                                                                                                                                                                                                                                                         |
| `PaletteNavigationTests`    | `Palette/PaletteState.swift`'s screen motions (`prepare`, `replace`, `push`, `pop`) and hover arming, pointer drift, scroll disarming and highlight tokens                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `CompactBarTests`           | Compact shortcut order, selection boundaries, zero-to-four slots, identifiers, isolated preferences and invalid settings-file rejection                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `InterfaceSizeTests`        | `DesignSystem/InterfaceMetrics.swift`, `Features/Settings/InterfaceSize.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `FormInputTests`            | Native field/textarea sizing, editing alignment, placeholders, Tab, Unicode selection, undo and code fonts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `PalettePlacementTests`     | `DesignSystem/Theme.swift`, `Palette/PalettePlacement.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `PaletteMenuClickTests`     | `Palette/PalettePanel.swift`: complete click-away presses and subsequent control activation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `HyperKeyEngineTests`       | Hyper chord transitions for every physical key, device-bit holds, own-bit and other-Shift residue, released modifiers, the Quick Press rule, repeats and interruption recovery                                                                                                                                                                                                                                                                                                                                                                                                               |
| `HotKeyTests`               | `HotKeys/Model/DoubleTapModifier.swift`, `DoubleTapDetector.swift`, `ModifierKey.swift`, `ModifierKeyDetector.swift`, `HotKeyBinding.swift`, `HotKeySpelling.swift`, `HyperKey.swift`, `HIDKeyMapping.swift`, `HotKeyAction.swift`, `Service/KeyShortcut.swift`, and the command→action mapping in `Launcher/Model/CommandID.swift`                                                                                                                                                                                                                                                          |
| `HyperKeyTests`             | `HotKeys/Model/HIDKeyMapping.swift`, `HyperKeyConflictPolicy.swift`, `Service/KeyboardRemapper.swift`, `RemapInstanceLock.swift`: mapping ownership, refused writes, crash recovery, device reconnection, conflict severities, Modifier Keys and Karabiner parsing, another app taking over Caps Lock, one process per Hyper Key                                                                                                                                                                                                                                                            |
| `HotKeyDispatchTests`       | `HotKeys/Service/HotKeyManager.swift`: Secure Input side isolation, shared Control registrations, press/release routing, recording and cancellation; isolated preferences and simulated Carbon registration                                                                                                                                                                                                                                                                                                                                                                                  |
| `FallbackTests`             | `Launcher/Model/Fallback.swift`, plus the `CommandID` and `Quicklink` ids it is built from                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `DictionaryTests`           | `Dictionary/Model/DictionaryEntry.swift`, `DictionaryMarkup.swift`: a real XHTML record and the plain-text fallback, read into page blocks                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `CalloutTests`              | `DesignSystem/Theme.swift`, `HotKeys/UI/CalloutPlacement.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `SystemActionTests`         | `SystemActions/Model/SystemAction.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `MicrophoneMuteTests`       | Native input mute, delayed confirmation, device switches and failures; injected CoreAudio calls only                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `VolumeTests`               | `SystemActions/Model/VolumeLevel.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `WindowCommandTests`        | `WindowManagement/WindowCommand.swift`, `WindowPlacementEngine.swift`, `WindowActionMemory.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `WindowLayoutTests`         | `WindowManagement/Model/WindowLayout*.swift` and `CustomWindowSize*.swift`: the layout record, its geometry and its inverse, the plan and the store; custom sizes' units, frames and store                                                                                                                                                                                                                                                                                                                                                                                                   |
| `WindowRoomTests`           | `WindowManagement/Model/Room*.swift`: every room layout and its minimum sizes, the grid, arrangement reading, window matching, parking, the plan, Tab's choices and the three stores                                                                                                                                                                                                                                                                                                                                                                                                         |
| `CustomCommandTests`        | Command storage and execution, editor drafts, argument identities and dynamic keyboard focus                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `CustomCommandListTests`    | Browser result snapshots, observation, row actions and empty-library messages                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `QuicklinkTests`            | all of `Quicklinks/Model/`, plus editor drafts and placeholder selection                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `QuicklinkCoordinatorTests` | Opening and requested arguments, launcher editing, current enabled-state preservation, deletion during editing and feature gates; no platform effects or on-screen focus checks                                                                                                                                                                                                                                                                                                                                                                                                              |
| `AppleShortcutTests`        | all of `AppleShortcuts/Model/`: the `shortcuts list` parser and entry ids                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `RaycastTests`              | `Backup/Service/RaycastDecoder.swift`, `Scrypt.swift`, `Platform/Compression/Zlib.swift`                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `IconCacheTests`            | `Platform/Images/IconCache.swift`: row sizing at 1×/2×, warm reuse, stamp and style invalidation, bitmap release, fitted geometry across all 256 alpha values, and that a row icon draws identically to the 96px one                                                                                                                                                                                                                                                                                                                                                                         |
| `EntryIconTests`            | `EntryIcon`: that each case draws, caches and prints apart from the others, and that a moved `FileIconStamp` retires the bitmap decoded before it                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `SettingsBackupTests`       | `Settings/AppSettingsKey.swift`, `Backup/Model/SettingsBackupCoverage.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `SettingsFileTests`         | `Settings/Model/` and `Settings/Service/`: key paths, value tokens, the printer and parser, and the repository's import, replace, save, reload and symlink handling on a scratch folder                                                                                                                                                                                                                                                                                                                                                                                                      |
| `WindowFileTests`           | `WindowManagement/Model/WindowManagementFileFormat.swift`: command shortcuts, custom sizes, layouts and rooms as settings.json spells them, hand edits and bad records                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `LauncherSettingsFileTests` | Launcher settings application: invalid records, partial edits, deferred bundles, shortcut moves and records outside search scopes; isolated preferences and in-memory scan/Carbon effects                                                                                                                                                                                                                                                                                                                                                                                                    |
| `BackupArchiveTests`        | all of `Backup/Model/`, plus `Backup/Service/BackupStaging.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

A harness that passed before a change passes after it. There is no "I'll fix it next commit" and no
commenting out a case. If a change genuinely invalidates an assertion, the assertion is rewritten in the
same commit with the reason in the message.

### Purity checks

The layering rule reduces to one grep, and it must return nothing:

```sh
grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Tinycast/Features/*/Model/
```

Beyond the imports, the injected-environment half is not mechanically checkable, so it is worth an eye
when touching a pure file:

- `Calculator/Model/` still takes its clock via `now`/`calendar`, its rates via `rates` and its
  separators via `format`
- `HotKeys/Model/DoubleTap*` still take the clock as a parameter
- `WindowManagement/Model/` still touches no `NSScreen` and makes no AX call, layouts included
- `Quicklinks/Model/` is still handed the home directory rather than reading it
- `FileSearch/Model/` is still handed the home directory rather than reading it

## Build and size checks

A clean build is part of the bar; nothing builds the app for you, so this is on you.

```sh
xcodegen generate                 # only after editing project.yml
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
  CODE_SIGNING_ALLOWED=NO
find ~/Library/Developer/Xcode/DerivedData -name "Tinycast*.app" -maxdepth 6 -print -quit
```

- Zero **new** warnings. Pre-existing ones are not your problem; new ones are.
- No `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated` added without a stated reason.
- The type-checker did not time out. `LauncherList.rows` already carries an explicit annotation for
  this reason; the fix for a timeout is an annotation, not a restructure.
- Release binary growth under **2%** for an ordinary change.

### Lint

```sh
./Scripts/lint.sh
```

SwiftLint owns the rules that catch defects, including the two checkable comment rules: the
100-character cap and the ban on stacked comment lines. Errors block; warnings do not. There is no
formatter, deliberately; the configuration and the measurements behind that are in
[development.md](development.md#formatting).

The script then runs `Scripts/check-settings-search.js`, one check SwiftLint can't: every
`SettingsAnchor` must be claimed by a section, and every row in `SettingsSearchCatalog` must be
marked by a `SettingsRowTitle`. Either gap compiles and reads fine, and fails only at runtime as a
search result that navigates and then sits there.

Last, `Scripts/check-migrations.sh` fails once a stable release has shipped a migration, which is the
cue to delete it. See [migrations.md](migrations.md).

## Performance measurement

`Platform/Signposts.swift` emits five intervals on the `com.tinycast.perf` subsystem: `AppCore.start`,
`AppIndex.scan`, `AppIndex.rank`, `PaletteWindowController.show` and `FileIndexer.update`. Open the Time Profiler or
`os_signpost` instrument in Instruments and filter to that subsystem; nothing needs recompiling.

None of the benchmarks below join the suite, so each is registered in `run-tests.sh` as `run index`
instead: `--index` hands it editor flags without queueing it, and without that entry nothing in the
file resolves. Keep the entry's source list matching the command beside it.

Run the file-index benchmark separately from the deterministic harnesses. With no arguments it crawls
`/System /Applications /Library /usr`, which never raise a privacy prompt; pass other roots to measure
them:

```sh
swiftc -O -wmo -swift-version 6 Tinycast/Features/FileSearch/Model/*.swift \
    Tinycast/Features/FileSearch/Service/FileIndex.swift \
    Tinycast/Features/FileSearch/Service/FileIndexSnapshot.swift \
    Tinycast/Features/FileSearch/Service/FileIndexCrawler.swift \
    Tests/FileSearchPerformanceTests.swift -o /tmp/FileSearchPerformanceTests
/tmp/FileSearchPerformanceTests
```

It prints the crawl and write times, the index size, and first and median latency per query.

The calculator benchmark is deterministic (an injected clock, calendar and rate table), so it is a
timing harness rather than an assertion one, and stays out of `run-tests.sh` for that reason:

```sh
swiftc -O -swift-version 6 Tinycast/Features/Calculator/Model/*.swift \
    Tests/CalcPerformanceTests.swift -o /tmp/CalcPerformanceTests
/tmp/CalcPerformanceTests          # µs per query, by grammar
/tmp/CalcPerformanceTests --probe  # every answer as JSON, to diff two builds
/tmp/CalcPerformanceTests --cold "10kg to lb"   # first query, including catalog decode
```

`Signposts.interval` owns an explicit `defer` around the wrapped work on purpose. The obvious spelling
leaks the interval when the work throws, because the `.end` emit is skipped on the throw path and the
instrument then shows an interval that never closes.

Measure before optimising, and measure the same way twice. For cold launch: quit fully, relaunch, time
it three times, take the median.

### Recorded baselines

Measured upstream at the end of the 2026 refactor, before this fork removed features. Useful as orders
of magnitude, not as contracts.

|                                           | Value                                                                                                                                                                |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Release binary                            | 3,655,736 B (from 3,471,592 B at the start of the refactor)                                                                                                          |
| Resident memory                           | 40–80 MB in normal use; the hard ceiling is 100 MB                                                                                                                   |
| `SettingsPaneScanner` warm scan           | 0.014 ms (16.5 ms cold), 52 panes                                                                                                                                    |
| Largest view / owner                      | `RootPaletteView` 662 lines, `AppCore` 284 lines                                                                                                                     |
| Comment density                           | 1,653 of 27,289 source lines (6.1%)                                                                                                                                  |
| The harness suite                         | ~15 s wall clock, 11-way parallel (~98 s serial, ~140 s before either)                                                                                               |
| `count items of trash`                    | 5,000 ms against a cold Finder on an _empty_ Trash, 110 ms warm: why AppleScript is detached                                                                         |

Launch time, allocation counts and RSS have never been captured as numbers. The signposts are in place,
so any of them can be taken from `main` whenever a change makes it worth knowing.

## Manual regression sweep

There is no UI test suite, so this is it. Run the core sweep for any change that touches the palette;
run the scoped section for whatever feature you touched. Budget about five minutes plus three per
section.

Run against the **Debug channel** (`Tinycast Dev.app`, `com.xanderthunder.tinycast.dev`). It has its own
prefs, caches, TCC grants and login item, so this cannot disturb an installed copy.

### Core

- Palette hotkey opens the launcher; pressing it again closes it; Escape clears a non-empty query,
  then hides on a second press; clicking away closes it
- Search a mode command (Search Quicklinks, Search Files, Calculator History)
  and run it: Escape returns to the launcher **with the query still typed and the row still
  selected**, and the next press clears it. The same screen from its own global hotkey hides the
  palette instead, and shows its own header icon rather than a back chevron
- ⌘esc from any depth lands on an empty root search with the window still open; **must be checked
  on a real keyboard**: macOS claims the chord, so `CommandEscapeTap` is the only thing that
  delivers it and it needs Accessibility granted to the running build. With the palette closed, ⌘esc
  still does whatever macOS does with it. Open a menu or dialog over the palette and verify ⌘esc
  passes through while the palette is not key; after dismissing it, the palette chord works again
- A bare ⌫ in an empty field walks the same path Escape does
- General ▸ Escape Key Behavior set to `Close window and pop to root`: Escape on sub-screens closes
  the window, and reopening lands on the root search whatever Pop to Root Search says
- Reopening focuses the search field with an empty query, in the same position and at the same size
- Compact mode: typing expands it, and the search bar does **not** shift vertically during the swap
- Compact mode: the opening frames show no shortcut fill beneath the query before the buttons emerge
- Compact mode: configure zero, one or both shortcuts (Search Files, Search Quicklinks), replace/remove them and move them up/down;
  disabling a feature hides its button without losing its configured position, and Settings marks
  it Off in the list and lists it under Off in both menus
- Compact mode: Left/Right traverses Search and the visible buttons without wrapping; Down expands
  Search or opens a selected shortcut, Return opens only a shortcut, and typing/pasting starts Search
- Compact mode: Escape at expanded root clears text, then collapses, then closes under both preferences
- Compact mode: a round button per enabled configured shortcut; the
  capsule fills the rest, the whole width with none on. Each summon and each cleared query buds them out
  of the capsule's end, the last one never clipped at the window's edge; with Show animations off they
  appear in place. Mouse and keyboard activation open the command immediately, without a fuse,
  delayed reveal or shortcut shapes beneath the expanded panel
- Compact mode: arrow navigation tints the selected glass circle and uses a white monochrome glyph;
  inspect its native contour at actual size in both appearances, without a second fill or stroke;
  the left capsule and rightmost button must remain whole through opening, hovering, and selection,
  and expanding/collapsing after a drag must preserve the visible bar’s top-left position
- Verify compact selection in the live glass compositor in both appearances; an offscreen view bitmap
  omits the material and cannot prove selection contrast
- Compact Shortcuts settings: command names sit beside their icons; replacement menus and borderless
  move/remove controls work without stretching the labels across the row
- The expanded header leaves even room above the query and below it, before the first section
- With a CJK IME: the placeholder clears as soon as composition starts and the composing text never
  overlaps it; cancelling composition brings the placeholder back, and the list filters only once the
  candidate is committed; check on a second summon too, where first responder never moved
- Typing filters instantly; ↑/↓ move the highlight and scroll it into view without yanking the list
- ⌃N/⌃P move the highlight as ↓/↑ do; ⌃F/⌃B step compact shortcuts, and the caret elsewhere
- The highlight always sits on the row the footer pill describes
- With a calculation typed, the calculator card is first and is selected first
- ⌘↵ on a number, unit or money card puts the answer in the search bar with the caret after it, so
  ` * 2` typed straight away extends it (from ⌘K too); a date or time card offers neither
- With macOS set to a decimal-comma region (Italian), `2,3 + 1,5` answers `3,8`, `max(2,5; 3)`
  answers `3`, and ↵ pastes `3,8`; General ▸ Calculator ▸ Number format `English` restores `2.3 + 1.5`
  and re-renders past Calculator History in the chosen format
- Section headers appear in order: Favorites, Suggestions, Applications, System Settings, Quicklinks,
  System Actions, Window Management, Custom Commands, Commands
- With a non-ASCII input source active, ⌘K opens Actions; ↑/↓ move it, ↵ activates, Escape closes it
- In either ⌘K Actions panel, typing filters immediately in the bottom search band without changing
  the palette query; sections survive filtering, **No Results** is centred, and no dissolve covers the
  last row. The native caret blinks; mouse drag and ⌘A select text; ←/→ move through it; ↑/↓ still
  move the menu highlight. Escape clears a non-empty query, then closes the menu on the next press
- The bottom-left app menu also searches from its bottom band; every header menu (File Search
  filters, the dictionary selector) searches from its top band
- The app menu shows About, a separator, then Settings and Quit; filtering to fewer rows shrinks it
- A long menu opens with unchanged row insets; while scrolling, rows can reach the panel edges
- A click in the palette but outside its menu closes only the menu; a click outside the palette
  closes both, regardless of the menu query; the next summon accepts typing immediately
- Click the menu search field, pause, then dismiss by clicking the other footer control. The next
  click opens that control's menu once and leaves it open, including when the clicks form a double click
- Footer menus are about 30pt wider; their row hover keeps the shared 10pt menu-row corner
- Tab on a sub-screen with no fields returns to the launcher; bare Backspace on an empty query backs out
  of a sub-screen
- Launching an app focuses it; escaping the palette returns focus to the app you came from
- Paste from File Search lands in that app, not in Tinycast
- No flash, flicker or reflow on open, and row metrics unchanged

### Launcher and icons

- Every installed app appears; Settings panes appear under System Settings; running apps show the dot
- Icons render with no placeholder flash on reopen, and Settings ▸ Applications scrolls without hitching,
  even with the scrollbar thumb dragged from end to end in under a second
- An app removed since the last open drops out after a reopen
- Learned ranking still surfaces your habitual result for a short query
- An application row drags onto the Dock and into a Finder window as a copy, never a move, and a
  landed drop hides the palette; a click still launches; no other kind of row drags

### Hotkeys

- The palette, File Search and Search Quicklinks shortcuts fire; a per-app shortcut toggles that app
- Recording captures a shortcut, and the old binding does not fire while recording
- A conflicting binding is rejected and names its current owner
- A double-tap binding fires; Hyper Key remaps and its status dot is green
- Each Hyper Key choice (Caps Lock and all eight Left/Right modifiers) sends the chord.
  Quick Press is offered for Caps Lock only, with original-key and Escape actions. Hyper Key never
  requests Input Monitoring
- Plug in a second keyboard: Caps Lock is Hyper there too. Change Hyper Key to a modifier while
  disconnected, then reconnect: Caps Lock works normally again
- An unused Escape action still fires after a long hold; Caps Lock ignores very brief accidental
  presses while off, yet any press turns it off. A combo never triggers Quick Press. With Caps Lock
  input-source switching on, a short press switches sources only while Caps Lock is off
- Right Command as Hyper with Left Command held keeps the chord; Left Shift as Hyper with Include
  Shift off sends ⌃⌥⇧⌘K when Right Shift is held with K
- Run Tinycast Dev next to Tinycast: the second reads Blocked and names the first; quitting the
  first hands the Hyper Key over without a relaunch
- Revoke Accessibility while Hyper is live: the key goes back to normal. Grant it again: Hyper
  returns within a couple of seconds without a relaunch
- Lock the screen: Caps Lock types capitals in the password field; unlocking restores Hyper. Sleep
  and wake do the same
- With Raycast running, Diagnostics… lists it as a warning and Hyper keeps working. Turn on Raycast's
  Hyper Key on Caps Lock: Settings reads Taken Over in red, names the keyboards and Raycast, and
  Diagnostics… lists it under Apps Changing Keys
- With Hyperkey running, the status reads Blocked and a HUD names it; quitting Hyperkey restores
  Hyper without a relaunch. Diagnostics… lists BetterTouchTool as a warning when it runs
- Remap Caps Lock in Keyboard ▸ Modifier Keys: Diagnostics… reports it with the keyboard's name
- In a password field, Hyper with Caps Lock shows the Secure Input HUD at once. Turn on Secure Input
  Compatibility: a Hyper shortcut now fires there, and Diagnostics… names the Secure Input holder
- With Secure Input held, record Hyper+J with and without Secure Input Compatibility: both save ✦J,
  never F18 or ⌃J, and a quick Hyper+J leaves Caps Lock off
- Quit Tinycast: Caps Lock types capitals again on every keyboard, the built-in one included
- With Karabiner-Elements running and Caps Lock left alone there, Hyper with Caps Lock still works;
  quit Tinycast and Karabiner's own remaps keep working. Remap Caps Lock in Karabiner instead:
  Diagnostics… reports a Karabiner conflict
- Every binding survives quit and relaunch
- `Enable Commands` off leaves every pane-owned command listed, searchable and firing: File Search,
  Navigation, Quicklinks, the custom-command pair and the window layout and room commands

### Quicklinks

- A quicklink opens its destination; `{argument}` prompts in order and Backspace steps back
- `{selection}` with nothing selected opens nothing and shows "Couldn’t get the selected text". With
  a required `{argument}` too, the argument is asked for first
- In an app Accessibility can't read (a terminal, an Electron app), a `{selection}` quicklink still
  opens with the selected text, and the clipboard holds what it held before. Repeat it ten times to be sure
- With **Pass selected text as argument** on, select text and press a quicklink's shortcut: its first
  free-text argument is filled and the link opens. Blank selection or an `options=` first argument still
  prompts; Return on the row in the launcher never fills from the selection
- Opening Search Quicklinks normally focuses search; a readable selection opens directly.
  Custom-command argument prompts still focus their first missing field
- In the launcher and Search Quicklinks, open Actions with ⌘K and close with ⌘K or Escape. Immediately
  type a query, use the arrows and press Return; the palette must accept keyboard input again
- Pin, duplicate, delete and Open with Default all behave; import and export round-trip
- Display order is pinned first by pin time, then by name

### Apple Shortcuts

- Off out of the box: the pane lists nothing and no shortcut reaches the launcher
- Switching on lists every shortcut with the Shortcuts app's icon; ↵ on a row runs it
- A shortcut added in Shortcuts appears on the next launcher open
- A row's hotkey runs it with the palette closed; switching the feature off silences it
- Unchecking a row hides it from search, and its hotkey still fires
- Deleting a shortcut in Shortcuts frees its alias and hotkey on the next launcher open
- A shortcut that fails shows Tinycast's dialog with the tool's error

### File Search

- With File Search **off**: Search Files is absent, its shortcut no-ops, and no index folder exists
- Without Full Disk Access the pane shows **Required** with the hint, the palette says so, and ↵ and the
  button both open Privacy & Security › Full Disk Access; granting it starts a build with no relaunch
- The first build shows a rising item count in Settings and the palette, then a final count and date;
  Activity Monitor shows the helper's memory, and Tinycast's own footprint is back at its baseline after
- Enabling in Settings exposes Search Files immediately; it persists across relaunch and backup import
- Disabling during a query cancels it, returns the open screen to the launcher and deletes the index
- File Search and Quicklinks remain independently visible in all four enabled/disabled combinations
- An empty query lists recent files under home; a filename query returns only entries beneath the scopes
- Files under home rank above system, hidden and bundle files with the same name
- Creating, renaming and deleting a file in `~/Desktop` shows in results within a second
- **Rebuild Index** rebuilds while the old index keeps answering
- Return opens, Command-Return reveals in Finder, and Copy Path keeps the palette open with a HUD
- A file and a folder drag into Finder as copies and into a browser's upload field; a cancelled drag
  flies back and leaves the palette up, a landed one hides it
- Replacing a query quickly never lets an older result list overwrite the current query
- A broad `.` search can be scrolled end to end; leaving it releases its fitted icons, and repeating the
  cycle does not raise the post-close memory floor
- Replacing the whole disk with one folder narrows results to it after the rebuild; restoring the default
  brings them back
- A cleared scope list returns nothing and never hangs
- A missing scope shows the warning triangle without failing the rest of the index
- The pattern field takes a click; **Add** and Return add `*.log`, which takes effect after the rebuild
- **Add Folder…** adds a `~/…` pattern, and that folder's files leave the results after the rebuild
- Built-in ignore rows carry no remove button; user rows do, and a duplicate or blank is refused
- Recording a shortcut opens the palette straight into File Search, hidden from the launcher or not
- Search Files is absent from Settings ▸ Commands, and `Enable Commands` off leaves its shortcut live
- Export, clear both lists and the shortcut, re-import: all three return, defaults undo not duplicated
- **Show in launcher** off (the default): a typed filename lists no Files section
- **Show in launcher** on: three or more characters list up to five files between Results and the
  fallbacks; two do not. ↵ opens, ⌘↵ reveals, the copy, paste and ⌃X chords act
  on the row, and a row drags out as a copy
- Choosing the Search Files fallback right after opens on the same results without a pause
- With Pop to Root Search delayed, close and reopen before the timeout: the launcher keeps its query
  and file results. Let the timeout expire, or use Immediately: reopening starts with an empty query

### Calculator and currency

- `2+2` shows a card; ↵ copies and records to history; unit and date conversions work
- In Calculator History, ⌃X deletes a row and ⌃⇧X clears the history behind a confirmation
- A currency query answers from the cached snapshot; with the cache cleared and no network it reports
  rates unavailable rather than guessing
- A bare amount (`1 usd`) answers in the Mac's region currency, and follows a change to
  System Settings ▸ General ▸ Language & Region without a relaunch, and nothing prompts for location
- A crypto query (`1 btc`, `0.5 sol to eur`) answers, and `1 usd to btc` stays in plain notation
- `1000 usd in eur/12` converts and then divides; copying preserves the euro amount and code.
  `100km/h in m/s / 2` retains the compound target, and `1000 usd in eur / 0` stays silent

### File favorites

- In Search Files, use ⌘K → Add to Favorites on a folder and ⇧⌘F on a file. Open root search with an
  empty query: both appear with app favorites in insertion order, including after relaunch.
- Move files and apps across each other with ⌥⌘↑/↓ and the matching menu actions; selection follows
  the moved row. Remove a favorite through either path; selection stays within Favorites.
- Hold ⌘ and check that each displayed ⌘1–⌘0 opens that favorite, including from the compact palette.
- Search for a saved filename, including a short query and accented text: the favorite appears once.
  Turn Show in launcher off: saved files remain available; disable File Search: they disappear.
  Re-enable it: their order returns.
- Export and import settings: the mixed order survives. Move or remove a saved file: opening reports
  the failure and Remove from Favorites still works.

### System actions and window management

- A confirmation-gated action (Restart, Quit All) confirms, showing the subject's own glyph
- Restart and Shut Down follow "Reopen windows when logging back in": after logging back in,
  apps and windows reopen with it on and stay closed with it off. Check both actions and settings
  from the launcher and a global hotkey
- Empty Trash confirms while Finder's "Show warning before emptying the Trash" is on, and runs
  without a dialog once it is off
- Volume actions show the volume HUD; everything else shows the message pill
- Toggle Microphone Mute works from the launcher and a global hotkey with the palette closed;
  its pill reports Microphone Muted / Microphone Unmuted, input audio follows that state, and input
  gain and output audio stay unchanged. Switch the default input and repeat; an unavailable or
  externally controlled mute reports failure. Rapid repeats while a change is pending are ignored
- Holding a bound hotkey does **not** stack dialogs
- Lock Screen locks from a global hotkey with the palette closed, including a Hyper-key binding
- Window commands move the window you were last in; cycle-on-repeat steps ½ → ⅓ → ⅔
- "Top Half" lands flush with the top of the visible frame, on a secondary display too
- A command with Settings focused places Settings, not the app behind it
- Cycling, Restore, custom sizes and display moves all work on Settings; Fullscreen toggles it
- HUDs and dialogs are never placed
- Rooms: create one from Switch Room; ⇥ glides the preview through its layouts; ↵ lands its windows
  with the gap, hides other apps and parks their extra windows; quitting, `kill -9` then relaunching, and
  turning Window Management off each bring every window back.
  Repeat on two displays and with Reduce Motion on

### Settings and backup

- Settings → About shows the version, a link to the fork's GitHub repository and the license, and
  nothing that reaches `tinycast.dev`
- Every pane renders and the sidebar switches without flicker
- A feature switch takes effect in the launcher immediately; every setting survives relaunch
- Export produces a `.tinycast`; import applies it and reports a per-category summary
- Untick a category on export, and the import picker greys that row out rather than offering it
- Untick a category on **import** and confirm it did not arrive, while the ticked ones did
- A file whose `manifest.json` `format` was hand-edited is refused **with a message naming it**
- Cancelling the save panel leaves nothing in `~/Library/Caches/com.xanderthunder.tinycast.dev/backup-staging/`
- **`settingsFileEnabled` is not in the exported file**, and importing does not turn the settings file on
- Nothing in the extracted tree names a Keychain item

### Clean install

The realistic storage failure is a store that crashes on an absent file rather than starting empty.
Wipe the Dev channel and check that path directly:

```sh
rm -rf ~/Library/Caches/com.xanderthunder.tinycast.dev
rm -rf "$HOME/Library/Application Support/com.xanderthunder.tinycast.dev"
rm -rf ~/.config/tinycast-dev
defaults delete com.xanderthunder.tinycast.dev 2>/dev/null || true
tccutil reset Accessibility com.xanderthunder.tinycast.dev 2>/dev/null || true
```

- Launches with every store directory absent: no crash, no hang; onboarding runs
- Onboarding has no Dock entry; completing it leaves the palette open and ready for typing.
  Settings still adds a Dock entry while open and removes it when the last ordinary window closes
- Palette opens and lists apps; quicklinks, custom commands and calculator history are all empty
  and all accept a first entry
- **Every setting shows its intended default.** Walk the panes: this is what catches a broken
  absence-versus-`false` read
- Quit and relaunch: everything created above persisted
- Nothing was written outside `com.xanderthunder.tinycast.dev/`. Channel isolation is not negotiable: a
  Dev build writing into the stable app's directory is a defect even though the data is disposable
