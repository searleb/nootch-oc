# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NotchNook is a macOS menu-bar/notch utility app (lo-cafe / Igor Marcossi). It draws an
interactive UI around the MacBook notch ("the Nook") hosting widgets — media player,
calendar, notes, todos, timer, mirror, shortcuts — plus a file "Tray", drop area, and
live activities. AppKit-hosted, SwiftUI-rendered. Shipped via direct download (Sparkle
auto-update) **and** the Setapp store. **It is never sold on the Mac App Store, so
private-API use is acceptable** and is used deliberately (e.g. the native Liquid Glass
stack).

## Build / test

There is **no `xcodebuild`/CLI workflow expected here** — the user drives builds through
the **Xcode MCP** (`mcp__xcode__*`). The build is the **arbiter of correctness**:

- Build: `mcp__xcode__BuildProject` with `tabIdentifier: "windowtab1"`.
- Tests: `mcp__xcode__RunAllTests` / `RunSomeTests` (XCTest target `NotchNookTests`,
  e.g. `SideEffectsModifierTests`).
- **SourceKit cross-file diagnostics are NOISE** — `Cannot find X in scope`,
  `Color has no member hex`, `No such module Defaults`, `Cannot find type 'LiquidGlass'`
  routinely appear in single-file analysis yet build clean. Trust `BuildProject`, not the
  in-editor squiggles. (`Defaults` etc. are real SPM packages — see `Package.resolved`.)

### Build variants
- Two configs (`Debug`, `Release`) and a **Setapp** build path gated by the
  `SETAPP_BUILD` compilation condition. `#if !SETAPP_BUILD` wraps all **Sparkle**
  (auto-update) code; the Setapp build has no Sparkle.
  When touching update/about code, keep BOTH branches compiling.
- There is **no trial or license/registration system** — this fork is open source and runs
  unrestricted. Don't reintroduce license gating.
- Deployment target is **macOS 14.4+**. Guard newer APIs with `#available` / `if #available`
  and provide a fallback (the timer glass pill is the canonical example: native macOS 26
  `CABackdropLayer` path → Metal lens → hairline capsule).

## Searching the code

This repo is **live-indexed by the hatter MCP** (`search_code`, project id `xJ4`). Use it
**first** for "where/how is X wired up" questions — one natural-language query returns
ranked chunks repo-wide, and the index auto-syncs after edits. Fall back to grep/read to
confirm or expand. Note: the `rtk` proxy intercepts bare `grep`; use **`/usr/bin/grep`**
when you need raw grep.

## Architecture

### Process / window model
- `main.swift` → `AppDelegate` (accessory app, no Dock icon). `applicationDidFinishLaunching`
  eagerly instantiates the singleton managers (`CalendarManager`, `MediaManager`,
  `BluetoothManager`, `FullscreenMonitor`, …) and seeds SwiftData notes
  **once** before any window exists, then builds `WindowsManager.shared`.
- `WindowsManager` (singleton) owns one borderless, transparent, click-through-capable
  window **per screen** (`DisplayKit`), rebuilt on `didChangeScreenParametersNotification`
  (debounced). Window classes: `BetterWindow` / `ForceFocusableWindow` (custom `NSWindow`s
  that can become key on demand for text editing in the notch). Settings live in a separate
  `Settings`-package window (`SettingsWindowController`).
- Each window roots a `RootView(displayKitId:…)` → `NotchView` → the notch UI. The notch has
  modes (`NotchNookState.NotchMode`: `closed / nook / tray / dragging`).

### State & settings — the central pattern
- **`Defaults` (sindresorhus)** is the single source of truth for all settings. Every
  settings group is one `Defaults.Key` of a `Codable` struct, all declared in
  `extensions/Defaults.swift` (`generalSettings`, `nookSettings`, `timerWidgetSettings`,
  one per widget, etc.).
- **`RootView` injects every settings group into the SwiftUI environment** via `@Default` →
  `.environment(\.…)`. Views read settings through `@Environment`, not by reaching into
  `Defaults` directly. When adding a setting: add the struct + `Defaults.Key`, an
  `EnvironmentKey`, and wire it through `RootView`.
- **`InMemoryDefault<T>`** is a non-SwiftUI live cache of a `Defaults.Key` (subscribes to
  `Defaults.updates`) for code outside the view tree (managers, utilities). Writing `.value`
  writes back to `Defaults`.
- `NotchNookState` (`@Observable`) is the transient per-notch runtime state (hidden,
  indicator, quickPeeks, mode) — **not** persisted.

### The Nook & widgets
- `NookView` renders `nookSettings.enabledWidgets` in an `HStack`, switching on
  `NookWidgetEnum` to the per-widget view (`…/Notch/Nook/Widgets/<Widget>/`). Widget layout
  uses a **grid unit of 50pt** (`NookGrid.point`); sizes are expressed as `NookGrid.Point`
  multiples (`.screenPoints` converts to CGFloat).
- Persistent widget data (Notes, Todos) uses **SwiftData**, one shared `ModelContainer`
  (`RootView.sharedModelContainer`, static so all per-screen RootViews + AppDelegate share
  it). Saved on terminate.

### Haptics (respect the user setting)
- Always gate haptics on `GeneralSettings.disableHaptics`. The simple helper is
  `vibrate()` (`utils/vibrate.swift`); the timer wheels have a richer `TimerHaptics` that
  composes the only three macOS Force-Touch primitives (`.generic`, `.alignment`,
  `.levelChange`) via timing/sequencing — macOS has no CoreHaptics waveforms.

### Scroll "glue" reference pattern
When asked to make scrolling feel damped/sticky "like the calendar widget", the reference
is `components/ScrollWheelViewRepresentable.swift` (NSView `scrollWheel` by `event.phase`,
exponential smoothing factor 0.3) + `CalendarWidget/CalendarWidgetView.swift` /
`ScrollableDaysView.swift` (offset accumulation, velocity/offset thresholds on drag-end,
`.snappy` snap-back with a `vibrate()` past the halfway point).

### Timer glass pill (private-API Liquid Glass)
`…/Widgets/TimerWidget/LiquidLens/` holds a three-tier focus-pill renderer, chosen at the
call site in `TimerCreatorView`:
1. **macOS 26+**: `NativeGlassPill` — Apple's private `CABackdropLayer` + `glassBackground`
   `CAFilter` + `CASDFLayer` stack (the same one SwiftUI `.glassEffect()` uses). Runs in the
   WindowServer (GPU, off-main, world-anchored). Mirrors `AlexStrNik/ShatteredGlass`
   (indexed as hat `BY9`). Needs the `NativeGlass-Bridging-Header.h`.
2. **Metal fallback** (`LiquidLensView` + `LiquidGlassFragment.metal` + `ZeroCopyBridge`):
   a per-frame `CALayer.render(in:)` refraction lens for < macOS 26.
3. Plain hairline capsule if no Metal device.

Every private class is resolved via `NSClassFromString` and gated behind an `isAvailable`
flag — **never force-unwrap a private symbol**; a future OS rename must degrade gracefully,
not crash the notch. `ProgressiveBlurView` is a related lighter primitive: a `CABackdropLayer`
+ `variableBlur` `CAFilter`. Critical gotcha: **`variableBlur` reads its `inputMaskImage`'s
alpha channel** (alpha 1 = full blur, 0 = crisp) — a mask with no alpha channel blurs
uniformly; `gaussianBlur` ignores the mask entirely.

## Xcode project structure
- The **app target is folder-synchronized** (`PBXFileSystemSynchronizedRootGroup`, as of
  commit `79d1611`): new `.swift` files under `NotchNook/` auto-register — no `project.pbxproj`
  edits needed. **Bridging headers and build-setting changes still require manual pbxproj
  edits** (e.g. `SWIFT_OBJC_BRIDGING_HEADER`). See memory `notchnook-pbxproj-not-synchronized`.

## Localization
- UI strings are localized: `String(localized: "…")`, stored in `Localizable.xcstrings`
  (1MB). Crowdin-synced (`crowdin.yml`, `.github/workflows/crowdin-sync.yml`). Prefer
  `String(localized:)` for new user-facing text.
