# Claude Usage widget — design

Date: 2026-10-14 · Branch: `claude-usage-widget` · Status: draft for review

## Goal

A Nook widget that shows when Claude Code is working, notifies when a turn
finishes, and shows Claude usage when the Nook is open. It is a small
Claude-only take on the AI-agents feature in `vorssaint-utils`
("AgentsUsage"), built to the same widget contract as the other Nook widgets
(grid width from `WidgetPrefs.size`, width slider in settings, the same
insets and position-aware padding as Timer/Todo).

## Decisions made with the user

| Question | Decision |
|---|---|
| How to detect "in progress" | Tail Claude Code session logs (`~/.claude*/projects/**/*.jsonl`). No hooks, no process polling. |
| Where it shows | Closed-notch live activities: `.claudeWorking` while a turn runs, `.claudeFinished` alert when it ends. |
| What the open widget shows | Same as Vorssaint: plan limits (from the Claude desktop app) plus today's tokens and API value, and live sessions. |
| Two accounts | User runs work `claude` (enterprise, `~/.claude`) and personal `claude-personal` (`CLAUDE_CONFIG_DIR=~/.claude-personal`). Both are tracked as profiles. |
| Code reuse | Clean-room. Vorssaint is GPL-3.0 and nootch is PolyForm Noncommercial; we copy behaviour, not code. |

## Findings that shaped the design

- Vorssaint only reads `~/.claude/projects` and `~/.config/claude/projects`;
  it never sees `~/.claude-personal`.
- The Claude desktop app writes plan limits to
  `~/Library/Application Support/Claude/plan-usage-history.json` (percent
  used for the 5h session `fh` and weekly `sd`/`so`/`sn` windows, each sample
  tagged with an `org` UUID). On this Mac that org is the **personal**
  account. Vorssaint filters samples by the org in `~/.claude.json`, which
  is the **work** (managed) account, so it would drop the limits entirely.
  Limits must therefore be matched per profile.
- nootch is not sandboxed (no `app-sandbox` entitlement), so it can read
  these paths directly.

## Architecture

### Profiles

A profile is one Claude config dir.

- Discovery: `~/.claude`, `~/.config/claude`, and any `~/.claude-*` directory
  containing `projects/`. Re-scanned on a slow timer so a new dir appears
  without a relaunch.
- Org: read `organizationUuid` from the profile's `.claude.json`
  (`~/.claude.json` for the default dir, `<dir>/.claude.json` otherwise).
  Only that field is read.
- Label: from the folder suffix, never the org name (the personal org name
  is an Apple private-relay address). `.claude` → "Work", `.claude-personal`
  → "Personal", any other `.claude-foo` → "Foo". (The default dir is labelled
  "Work" because that is how this user's setup is; other users get the same
  label for their default dir, which is acceptable and editable later.)

### `ClaudeUsageStore` (singleton, `@Observable`)

Mirrors `NookTimersStore.shared`. One instance, because nootch has a window
per screen and per-view watchers would double-fire alerts.

Responsibilities:

1. **Tail logs.** Every 2s, for `.jsonl` files modified in the last 30
   minutes (a slower pass for the rest of today), read new bytes from a saved
   offset. Filter each line on raw bytes (`"type":"assistant"`,
   `"type":"user"`) before any JSON parse; some lines are many MB.
2. **Track turns** (pure function in `ClaudeTurnTracker`, unit-tested):
   - Opens on a `user` line that is not `isMeta`, not `isSidechain`, and not a
     `tool_result`.
   - Stays open on `assistant` lines whose `stop_reason` is `tool_use`/nil.
   - Closes on `assistant` with `stop_reason` of `end_turn`, `stop_sequence`
     or `max_tokens` (not sidechain), on a user `[Request interrupted by
     user` marker, or after an idle timeout (default 10 min with no new
     lines and no running Bash tool) so a crashed session does not stay
     "working".
   - A subagent (`isSidechain`) never opens or closes the parent turn.
3. **Emit events.** `finished(profile, project, duration, tokens, cost)` only
   for turns that end *after* the initial history read completes (no alert
   spam from replayed logs) and last at least `minFinishSeconds`.
4. **Aggregate today's usage** per profile: tokens (input, cache write, cache
   read, output) and estimated API value. Records are de-duplicated by
   `message.id` + `requestId`, keeping the largest reading since streamed
   replies log once per content block.
5. **Plan limits.** Read the desktop app's `plan-usage-history.json` (v1/v2,
   4 MB cap, unknown version → ignored). Attach windows to the profile whose
   `organizationUuid` equals the sample `org`; profiles with no match show
   "Limits unavailable". Session reset = 5h after the session's first
   request when known, else estimated; weekly reset from the last drop in
   history. Re-read when the file changes and when the widget appears.

### Pricing

A small bundled table of per-model-family list prices
(input / output / cache write / cache read per million tokens), keyed by
model-id prefix. Unknown models contribute tokens but no cost, and the cost
line shows a "+" when any model in the period was unpriced. The table is a
Swift constant in this repo, written fresh (prices are public facts); no
network fetch in v1.

### Live activities

New `LiveActivity` cases:

- `.claudeWorking`: left wing sparkle glyph (Claude orange), right wing
  elapsed time (`m:ss`). Appears while any turn is open; user-toggleable in
  Live Activities settings like the others. Multiple concurrent turns show
  the longest-running one.
- `.claudeFinished`: transient and always-on, exactly like `.timerExpired`:
  surfaces regardless of the toggle list, top priority in
  `LiveActivitySelectionManager`, auto-dismisses (same queue/timer approach
  as `NookTimersStore.expiredLabelQueue`). Text: `"<Label> · <project> ·
  2m 14s"`.

Both wings use the existing `LiveActivityIconView` + text styling and fit the
existing compact wing geometry.

### The widget (`ClaudeUsageWidgetView`)

- `ClaudeUsageWidgetSettings: WidgetPrefs`: `size` default 4×2 (width slider
  3…8 like Timer), `notifyOnFinish = true`, `playSound = true`,
  `minFinishSeconds = 10`.
- View contract identical to Timer/Todo: takes `arrayPosition` and
  `internalPadding`; `.paddingDependingOnArrPos`;
  `.frame(width: prefs.size.width.screenPoints, alignment: .leading)` then
  `.frame(maxHeight: .infinity)`; interior insets reuse the `TimerInsets`
  derivation (top = `TopBarView.buttonsVisualBottom`, bottom = widget
  padding, corner-safe leading/trailing for first/last position).
- Content, top to bottom: a live row per working session (provider glyph,
  label, project, elapsed); one stacked block per profile that has data (no selector); plan-limit rings for 5h and weekly with reset
  countdown; today's tokens and API value. Empty state when no Claude logs
  exist: "No Claude activity yet".
- Scrolls vertically if content exceeds the band, like Timer's list.

### Wiring checklist (every exhaustive switch)

Widget: `NookWidget` (`case claudeUsage`; `icon`, `name`, `prefs`,
`gridSizeType = .variable`), `Defaults.swift` key,
`PerWidgetSettingsKeys.swift`, `RootView` (`@Default` + `.environment`),
`EnvironmentsModifier` width switch, `subToAllWidgetsSettingsChanges`,
`WidgetsSettingsTabView` (`@Default` + switch), `NookView` switch, new
`ClaudeUsageWidgetSettingsView` (width `SliderPlus`, toggles, threshold).

Live activities: `LiveActivity` enum (`icon`, `name`, `isUserConfigurable`),
`LiveActivityView` switch, both switches in `MockTopBar.swift`,
`LiveActivitiesCustomizeSettingsTabView`, `LiveActivitySelectionManager`
priority list, `ActiveLiveActivitiesManager` always-on exception for
`.claudeFinished`.

Strings use `String(localized:)`. New files go under `NotchNook/`
(folder-synchronized target, no pbxproj edit needed).

## Settings and privacy

- Nothing leaves the Mac; no sign-in, no network. Only counters, model names,
  times and folder names are retained. Prompts, replies and tool output are
  never stored or logged.
- `.claude*.json` is read for `organizationUuid` only.
- Haptics, if any, respect `GeneralSettings.disableHaptics`.

## Error handling

- Missing dirs/files: profile simply has no data. Unreadable or unknown-format
  limits file: limits omitted, never guessed.
- Truncated final line in a log: carry the partial line to the next read.
- File rotated/shrunk: reset offset to 0 for that file.
- Large lines: skip by byte filter without decoding.

## Testing

XCTest (`NotchNookTests`), driven through `xcodebuild test`:

- `ClaudeTurnTracker`: open/close, tool_use continuation, interrupt,
  sidechain ignored, idle timeout, running-Bash keeps open.
- Usage de-duplication and streamed-record merge.
- Org matching: personal samples → personal profile only; work profile gets
  "unavailable".
- Finish threshold and "no alert for replayed history".
- Plan-limit parsing: v1/v2, unknown version, oversize file.

Manual: build with `xcodebuild -project NotchNook.xcodeproj -scheme NotchNook
build`, launch, run a real `claude` and `claude-personal` turn, screenshot
the notch (working wing, finished alert, open widget at several widths and in
first/middle/last positions).

## Out of scope (v1)

Codex/OpenCode/Copilot, per-model/project breakdowns, activity heatmap,
budgets and limit warnings, price-list download, historical trend charts,
user-renamable profile labels, Setapp-specific behaviour (no Sparkle impact).
