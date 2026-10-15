# Claude Usage Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Nook widget that shows when Claude Code is working, raises a closed-notch alert when a turn finishes, and shows plan limits plus today's tokens and API value when the Nook is open, for both the work (`~/.claude`) and personal (`~/.claude-personal`) profiles.

**Architecture:** A pure-Foundation engine (log parser, turn tracker, usage ledger, plan-limit reader, profile discovery, file tailer) is polled every 2s by an `@Observable` singleton `ClaudeUsageStore`. The store drives two new live activities (`.claudeWorking`, `.claudeFinished`) and feeds `ClaudeUsageWidgetView`, which follows the same width/inset contract as the Timer widget.

**Tech Stack:** Swift 5 mode, SwiftUI + AppKit, `Defaults` (sindresorhus), XCTest. macOS 14.4+. App target and test target are folder-synchronized (new files under `NotchNook/` and `NotchNookTests/` need no pbxproj edit).

**Spec:** `docs/superpowers/specs/2026-10-14-claude-usage-widget-design.md`

## Global Constraints

- Clean-room: do not copy code from `vorssaint-utils` (GPL-3.0); nootch-oc is PolyForm Noncommercial. Copy behaviour only.
- Nothing leaves the Mac: no network, no sign-in. Prompts, replies and tool output are never stored or logged. `.claude.json` is read for `organizationUuid` only.
- Widget contract: `size.width` in a `WidgetPrefs` struct; view takes `arrayPosition` and `internalPadding`; `.paddingDependingOnArrPos`; `.frame(width: prefs.size.width.screenPoints, alignment: .leading)` then `.frame(maxHeight: .infinity)`; insets reuse `TimerInsets`.
- Default widget size 4x2, width slider 3...8. Finish alert threshold default 10s. Profile labels from folder suffix (`.claude` → "Work", `.claude-personal` → "Personal"), never org names.
- Plan limits attach to a profile only when the sample `org` equals that profile's `organizationUuid`; otherwise show "Limits unavailable".
- No finished alert for turns replayed from history at launch; only turns with `completed == true` and duration >= `minFinishSeconds` alert.
- `LiveActivity.claudeFinished` is always-on and not user-configurable (like `.timerExpired`); `.claudeWorking` is user-toggleable.
- User-visible strings use `String(localized:)` (or `Text("…")` literals). Haptics, if any, respect `GeneralSettings.disableHaptics`.
- Do not touch the user's pre-existing uncommitted files: `NotchNook.xcodeproj/project.pbxproj`, `NotchNook.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `NotchNook/Localizable.xcstrings`. Only `git add` files this plan creates or edits by path. Builds may auto-edit `Localizable.xcstrings`; never stage it.
- Commit steps run only after the user okays committing (ask once at execution start).

**Spec deviation (documented):** The closed-notch wings are only `TopBarView.liveActionWidth` = 35pt wide, so the finished alert shows a check glyph on the left and the duration (`2m 14s`) on the right. The full "Label · project" text goes in the accessibility label and the open widget.

## Commands

```bash
# Build (arbiter of correctness; SourceKit squiggles are noise)
xcodebuild -project NotchNook.xcodeproj -scheme NotchNook -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -15

# One test class
xcodebuild test -project NotchNook.xcodeproj -scheme NotchNook -destination 'platform=macOS' -only-testing:NotchNookTests/<ClassName> 2>&1 | /usr/bin/grep -E "error:|Test case|TEST (SUCCEEDED|FAILED)"
```

Both were verified on the clean branch: build succeeds and `SideEffectsModifierTests` passes.

## Review Focus

Failure modes the spec implies that no single feature task would obviously test; each has a pinning test in the owning task.

1. Multi-megabyte JSONL lines (tool results) while a turn is open must not be JSON-decoded and must not stall polling. (Task 2)
2. A log line caught mid-write (no trailing newline yet) must be held and parsed only once complete; a truncated or rotated file must reset its cursor. (Task 6)
3. History replayed at launch must never fire a finished alert, and a turn already running at launch must show as working. (Task 7)
4. Subagent logs (separate `subagents/*.jsonl` files, `isSidechain: true`) count tokens but never open or close the parent turn; interrupt text quoted inside a tool result must not end a turn. (Tasks 2, 7)
5. Missing, unreadable, or mismatched-org `.claude.json` / `plan-usage-history.json` must yield "Limits unavailable", never a crash or the wrong account's limits. (Tasks 5, 6, 7)

## File Structure

Create (all under `NotchNook/` unless noted):

| File | Responsibility |
|---|---|
| `models/claude/ClaudeUsageModels.swift` | `ClaudeTokens`, `ClaudeUsageRecord`, `ClaudeUsageSummary`, `ClaudeLiveSession`, `ClaudeProfileSnapshot` |
| `models/claude/ClaudePricing.swift` | List-price table and `cost(...)` |
| `models/claude/ClaudeFormat.swift` | Elapsed/duration/token/cost/reset formatting |
| `models/claude/ClaudeLogParser.swift` | One log line → `ClaudeLogEvent`s, per-file `ClaudeLogState` |
| `models/claude/ClaudeTurnTracker.swift` | Open/finished turns, idle close |
| `models/claude/ClaudeUsageLedger.swift` | De-duplicated usage records, summaries, `ClaudeSessionBlock` |
| `models/claude/ClaudePlanLimits.swift` | Desktop-app `plan-usage-history.json` reader and window math |
| `models/claude/ClaudeProfile.swift` | Profile discovery, labels, org lookup |
| `models/claude/ClaudeLogTailer.swift` | Offset-based incremental file reader |
| `models/claude/ClaudeUsageEngine.swift` | Synchronous poll: files → events → snapshots |
| `models/singletons/ClaudeUsageStore.swift` | Timer, main-thread publish, live-activity + alert queue |
| `models/settings/Nook/widgets/ClaudeUsageWidgetSettings.swift` | `WidgetPrefs` |
| `components/Notch/TopBar/liveActivities/activities/Claude/ClaudeLiveActivityViews.swift` | Wing views + `ClaudeStyle` |
| `components/Notch/Nook/Widgets/ClaudeUsageWidget/ClaudeUsageWidgetView.swift` | The widget |
| `views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/perWidgetSettings/ClaudeUsageWidgetSettingsView.swift` | Settings pane |
| `NotchNookTests/Claude/ClaudeFixtures.swift` + one `*Tests.swift` per unit | Tests |

Modify: `models/enums/NookWidgetEnum.swift`, `extensions/Defaults.swift`, `extensions/EnvironmentValues/Defaults/PerWidgetSettingsKeys.swift`, `views/RootView.swift`, `views/NotchView/modifiers/EnvironmentsModifier/EnvironmentsModifier.swift`, `extensions/View/subToAllWidgetsSettingsChanges.swift`, `views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/WidgetsSettingsTabView.swift`, `components/Notch/Nook/NookView.swift`, `models/enums/LiveActivityEnum.swift`, `components/Notch/TopBar/liveActivities/LiveActivityView.swift`, `views/Settings/panes/LiveActivitiesSettings/tabs/LiveActivitiesCustomizeSettingsTab/MockTopBar.swift`, `.../LiveActivitiesCustomizeSettingsTabView.swift`, `models/singletons/LiveActivitySelectionManager.swift`, `models/singletons/ActiveLiveActivitiesManager.swift`, `models/settings/LiveActivities/LiveActivitiesSettings.swift`, `AppDelegate.swift`.

Code blocks that start with `// FILE: <path>` are whole new files; drop that first line when saving.

---

## Task 1: Models, pricing, formatting

**Files:**
- Create: `NotchNook/models/claude/ClaudeUsageModels.swift`, `NotchNook/models/claude/ClaudePricing.swift`, `NotchNook/models/claude/ClaudeFormat.swift`
- Test: `NotchNookTests/Claude/ClaudeFormatTests.swift` (also covers pricing)

**Interfaces:**
- Produces: `ClaudeTokens` (`input`, `cacheWrite`, `cacheRead`, `output`, `total`, `merged(with:)`, `+=`); `ClaudeUsageRecord(key:date:model:project:tokens:longCacheWrite:)`; `ClaudeUsageSummary(tokens:cost:hasUnpriced:requests:)`; `ClaudeLiveSession`; `ClaudeProfileSnapshot`; `ClaudePricing.cost(_:longCacheWrite:model:) -> Double?`; `ClaudeFormat.clock/duration/tokens/cost/resetIn`.

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeFormatTests.swift
import XCTest
@testable import NotchNook

final class ClaudeFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(ClaudeFormat.clock(0), "0:00")
        XCTAssertEqual(ClaudeFormat.clock(134), "2:14")
        XCTAssertEqual(ClaudeFormat.clock(3_725), "1:02:05")
        XCTAssertEqual(ClaudeFormat.clock(-5), "0:00")
    }

    func testDuration() {
        XCTAssertEqual(ClaudeFormat.duration(45), "45s")
        XCTAssertEqual(ClaudeFormat.duration(134), "2m 14s")
        XCTAssertEqual(ClaudeFormat.duration(3_900), "1h 05m")
    }

    func testTokens() {
        XCTAssertEqual(ClaudeFormat.tokens(512), "512")
        XCTAssertEqual(ClaudeFormat.tokens(1_500), "1.5K")
        XCTAssertEqual(ClaudeFormat.tokens(845_000), "845K")
        XCTAssertEqual(ClaudeFormat.tokens(1_234_567), "1.2M")
    }

    func testCost() {
        XCTAssertEqual(ClaudeFormat.cost(3.4), "$3.40")
        XCTAssertEqual(ClaudeFormat.cost(0.42, approximate: true), "$0.42+")
        XCTAssertEqual(ClaudeFormat.cost(123.4), "$123")
    }

    func testResetIn() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(ClaudeFormat.resetIn(now.addingTimeInterval(30), now: now), "<1m")
        XCTAssertEqual(ClaudeFormat.resetIn(now.addingTimeInterval(45 * 60), now: now), "45m")
        XCTAssertEqual(ClaudeFormat.resetIn(now.addingTimeInterval(3 * 3600 + 12 * 60), now: now), "3h 12m")
        XCTAssertEqual(ClaudeFormat.resetIn(now.addingTimeInterval(4 * 86_400 + 2 * 3600), now: now), "4d 2h")
    }

    func testPricingUsesLongestModelPrefix() {
        let million = ClaudeTokens(input: 1_000_000, cacheWrite: 0, cacheRead: 0, output: 0)
        // opus-5-5 is $4/MTok input; the shorter opus-5 prefix ($5) must not win.
        XCTAssertEqual(ClaudePricing.cost(million, longCacheWrite: 0, model: "claude-opus-5-5")!, 4.0, accuracy: 1e-9)
        XCTAssertEqual(ClaudePricing.cost(million, longCacheWrite: 0, model: "claude-opus-5")!, 5.0, accuracy: 1e-9)
        XCTAssertEqual(ClaudePricing.cost(million, longCacheWrite: 0, model: "claude-sonnet-5-5-20261001")!, 2.0, accuracy: 1e-9)
    }

    func testPricingSplitsLongCacheWriteAndAllowsUnknownModel() {
        let tokens = ClaudeTokens(input: 0, cacheWrite: 1_000_000, cacheRead: 0, output: 0)
        // opus-5-5: cacheWrite $5, cacheWriteLong $8 per MTok.
        XCTAssertEqual(ClaudePricing.cost(tokens, longCacheWrite: 400_000, model: "claude-opus-5-5")!, 0.6 * 5 + 0.4 * 8, accuracy: 1e-9)
        XCTAssertNil(ClaudePricing.cost(tokens, longCacheWrite: 0, model: "some-future-model"))
    }

    func testTokensMergeKeepsLargestReading() {
        let a = ClaudeTokens(input: 5, cacheWrite: 1, cacheRead: 9, output: 2)
        let b = ClaudeTokens(input: 3, cacheWrite: 4, cacheRead: 9, output: 20)
        XCTAssertEqual(a.merged(with: b), ClaudeTokens(input: 5, cacheWrite: 4, cacheRead: 9, output: 20))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeFormatTests`. Expected: build FAILS with "cannot find 'ClaudeFormat' in scope".

- [ ] **Step 3: Implement the models**

```swift
// FILE: NotchNook/models/claude/ClaudeUsageModels.swift
import Foundation

/// Token counts reduced to the four buckets Claude bills for. `output` already
/// contains thinking tokens.
struct ClaudeTokens: Equatable {
    var input = 0
    var cacheWrite = 0
    var cacheRead = 0
    var output = 0

    var total: Int { input + cacheWrite + cacheRead + output }

    static func += (lhs: inout ClaudeTokens, rhs: ClaudeTokens) {
        lhs.input += rhs.input
        lhs.cacheWrite += rhs.cacheWrite
        lhs.cacheRead += rhs.cacheRead
        lhs.output += rhs.output
    }

    /// Streamed replies are logged once per content block and the earlier
    /// blocks carry counts so far, so the largest reading of each counter is final.
    func merged(with other: ClaudeTokens) -> ClaudeTokens {
        ClaudeTokens(input: max(input, other.input), cacheWrite: max(cacheWrite, other.cacheWrite),
                     cacheRead: max(cacheRead, other.cacheRead), output: max(output, other.output))
    }
}

/// One billed model response.
struct ClaudeUsageRecord: Equatable {
    /// Identifies the response across duplicate lines and files.
    let key: String
    let date: Date
    let model: String
    let project: String
    var tokens: ClaudeTokens
    /// Part of `tokens.cacheWrite` written to the 1-hour cache tier.
    var longCacheWrite: Int
}

struct ClaudeUsageSummary: Equatable {
    var tokens = ClaudeTokens()
    /// Estimated API value in US dollars at list prices.
    var cost = 0.0
    /// True when a model in the period has no known price, so `cost` undercounts.
    var hasUnpriced = false
    var requests = 0
}

/// A turn Claude is working on right now.
struct ClaudeLiveSession: Equatable, Identifiable {
    let id: String
    let profileID: String
    let profileLabel: String
    var project: String
    let started: Date
    var lastActivity: Date
}

struct ClaudeProfileSnapshot: Equatable, Identifiable {
    let id: String
    let label: String
    var live: [ClaudeLiveSession]
    var today: ClaudeUsageSummary
    var limits: [ClaudeLimitWindow]

    /// Whether the widget has anything to show for this profile.
    var hasActivity: Bool { !live.isEmpty || today.requests > 0 || !limits.isEmpty }
}
```

```swift
// FILE: NotchNook/models/claude/ClaudePricing.swift
import Foundation

/// API list prices, US dollars per million tokens. Used only to put a rough
/// value on usage; unknown models are left unpriced rather than guessed.
/// Long-context surcharges and fast-mode multipliers are not modelled.
enum ClaudePricing {
    struct Rate: Equatable {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheWrite: Double
        let cacheWriteLong: Double
    }

    /// Longest matching id prefix wins, so `claude-opus-5-5` beats `claude-opus-5`.
    private static let table: [(id: String, rate: Rate)] = {
        func r(_ i: Double, _ o: Double, _ cr: Double, _ cw: Double, _ cwl: Double) -> Rate {
            Rate(input: i, output: o, cacheRead: cr, cacheWrite: cw, cacheWriteLong: cwl)
        }
        let rows: [(String, Rate)] = [
            ("claude-fable-5-1", r(10, 50, 0.25, 12.5, 20)), ("claude-fable-5", r(10, 50, 1, 12.5, 20)),
            ("claude-mythos-5-1", r(10, 50, 0.25, 12.5, 20)), ("claude-mythos-5", r(10, 50, 1, 12.5, 20)),
            ("claude-mythos-preview", r(25, 125, 2.5, 31.25, 50)),
            ("claude-opus-5-5", r(4, 20, 0.2, 5, 8)), ("claude-opus-5", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-8", r(5, 25, 0.5, 6.25, 10)), ("claude-opus-4-7", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-6", r(5, 25, 0.5, 6.25, 10)), ("claude-opus-4-5", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-1", r(15, 75, 1.5, 18.75, 30)), ("claude-opus-4", r(15, 75, 1.5, 18.75, 30)),
            ("claude-sonnet-5-5", r(2, 10, 0.1, 2.5, 4)), ("claude-sonnet-5", r(2, 10, 0.2, 2.5, 4)),
            ("claude-sonnet-4-6", r(3, 15, 0.3, 3.75, 6)), ("claude-sonnet-4-5", r(3, 15, 0.3, 3.75, 6)),
            ("claude-sonnet-4", r(3, 15, 0.3, 3.75, 6)),
            ("claude-3-7-sonnet", r(3, 15, 0.3, 3.75, 6)), ("claude-3-5-sonnet", r(3, 15, 0.3, 3.75, 6)),
            ("claude-haiku-5-5", r(0.1, 0.5, 0.01, 0.125, 0.2)), ("claude-haiku-4-5", r(1, 5, 0.1, 1.25, 2)),
            ("claude-3-5-haiku", r(0.8, 4, 0.08, 1, 1.6)), ("claude-3-haiku", r(0.25, 1.25, 0.03, 0.3, 0.5)),
            ("claude-3-opus", r(15, 75, 1.5, 18.75, 30)),
        ]
        return rows.map { (id: $0.0, rate: $0.1) }.sorted { $0.id.count > $1.id.count }
    }()

    static func rate(for model: String) -> Rate? {
        table.first { model.hasPrefix($0.id) }?.rate
    }

    /// Nil when the model has no known price.
    static func cost(_ tokens: ClaudeTokens, longCacheWrite: Int, model: String) -> Double? {
        guard let rate = rate(for: model) else { return nil }
        let long = min(max(longCacheWrite, 0), tokens.cacheWrite)
        let short = tokens.cacheWrite - long
        let total = Double(tokens.input) * rate.input
            + Double(tokens.output) * rate.output
            + Double(tokens.cacheRead) * rate.cacheRead
            + Double(short) * rate.cacheWrite
            + Double(long) * rate.cacheWriteLong
        return total / 1_000_000
    }
}
```

```swift
// FILE: NotchNook/models/claude/ClaudeFormat.swift
import Foundation

enum ClaudeFormat {
    /// `2:14` or `1:02:05`, for a running clock.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// `45s`, `2m 14s`, `1h 05m`, for a finished span.
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    static func tokens(_ count: Int) -> String {
        switch count {
        case ..<1_000: return "\(count)"
        case ..<100_000: return String(format: "%.1fK", Double(count) / 1_000)
        case ..<1_000_000: return String(format: "%.0fK", Double(count) / 1_000)
        default: return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }

    /// `approximate` appends `+` when some usage had no known price.
    static func cost(_ value: Double, approximate: Bool = false) -> String {
        let body = value >= 100 ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
        return approximate ? body + "+" : body
    }

    static func resetIn(_ date: Date, now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }
}
```

`ClaudeProfileSnapshot` references `ClaudeLimitWindow`, defined in Task 5. To keep the build green for this task, add this temporary-free forward definition now and move it in Task 5 only by *extending* it (Task 5 adds `ClaudePlanLimits`, not the window type): put `ClaudeLimitWindow` here.

```swift
// Append to NotchNook/models/claude/ClaudeUsageModels.swift
/// One plan allowance and how much of it is spent.
struct ClaudeLimitWindow: Equatable, Identifiable {
    enum Kind: String { case session, weekly }

    let kind: Kind
    let usedPercent: Double
    let resetsAt: Date?
    /// True when `resetsAt` is inferred from history rather than known.
    let isEstimate: Bool

    var id: String { kind.rawValue }
    var usedFraction: Double { min(1, max(0, usedPercent / 100)) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudeFormatTests`. Expected: `TEST SUCCEEDED`, 7 cases passed.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeUsageModels.swift NotchNook/models/claude/ClaudePricing.swift NotchNook/models/claude/ClaudeFormat.swift NotchNookTests/Claude/ClaudeFormatTests.swift
git commit -m "feat(claude): usage models, pricing table and formatters"
```

---

## Task 2: Log parser and test fixtures

**Files:**
- Create: `NotchNook/models/claude/ClaudeLogParser.swift`, `NotchNookTests/Claude/ClaudeFixtures.swift`
- Test: `NotchNookTests/Claude/ClaudeLogParserTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageRecord`, `ClaudeTokens` (Task 1).
- Produces: `enum ClaudeLogEvent { turnBegan(Date), turnActive(Date?), turnEnded(Date, completed: Bool), usage(ClaudeUsageRecord) }`; `struct ClaudeLogState { session, project, turnOpen, runningCommands }`; `ClaudeLogParser.parse(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent]`; test helper `ClaudeFixtures` (`prompt`, `toolResult`, `interrupt`, `assistant`, `stamp`, `date`).

Real log facts this relies on (verified on this Mac): lines are compact JSON so `"type":"assistant"` byte matches work; the interrupt text is `[Request interrupted by user]` or `[Request interrupted by user for tool use]`; subagent logs are separate `<session>/subagents/agent-*.jsonl` files whose lines carry `"isSidechain":true`; timestamps look like `2026-10-14T12:57:25.526Z`.

- [ ] **Step 1: Write the fixtures and failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeFixtures.swift
import Foundation
@testable import NotchNook

/// Builds log lines in the shape Claude Code writes them (compact JSON).
enum ClaudeFixtures {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func stamp(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ text: String) -> Date { formatter.date(from: text)! }

    private static func encode(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }

    static func prompt(at date: Date, session: String = "s1", cwd: String = "/Users/x/Sites/anywhere",
                       text: String = "do the thing", sidechain: Bool = false, meta: Bool = false) -> Data {
        var object: [String: Any] = ["type": "user", "timestamp": stamp(date), "sessionId": session, "cwd": cwd,
                                     "isSidechain": sidechain, "message": ["role": "user", "content": text]]
        if meta { object["isMeta"] = true }
        return encode(object)
    }

    static func userBlocks(at date: Date, blocks: [[String: Any]], session: String = "s1",
                           sidechain: Bool = false) -> Data {
        encode(["type": "user", "timestamp": stamp(date), "sessionId": session, "cwd": "/Users/x/Sites/anywhere",
                "isSidechain": sidechain, "message": ["role": "user", "content": blocks]])
    }

    static func toolResult(at date: Date, toolUseID: String, session: String = "s1", payload: String = "ok") -> Data {
        userBlocks(at: date, blocks: [["type": "tool_result", "tool_use_id": toolUseID, "content": payload]], session: session)
    }

    static func interrupt(at date: Date, session: String = "s1") -> Data {
        userBlocks(at: date, blocks: [["type": "text", "text": "[Request interrupted by user]"]], session: session)
    }

    static func assistant(at date: Date, stop: String?, session: String = "s1", messageID: String = "m1",
                          requestID: String = "r1", model: String = "claude-opus-5-5", input: Int = 10,
                          output: Int = 20, cacheRead: Int = 0, cacheWrite: Int = 0, bashIDs: [String] = [],
                          sidechain: Bool = false, cwd: String = "/Users/x/Sites/anywhere") -> Data {
        let content: [[String: Any]] = bashIDs.isEmpty
            ? [["type": "text", "text": "hi"]]
            : bashIDs.map { ["type": "tool_use", "id": $0, "name": "Bash", "input": ["command": "ls"]] }
        let usage: [String: Any] = ["input_tokens": input, "output_tokens": output,
                                    "cache_read_input_tokens": cacheRead, "cache_creation_input_tokens": cacheWrite]
        let message: [String: Any] = ["id": messageID, "role": "assistant", "model": model, "content": content,
                                      "stop_reason": stop as Any? ?? NSNull(), "usage": usage]
        return encode(["type": "assistant", "timestamp": stamp(date), "sessionId": session, "cwd": cwd,
                       "isSidechain": sidechain, "requestId": requestID, "message": message])
    }
}
```

```swift
// FILE: NotchNookTests/Claude/ClaudeLogParserTests.swift
import XCTest
@testable import NotchNook

final class ClaudeLogParserTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func run(_ lines: [Data], state: inout ClaudeLogState) -> [ClaudeLogEvent] {
        lines.flatMap { ClaudeLogParser.parse($0, state: &state, now: at(999)) }
    }

    func testPromptOpensTurnAndAdoptsSessionAndProject() {
        var state = ClaudeLogState()
        let events = run([ClaudeFixtures.prompt(at: t0, session: "abc", cwd: "/Users/x/Sites/anywhere")], state: &state)
        XCTAssertEqual(events, [.turnBegan(t0)])
        XCTAssertTrue(state.turnOpen)
        XCTAssertEqual(state.session, "abc")
        XCTAssertEqual(state.project, "anywhere")
    }

    func testToolUseKeepsTurnOpenAndEndTurnClosesIt() {
        var state = ClaudeLogState()
        var events = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        events += run([ClaudeFixtures.assistant(at: at(2), stop: "tool_use", messageID: "m1")], state: &state)
        XCTAssertTrue(state.turnOpen)
        events += run([ClaudeFixtures.assistant(at: at(9), stop: "end_turn", messageID: "m2", requestID: "r2")], state: &state)
        XCTAssertFalse(state.turnOpen)
        XCTAssertTrue(events.contains(.turnActive(at(2))))
        XCTAssertTrue(events.contains(.turnEnded(at(9), completed: true)))
    }

    func testAssistantLineReportsUsageWithStableKey() {
        var state = ClaudeLogState()
        let line = ClaudeFixtures.assistant(at: t0, stop: "end_turn", messageID: "m9", requestID: "r9",
                                            input: 3, output: 7, cacheRead: 100, cacheWrite: 5)
        let events = run([line, line], state: &state)
        let usages = events.compactMap { event -> ClaudeUsageRecord? in
            if case .usage(let record) = event { return record }
            return nil
        }
        XCTAssertEqual(usages.count, 2)
        XCTAssertEqual(usages[0].key, usages[1].key)
        XCTAssertEqual(usages[0].key, "claude:m9:r9")
        XCTAssertEqual(usages[0].tokens, ClaudeTokens(input: 3, cacheWrite: 5, cacheRead: 100, output: 7))
        XCTAssertEqual(usages[0].model, "claude-opus-5-5")
    }

    func testInterruptClosesTurnAsIncomplete() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        let events = run([ClaudeFixtures.interrupt(at: at(5))], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(5), completed: false)])
        XCTAssertFalse(state.turnOpen)
    }

    func testInterruptTextQuotedInsideToolResultDoesNotEndTurn() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use", bashIDs: ["b1"])], state: &state)
        let quoted = ClaudeFixtures.toolResult(at: at(3), toolUseID: "b1", payload: "grep found [Request interrupted by user]")
        let events = run([quoted], state: &state)
        XCTAssertTrue(state.turnOpen)
        XCTAssertEqual(events, [.turnActive(at(3))])
    }

    func testToolResultAloneDoesNotOpenTurn() {
        var state = ClaudeLogState()
        let events = run([ClaudeFixtures.toolResult(at: t0, toolUseID: "x")], state: &state)
        XCTAssertEqual(events, [])
        XCTAssertFalse(state.turnOpen)
    }

    func testMetaPromptDoesNotOpenTurn() {
        var state = ClaudeLogState()
        XCTAssertEqual(run([ClaudeFixtures.prompt(at: t0, meta: true)], state: &state), [])
    }

    func testSidechainNeverOpensOrClosesButStillCountsUsage() {
        var state = ClaudeLogState()
        var events = run([ClaudeFixtures.prompt(at: t0, sidechain: true)], state: &state)
        XCTAssertEqual(events, [])
        events = run([ClaudeFixtures.assistant(at: at(1), stop: "end_turn", sidechain: true)], state: &state)
        XCTAssertEqual(events.count, 1)
        guard case .usage = events[0] else { return XCTFail("expected usage only") }
        XCTAssertFalse(state.turnOpen)
        // A sidechain end must not close a real open turn either.
        _ = run([ClaudeFixtures.prompt(at: at(2))], state: &state)
        _ = run([ClaudeFixtures.assistant(at: at(3), stop: "end_turn", messageID: "side", sidechain: true)], state: &state)
        XCTAssertTrue(state.turnOpen)
    }

    func testRunningBashIsTrackedUntilItsResult() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use", bashIDs: ["b1", "b2"])], state: &state)
        XCTAssertEqual(state.runningCommands, ["b1", "b2"])
        _ = run([ClaudeFixtures.toolResult(at: at(5), toolUseID: "b1")], state: &state)
        XCTAssertEqual(state.runningCommands, ["b2"])
    }

    func testLocalCommandOutputClosesTurnItOpened() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0, text: "<command-name>/cost</command-name>")], state: &state)
        let out = ClaudeFixtures.userBlocks(at: at(1), blocks: [["type": "text", "text": "<local-command-stdout>$1</local-command-stdout>"]])
        let events = run([out], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(1), completed: false)])
        XCTAssertFalse(state.turnOpen)
    }

    func testSyntheticErrorEndsTurnIncompleteWithoutUsage() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        let events = run([ClaudeFixtures.assistant(at: at(2), stop: "stop_sequence", model: "<synthetic>")], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(2), completed: false)])
    }

    func testHugeToolResultWhileTurnOpenIsNotDecoded() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use")], state: &state)
        let huge = ClaudeFixtures.toolResult(at: at(4), toolUseID: "z", payload: String(repeating: "x", count: 3_000_000))
        let started = Date()
        let events = run([huge], state: &state)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertEqual(events, [.turnActive(at(4))])
    }

    func testUnrelatedAndMalformedLinesAreIgnored() {
        var state = ClaudeLogState()
        XCTAssertEqual(run([Data(#"{"type":"system","x":1}"#.utf8), Data("not json".utf8),
                            Data(#"{"type":"assistant", broken"#.utf8)], state: &state), [])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeLogParserTests`. Expected: build FAILS ("cannot find 'ClaudeLogParser' in scope").

- [ ] **Step 3: Implement the parser**

```swift
// FILE: NotchNook/models/claude/ClaudeLogParser.swift
import Darwin
import Foundation

/// What one log line says, reduced to what the widget needs. Only usage
/// counters, model names, times and folder names leave a line; prompts,
/// replies and tool output are never kept.
enum ClaudeLogEvent: Equatable {
    case turnBegan(Date)
    /// Work continues; nil when the line was not worth decoding for its time.
    case turnActive(Date?)
    case turnEnded(Date, completed: Bool)
    case usage(ClaudeUsageRecord)
}

/// Per-file context carried from line to line.
struct ClaudeLogState: Equatable {
    var session = ""
    var project = ""
    var turnOpen = false
    /// Bash tool calls still waiting for a result. They run on the Mac, so a
    /// quiet log while one runs does not mean Claude stopped.
    var runningCommands: Set<String> = []
}

enum ClaudeLogParser {
    private static let interruptPrefix = "[Request interrupted by user"
    private static let localOutputPrefix = "<local-command-std"

    static func parse(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        if contains(line, #""type":"assistant""#) { return assistant(line, state: &state, now: now) }
        guard contains(line, #""type":"user""#) else { return [] }
        // A subagent's prompts and tool output never touch the parent turn,
        // and its tool output can be large: skip without decoding.
        if contains(line, #""isSidechain":true"#) { return [] }
        if state.turnOpen { return userInsideTurn(line, state: &state, now: now) }
        guard let json = object(line), json["type"] as? String == "user",
              json["isMeta"] as? Bool != true, isPrompt(json) else { return [] }
        adopt(json, into: &state)
        state.turnOpen = true
        state.runningCommands = []
        return [.turnBegan(timestamp(json["timestamp"]) ?? now)]
    }

    // MARK: Lines

    /// Tool results arrive inside a turn and can be many megabytes. They are
    /// decoded only when they could change something: an interruption, a local
    /// command's output, or the result of a Bash call being waited on.
    private static func userInsideTurn(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        let mayEnd = contains(line, interruptPrefix) || contains(line, localOutputPrefix)
        guard mayEnd || !state.runningCommands.isEmpty,
              let json = object(line), json["type"] as? String == "user" else {
            return [.turnActive(quickTimestamp(line))]
        }
        let date = timestamp(json["timestamp"]) ?? now
        // Only the person's own text counts; a tool result can quote the same words.
        if userTexts(json).contains(where: { $0.hasPrefix(interruptPrefix) || $0.hasPrefix(localOutputPrefix) }) {
            state.turnOpen = false
            state.runningCommands = []
            return [.turnEnded(date, completed: false)]
        }
        for id in toolResultIDs(json) { state.runningCommands.remove(id) }
        return [.turnActive(date)]
    }

    private static func assistant(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        guard let json = object(line), json["type"] as? String == "assistant",
              let message = json["message"] as? [String: Any] else { return [] }
        adopt(json, into: &state)
        let date = timestamp(json["timestamp"]) ?? now
        let model = message["model"] as? String ?? ""
        var events: [ClaudeLogEvent] = []
        if let usage = message["usage"] as? [String: Any], !model.isEmpty, !model.hasPrefix("<") {
            events.append(.usage(record(usage, json: json, message: message, model: model, date: date, state: state)))
        }
        // A subagent ending is not the end of the turn it serves.
        guard json["isSidechain"] as? Bool != true else { return events }
        switch message["stop_reason"] as? String {
        case "end_turn", "stop_sequence", "max_tokens", "refusal":
            // An error written in place of a reply, like a spent limit, stops
            // the turn without finishing it.
            let failed = json["isApiErrorMessage"] as? Bool == true || model.hasPrefix("<")
            if state.turnOpen { events.append(.turnEnded(date, completed: !failed)) }
            state.turnOpen = false
            state.runningCommands = []
        default:
            for block in message["content"] as? [[String: Any]] ?? []
            where block["type"] as? String == "tool_use" && block["name"] as? String == "Bash" {
                if let id = block["id"] as? String { state.runningCommands.insert(id) }
            }
            // Ahead of the usage so a reply that reopens the turn counts toward it.
            events.insert(state.turnOpen ? .turnActive(date) : .turnBegan(date), at: 0)
            state.turnOpen = true
        }
        return events
    }

    private static func record(_ usage: [String: Any], json: [String: Any], message: [String: Any],
                               model: String, date: Date, state: ClaudeLogState) -> ClaudeUsageRecord {
        let tokens = ClaudeTokens(input: int(usage["input_tokens"]),
                                  cacheWrite: int(usage["cache_creation_input_tokens"]),
                                  cacheRead: int(usage["cache_read_input_tokens"]),
                                  output: int(usage["output_tokens"]))
        let long = int((usage["cache_creation"] as? [String: Any])?["ephemeral_1h_input_tokens"])
        let id = message["id"] as? String ?? ""
        let request = json["requestId"] as? String ?? ""
        let key = id.isEmpty && request.isEmpty
            ? "claude:\(state.session):\(date.timeIntervalSince1970)" : "claude:\(id):\(request)"
        return ClaudeUsageRecord(key: key, date: date, model: model, project: state.project, tokens: tokens,
                                 longCacheWrite: min(long, tokens.cacheWrite))
    }

    // MARK: Prompt and content helpers

    /// A person's own prompt: text or an image, not a bare tool result, not
    /// command output, not an interruption marker.
    private static func isPrompt(_ json: [String: Any]) -> Bool {
        let content = (json["message"] as? [String: Any])?["content"]
        if let text = content as? String {
            return !text.isEmpty && !text.hasPrefix(interruptPrefix) && !text.hasPrefix(localOutputPrefix)
        }
        guard let blocks = content as? [[String: Any]] else { return false }
        let texts = userTexts(json)
        if texts.contains(where: { $0.hasPrefix(interruptPrefix) || $0.hasPrefix(localOutputPrefix) }) { return false }
        return blocks.contains { ["text", "image"].contains($0["type"] as? String ?? "") }
    }

    private static func userTexts(_ json: [String: Any]) -> [String] {
        let content = (json["message"] as? [String: Any])?["content"]
        if let text = content as? String { return [text] }
        guard let blocks = content as? [[String: Any]] else { return [] }
        return blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
    }

    private static func toolResultIDs(_ json: [String: Any]) -> [String] {
        let blocks = (json["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
        return blocks.compactMap { $0["type"] as? String == "tool_result" ? $0["tool_use_id"] as? String : nil }
    }

    private static func adopt(_ json: [String: Any], into state: inout ClaudeLogState) {
        if let session = json["sessionId"] as? String, !session.isEmpty { state.session = session }
        if let cwd = json["cwd"] as? String, !cwd.isEmpty { state.project = projectName(cwd) }
    }

    static func projectName(_ cwd: String) -> String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    // MARK: Decoding helpers

    /// Structural keys are written without spaces and never appear unescaped
    /// inside a string value, so a byte match is a safe first filter.
    private static func contains(_ line: Data, _ needle: String) -> Bool {
        let bytes = Array(needle.utf8)
        return line.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, raw.count >= bytes.count else { return false }
            return memmem(base, raw.count, bytes, bytes.count) != nil
        }
    }

    private static func object(_ line: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
    }

    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func timestamp(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return fractional.date(from: text) ?? plain.date(from: text)
    }

    /// The line's own time without decoding it, for lines too big to parse.
    static func quickTimestamp(_ line: Data) -> Date? {
        let key: StaticString = #""timestamp":""#
        return line.withUnsafeBytes { bytes -> Date? in
            guard let base = bytes.baseAddress,
                  let found = memmem(base, bytes.count, key.utf8Start, key.utf8CodeUnitCount) else { return nil }
            let start = base.distance(to: UnsafeRawPointer(found)) + key.utf8CodeUnitCount
            guard start + 24 <= bytes.count else { return nil }
            let text = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[start..<(start + 24)]), as: UTF8.self)
            return timestamp(text)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudeLogParserTests`. Expected: `TEST SUCCEEDED`, 12 cases passed. If `testHugeToolResultWhileTurnOpenIsNotDecoded` fails on the timing assertion, the byte filter is being bypassed: the tool result must hit the `[.turnActive(quickTimestamp(line))]` path without `object(line)`.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeLogParser.swift NotchNookTests/Claude/ClaudeFixtures.swift NotchNookTests/Claude/ClaudeLogParserTests.swift
git commit -m "feat(claude): log line parser with turn and usage events"
```

---

## Task 3: Turn tracker

**Files:**
- Create: `NotchNook/models/claude/ClaudeTurnTracker.swift`
- Test: `NotchNookTests/Claude/ClaudeTurnTrackerTests.swift`

**Interfaces:**
- Consumes: `ClaudeLogEvent` (Task 2).
- Produces: `ClaudeOpenTurn`, `ClaudeFinishedTurn(profileID:project:started:duration:completed:)`, `ClaudeTurnTracker` with `apply(_:key:profileID:project:busy:) -> ClaudeFinishedTurn?`, `closeIdle(now:) -> [ClaudeFinishedTurn]`, `openTurns: [ClaudeOpenTurn]`, constants `idleLimit` (10 min) and `busyLimit` (3 h).

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeTurnTrackerTests.swift
import XCTest
@testable import NotchNook

final class ClaudeTurnTrackerTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    private func apply(_ tracker: inout ClaudeTurnTracker, _ event: ClaudeLogEvent, key: String = "p|s1",
                       project: String = "anywhere", busy: Bool = false) -> ClaudeFinishedTurn? {
        tracker.apply(event, key: key, profileID: "p", project: project, busy: busy)
    }

    func testBeginThenEndReportsDurationAndCompletion() {
        var tracker = ClaudeTurnTracker()
        XCTAssertNil(apply(&tracker, .turnBegan(t0)))
        XCTAssertEqual(tracker.openTurns.count, 1)
        let done = apply(&tracker, .turnEnded(at(134), completed: true))
        XCTAssertEqual(done, ClaudeFinishedTurn(profileID: "p", project: "anywhere", started: t0, duration: 134, completed: true))
        XCTAssertTrue(tracker.openTurns.isEmpty)
    }

    func testEndWithoutBeginIsIgnored() {
        var tracker = ClaudeTurnTracker()
        XCTAssertNil(apply(&tracker, .turnEnded(at(5), completed: true)))
    }

    func testSecondBeginKeepsOriginalStart() {
        var tracker = ClaudeTurnTracker()
        _ = apply(&tracker, .turnBegan(t0))
        _ = apply(&tracker, .turnBegan(at(30)))
        XCTAssertEqual(tracker.openTurns.first?.started, t0)
    }

    func testSessionsTrackIndependently() {
        var tracker = ClaudeTurnTracker()
        _ = apply(&tracker, .turnBegan(t0), key: "p|a")
        _ = apply(&tracker, .turnBegan(at(1)), key: "p|b")
        XCTAssertEqual(tracker.openTurns.count, 2)
        XCTAssertNotNil(apply(&tracker, .turnEnded(at(9), completed: true), key: "p|a"))
        XCTAssertEqual(tracker.openTurns.map(\.key), ["p|b"])
    }

    func testActiveRefreshesLastActivity() {
        var tracker = ClaudeTurnTracker()
        _ = apply(&tracker, .turnBegan(t0))
        _ = apply(&tracker, .turnActive(at(50)))
        XCTAssertEqual(tracker.openTurns.first?.lastActivity, at(50))
        _ = apply(&tracker, .turnActive(nil))
        XCTAssertEqual(tracker.openTurns.first?.lastActivity, at(50))
    }

    func testIdleTurnIsClosedAsIncompleteButBusyTurnSurvives() {
        var tracker = ClaudeTurnTracker()
        _ = apply(&tracker, .turnBegan(t0), key: "p|idle")
        _ = apply(&tracker, .turnBegan(t0), key: "p|busy", busy: true)
        XCTAssertTrue(tracker.closeIdle(now: at(ClaudeTurnTracker.idleLimit - 1)).isEmpty)
        let closed = tracker.closeIdle(now: at(ClaudeTurnTracker.idleLimit + 1))
        XCTAssertEqual(closed.count, 1)
        XCTAssertFalse(closed[0].completed)
        XCTAssertEqual(tracker.openTurns.map(\.key), ["p|busy"])
        XCTAssertEqual(tracker.closeIdle(now: at(ClaudeTurnTracker.busyLimit + 1)).count, 1)
    }

    func testUsageEventsAreIgnored() {
        var tracker = ClaudeTurnTracker()
        let record = ClaudeUsageRecord(key: "k", date: t0, model: "m", project: "p", tokens: ClaudeTokens(), longCacheWrite: 0)
        XCTAssertNil(apply(&tracker, .usage(record)))
        XCTAssertTrue(tracker.openTurns.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeTurnTrackerTests`. Expected: build FAILS ("cannot find 'ClaudeTurnTracker' in scope").

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/claude/ClaudeTurnTracker.swift
import Foundation

struct ClaudeOpenTurn: Equatable {
    let key: String
    let profileID: String
    var project: String
    let started: Date
    var lastActivity: Date
    /// A Bash command is running, so a quiet log is expected.
    var busy: Bool
}

struct ClaudeFinishedTurn: Equatable {
    let profileID: String
    let project: String
    let started: Date
    let duration: TimeInterval
    /// False for interruptions, errors and turns closed for going quiet.
    let completed: Bool
}

/// Open turns across all profiles and sessions, keyed by `profileID|session`.
struct ClaudeTurnTracker {
    /// A turn with no new lines for this long is taken to be dead (crashed session).
    static let idleLimit: TimeInterval = 10 * 60
    /// Same, while a Bash command is still waiting for its result.
    static let busyLimit: TimeInterval = 3 * 3600

    private var open: [String: ClaudeOpenTurn] = [:]

    var openTurns: [ClaudeOpenTurn] { open.values.sorted { $0.started < $1.started } }

    mutating func apply(_ event: ClaudeLogEvent, key: String, profileID: String, project: String,
                        busy: Bool) -> ClaudeFinishedTurn? {
        switch event {
        case .turnBegan(let date):
            if var turn = open[key] {
                turn.lastActivity = max(turn.lastActivity, date)
                turn.busy = busy
                open[key] = turn
            } else {
                open[key] = ClaudeOpenTurn(key: key, profileID: profileID, project: project,
                                           started: date, lastActivity: date, busy: busy)
            }
        case .turnActive(let date):
            guard var turn = open[key] else { return nil }
            if let date { turn.lastActivity = max(turn.lastActivity, date) }
            if !project.isEmpty { turn.project = project }
            turn.busy = busy
            open[key] = turn
        case .turnEnded(let date, let completed):
            guard let turn = open.removeValue(forKey: key) else { return nil }
            return ClaudeFinishedTurn(profileID: turn.profileID, project: turn.project, started: turn.started,
                                      duration: max(0, date.timeIntervalSince(turn.started)), completed: completed)
        case .usage:
            break
        }
        return nil
    }

    mutating func closeIdle(now: Date) -> [ClaudeFinishedTurn] {
        var closed: [ClaudeFinishedTurn] = []
        for (key, turn) in open {
            let limit = turn.busy ? Self.busyLimit : Self.idleLimit
            guard now.timeIntervalSince(turn.lastActivity) > limit else { continue }
            open.removeValue(forKey: key)
            closed.append(ClaudeFinishedTurn(profileID: turn.profileID, project: turn.project, started: turn.started,
                                             duration: max(0, turn.lastActivity.timeIntervalSince(turn.started)),
                                             completed: false))
        }
        return closed
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudeTurnTrackerTests`. Expected: `TEST SUCCEEDED`, 7 cases.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeTurnTracker.swift NotchNookTests/Claude/ClaudeTurnTrackerTests.swift
git commit -m "feat(claude): turn tracker with idle close"
```

---

## Task 4: Usage ledger and session block

**Files:**
- Create: `NotchNook/models/claude/ClaudeUsageLedger.swift`
- Test: `NotchNookTests/Claude/ClaudeUsageLedgerTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageRecord`, `ClaudeUsageSummary`, `ClaudePricing` (Task 1).
- Produces: `ClaudeUsageLedger` (`add(_:)`, `prune(before:)`, `summary(since:) -> ClaudeUsageSummary`, `dates(since:) -> [Date]`, `static retention`); `ClaudeSessionBlock.currentStart(_ dates: [Date], now: Date) -> Date?`, `ClaudeSessionBlock.length`.

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeUsageLedgerTests.swift
import XCTest
@testable import NotchNook

final class ClaudeUsageLedgerTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    private func record(_ key: String, at date: Date, model: String = "claude-opus-5-5", input: Int = 0, output: Int = 0) -> ClaudeUsageRecord {
        ClaudeUsageRecord(key: key, date: date, model: model, project: "p",
                          tokens: ClaudeTokens(input: input, cacheWrite: 0, cacheRead: 0, output: output), longCacheWrite: 0)
    }

    func testStreamedDuplicatesKeepLargestCountsAndCountOnce() {
        var ledger = ClaudeUsageLedger()
        ledger.add(record("m1", at: t0, input: 1_000_000, output: 10))
        ledger.add(record("m1", at: t0, input: 1_000_000, output: 500_000))
        let summary = ledger.summary(since: t0.addingTimeInterval(-60))
        XCTAssertEqual(summary.requests, 1)
        XCTAssertEqual(summary.tokens.output, 500_000)
        // opus-5-5: $4 in + $20/MTok out * 0.5 = 4 + 10
        XCTAssertEqual(summary.cost, 14.0, accuracy: 1e-9)
        XCTAssertFalse(summary.hasUnpriced)
    }

    func testSummaryOnlyCountsRecordsSinceStart() {
        var ledger = ClaudeUsageLedger()
        ledger.add(record("old", at: at(-7200), input: 5))
        ledger.add(record("new", at: at(10), input: 7))
        XCTAssertEqual(ledger.summary(since: t0).tokens.input, 7)
    }

    func testUnknownModelCountsTokensButFlagsUnpriced() {
        var ledger = ClaudeUsageLedger()
        ledger.add(record("a", at: t0, model: "future-model", input: 100))
        let summary = ledger.summary(since: t0)
        XCTAssertEqual(summary.tokens.input, 100)
        XCTAssertEqual(summary.cost, 0)
        XCTAssertTrue(summary.hasUnpriced)
    }

    func testPruneDropsOldRecords() {
        var ledger = ClaudeUsageLedger()
        ledger.add(record("old", at: at(-100_000)))
        ledger.add(record("new", at: at(0)))
        ledger.prune(before: at(-1000))
        XCTAssertEqual(ledger.dates(since: at(-200_000)).count, 1)
    }

    func testSessionBlockStartsAtFirstRequestHourAndEndsAfterFiveHours() {
        let dates = [at(20 * 60), at(60 * 60), at(5 * 3600 + 30 * 60)]   // 10:20, 11:00, 15:30
        XCTAssertEqual(ClaudeSessionBlock.currentStart(dates, now: at(5 * 3600 + 40 * 60)), at(5 * 3600))   // 15:00 block
        XCTAssertEqual(ClaudeSessionBlock.currentStart(Array(dates.prefix(2)), now: at(2 * 3600)), t0)      // 10:00 block
    }

    func testSessionBlockIsNilOnceFiveHoursPass() {
        XCTAssertNil(ClaudeSessionBlock.currentStart([at(20 * 60)], now: at(5 * 3600 + 1)))
        XCTAssertNil(ClaudeSessionBlock.currentStart([], now: t0))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeUsageLedgerTests`. Expected: build FAILS ("cannot find 'ClaudeUsageLedger' in scope").

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/claude/ClaudeUsageLedger.swift
import Foundation

/// De-duplicated usage records for one profile.
struct ClaudeUsageLedger {
    /// Enough for today's total plus the current 5-hour session block.
    static let retention: TimeInterval = 36 * 3600

    private var records: [String: ClaudeUsageRecord] = [:]

    mutating func add(_ record: ClaudeUsageRecord) {
        guard var existing = records[record.key] else {
            records[record.key] = record
            return
        }
        existing.tokens = existing.tokens.merged(with: record.tokens)
        existing.longCacheWrite = max(existing.longCacheWrite, record.longCacheWrite)
        records[record.key] = existing
    }

    mutating func prune(before cutoff: Date) {
        records = records.filter { $0.value.date >= cutoff }
    }

    func dates(since start: Date) -> [Date] {
        records.values.filter { $0.date >= start }.map(\.date)
    }

    func summary(since start: Date) -> ClaudeUsageSummary {
        var summary = ClaudeUsageSummary()
        for record in records.values where record.date >= start {
            summary.requests += 1
            summary.tokens += record.tokens
            if let cost = ClaudePricing.cost(record.tokens, longCacheWrite: record.longCacheWrite, model: record.model) {
                summary.cost += cost
            } else {
                summary.hasUnpriced = true
            }
        }
        return summary
    }
}

/// Claude's plan session is a five-hour window that begins with the first
/// request, on the hour. The logs place it; the desktop app's file only
/// reports percentages.
enum ClaudeSessionBlock {
    static let length: TimeInterval = 5 * 3600
    static let lookback: TimeInterval = 12 * 3600

    /// The start of the block holding `now`; nil when the last one has ended.
    static func currentStart(_ dates: [Date], now: Date) -> Date? {
        var start: Date?
        for date in dates.sorted() where date <= now {
            if let current = start, date < current.addingTimeInterval(length) { continue }
            start = hour(of: date)
        }
        guard let start, now < start.addingTimeInterval(length) else { return nil }
        return start
    }

    /// Allowances renew on the hour in UTC.
    static func hour(of date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudeUsageLedgerTests`. Expected: `TEST SUCCEEDED`, 6 cases.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeUsageLedger.swift NotchNookTests/Claude/ClaudeUsageLedgerTests.swift
git commit -m "feat(claude): usage ledger and session block"
```

---

## Task 5: Plan limits from the desktop app

**Files:**
- Create: `NotchNook/models/claude/ClaudePlanLimits.swift`
- Test: `NotchNookTests/Claude/ClaudePlanLimitsTests.swift`

**Interfaces:**
- Consumes: `ClaudeLimitWindow` (Task 1), `ClaudeSessionBlock` (Task 4).
- Produces: `ClaudePlanLimits.Sample(date:organization:session:weekly:)`, `ClaudePlanLimits.historyURL(home:) -> URL`, `ClaudePlanLimits.samples(from: Data) -> [Sample]?`, `ClaudePlanLimits.windows(from:organization:sessionStart:now:) -> [ClaudeLimitWindow]`.

File format (verified on this Mac): `~/Library/Application Support/Claude/plan-usage-history.json` = `{"version":2,"samples":[{"t":<ms>,"org":"<uuid>","u":{"fh":21,"sd":13}}]}`. `fh` = 5-hour session percent used, `sd` = weekly percent used. Version 1 keeps `fh`/`sd` beside `t` without `u`. Any other version is ignored.

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudePlanLimitsTests.swift
import XCTest
@testable import NotchNook

final class ClaudePlanLimitsTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }
    private func sample(_ s: TimeInterval, org: String? = "personal", session: Double? = nil, weekly: Double? = nil) -> ClaudePlanLimits.Sample {
        ClaudePlanLimits.Sample(date: at(s), organization: org, session: session, weekly: weekly)
    }

    func testParsesVersionTwoAndOne() {
        let v2 = #"{"version":2,"samples":[{"t":1791981399240,"org":"o1","u":{"fh":21,"sd":13}},{"t":1791981000000,"org":"o1","u":{"fh":150}}]}"#
        let samples = ClaudePlanLimits.samples(from: Data(v2.utf8))
        XCTAssertEqual(samples?.count, 2)
        XCTAssertEqual(samples?.first?.session, 100, "clamped to 100 and sorted oldest first")
        XCTAssertEqual(samples?.last?.weekly, 13)
        XCTAssertEqual(samples?.last?.organization, "o1")
        let v1 = #"{"version":1,"samples":[{"t":1791981399240,"fh":5,"sd":6}]}"#
        XCTAssertEqual(ClaudePlanLimits.samples(from: Data(v1.utf8))?.first?.weekly, 6)
    }

    func testUnknownVersionOrGarbageIsIgnored() {
        XCTAssertNil(ClaudePlanLimits.samples(from: Data(#"{"version":9,"samples":[]}"#.utf8)))
        XCTAssertNil(ClaudePlanLimits.samples(from: Data("nope".utf8)))
        XCTAssertNil(ClaudePlanLimits.samples(from: Data(repeating: 0x20, count: (4 << 20) + 1)))
    }

    func testOtherAccountsSamplesAreNeverShown() {
        let samples = [sample(0, org: "personal", session: 20, weekly: 10)]
        XCTAssertEqual(ClaudePlanLimits.windows(from: samples, organization: "work", sessionStart: nil, now: at(60)), [])
        XCTAssertEqual(ClaudePlanLimits.windows(from: samples, organization: nil, sessionStart: nil, now: at(60)), [])
    }

    func testSessionResetFromLogsIsExact() {
        let samples = [sample(0, session: 20, weekly: 10)]
        let windows = ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: t0, now: at(600))
        let session = windows.first { $0.kind == .session }
        XCTAssertEqual(session?.usedPercent, 20)
        XCTAssertEqual(session?.resetsAt, at(5 * 3600))
        XCTAssertEqual(session?.isEstimate, false)
    }

    func testSessionResetWithoutLogsIsEstimatedFromFirstReadingAboveZero() {
        let samples = [sample(0, session: 0), sample(300, session: 5), sample(600, session: 8)]
        let session = ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: nil, now: at(900))
            .first { $0.kind == .session }
        XCTAssertEqual(session?.resetsAt, at(300 + 5 * 3600))
        XCTAssertEqual(session?.isEstimate, true)
    }

    func testRenewedSessionIsDropped() {
        let samples = [sample(0, session: 40)]
        XCTAssertNil(ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: nil, now: at(5 * 3600 + 10))
            .first { $0.kind == .session })
    }

    func testWeeklyRenewalComesFromLastDropAndRollsForward() {
        let samples = [sample(0, weekly: 80), sample(3600, weekly: 3), sample(7200, weekly: 4)]
        let weekly = ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: nil, now: at(7300))
            .first { $0.kind == .weekly }
        XCTAssertEqual(weekly?.resetsAt, at(3600 + 7 * 86_400))
        XCTAssertEqual(weekly?.isEstimate, true)
    }

    func testWeeklyWithoutKnownRenewalIsHiddenOnceStale() {
        let samples = [sample(0, weekly: 30)]
        XCTAssertNotNil(ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: nil, now: at(3600)).first)
        XCTAssertTrue(ClaudePlanLimits.windows(from: samples, organization: "personal", sessionStart: nil, now: at(86_400 + 1)).isEmpty)
    }

    func testHistoryURL() {
        let home = URL(fileURLWithPath: "/Users/x")
        XCTAssertEqual(ClaudePlanLimits.historyURL(home: home).path, "/Users/x/Library/Application Support/Claude/plan-usage-history.json")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudePlanLimitsTests`. Expected: build FAILS ("cannot find 'ClaudePlanLimits' in scope").

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/claude/ClaudePlanLimits.swift
import Foundation

/// The Claude desktop app checks the plan's limits itself and keeps a history
/// of percentages on this Mac. Only that file is read: no sign-in, no network.
/// The format is the app's own, so an unknown version is left out, not guessed.
enum ClaudePlanLimits {
    static let sessionLength: TimeInterval = 5 * 3600
    static let weekLength: TimeInterval = 7 * 86_400
    private static let maximumSize = 4 << 20

    struct Sample: Equatable {
        let date: Date
        let organization: String?
        /// Percent of the 5-hour session spent (`fh`).
        let session: Double?
        /// Percent of the weekly allowance spent (`sd`).
        let weekly: Double?
    }

    static func historyURL(home: URL) -> URL {
        home.appending(path: "Library/Application Support/Claude/plan-usage-history.json", directoryHint: .notDirectory)
    }

    /// Readings oldest first; nil for a file this reader does not know.
    static func samples(from data: Data) -> [Sample]? {
        guard data.count <= maximumSize,
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = (json["version"] as? NSNumber)?.intValue, version == 1 || version == 2,
              let entries = json["samples"] as? [[String: Any]] else { return nil }
        var result: [Sample] = []
        for entry in entries {
            guard let milliseconds = (entry["t"] as? NSNumber)?.doubleValue, milliseconds.isFinite, milliseconds > 0 else { continue }
            // The first version kept its windows beside the time.
            let values = version == 1 ? entry : (entry["u"] as? [String: Any] ?? [:])
            result.append(Sample(date: Date(timeIntervalSince1970: milliseconds / 1_000),
                                 organization: entry["org"] as? String,
                                 session: percent(values["fh"]), weekly: percent(values["sd"])))
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func percent(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { return nil }
        return min(100, max(0, number.doubleValue))
    }

    /// The latest reading for `organization` as limit windows. Samples from any
    /// other account are ignored: the app may be signed in to another one.
    static func windows(from samples: [Sample], organization: String?, sessionStart: Date?, now: Date) -> [ClaudeLimitWindow] {
        guard let organization else { return [] }
        let history = samples.filter { $0.organization == organization }.sorted { $0.date < $1.date }
        guard let latest = history.last, latest.date <= now.addingTimeInterval(300),
              now.timeIntervalSince(latest.date) < weekLength else { return [] }
        let age = now.timeIntervalSince(latest.date)
        var result: [ClaudeLimitWindow] = []

        // An old reading says nothing about a session that renewed since.
        if let used = latest.session, age < sessionLength {
            let reset = sessionReset(history, used: used, sessionStart: sessionStart)
            if reset.date.map({ $0 > now }) ?? true {
                result.append(ClaudeLimitWindow(kind: .session, usedPercent: used, resetsAt: reset.date, isEstimate: reset.isEstimate))
            }
        }
        if let used = latest.weekly {
            let renewal = weeklyRenewal(history, now: now)
            // Without a renewal date, a day-old week may have renewed.
            if renewal != nil || age < 86_400 {
                result.append(ClaudeLimitWindow(kind: .weekly, usedPercent: used, resetsAt: renewal, isEstimate: renewal != nil))
            }
        }
        return result
    }

    private static func sessionReset(_ history: [Sample], used: Double, sessionStart: Date?) -> (date: Date?, isEstimate: Bool) {
        guard used > 0 else { return (nil, false) }
        if let sessionStart { return (sessionStart.addingTimeInterval(sessionLength), false) }
        // The run of readings above zero that ends with the latest one: the
        // first of them is the latest the session can have begun.
        var index = history.count - 1
        while index > 0, let before = history[index - 1].session, before > 0,
              before <= (history[index].session ?? 0) + 1,
              history[index].date.timeIntervalSince(history[index - 1].date) < sessionLength {
            index -= 1
        }
        return (history[index].date.addingTimeInterval(sessionLength), true)
    }

    /// The next renewal after the last drop the history saw, rolled forward by weeks.
    private static func weeklyRenewal(_ history: [Sample], now: Date) -> Date? {
        guard history.count > 1 else { return nil }
        for index in stride(from: history.count - 1, to: 0, by: -1) {
            guard let before = history[index - 1].weekly, let after = history[index].weekly, after + 1 < before else { continue }
            var next = history[index].date.addingTimeInterval(weekLength)
            while next <= now { next.addTimeInterval(weekLength) }
            return next
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudePlanLimitsTests`. Expected: `TEST SUCCEEDED`, 9 cases.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudePlanLimits.swift NotchNookTests/Claude/ClaudePlanLimitsTests.swift
git commit -m "feat(claude): plan limits from the desktop app history"
```

---

## Task 6: Profile discovery and file tailer

**Files:**
- Create: `NotchNook/models/claude/ClaudeProfile.swift`, `NotchNook/models/claude/ClaudeLogTailer.swift`
- Modify: `NotchNookTests/Claude/ClaudeFixtures.swift` (append temp-dir helpers)
- Test: `NotchNookTests/Claude/ClaudeProfileTests.swift`, `NotchNookTests/Claude/ClaudeLogTailerTests.swift`

**Interfaces:**
- Consumes: `ClaudeLogState` (Task 2).
- Produces: `ClaudeProfile(id:label:roots:organization:)`; `ClaudeProfileDiscovery.discover(home:) -> [ClaudeProfile]`, `.label(forDirectoryNamed:)`, `.organization(inJSONAt:)`; `ClaudeLogCursor(offset:partial:state:)`; `ClaudeLogTailer.readNewLines(at:cursor:) -> [Data]`; fixture helpers `makeTemporaryDirectory()`, `writeAccountJSON(org:to:)`, `append(_:to:)`.

Verified on this Mac: the default profile's account file is `~/.claude.json` (inside home, not inside `~/.claude`), a `CLAUDE_CONFIG_DIR` profile keeps `<dir>/.claude.json`, and the org is at `oauthAccount.organizationUuid`.

- [ ] **Step 1: Write the failing tests**

Append to `ClaudeFixtures`:

```swift
// Append inside `enum ClaudeFixtures { … }` in NotchNookTests/Claude/ClaudeFixtures.swift
    static func makeTemporaryDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(path: "claude-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeAccountJSON(org: String, to url: URL) {
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let json = #"{"oauthAccount":{"organizationUuid":"\#(org)","emailAddress":"x@example.com"}}"#
        try! Data(json.utf8).write(to: url)
    }

    /// Appends lines, each followed by a newline, creating folders and the file as needed.
    static func append(_ lines: [Data], to url: URL) {
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        let handle = try! FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try! handle.seekToEnd()
        for line in lines {
            try! handle.write(contentsOf: line)
            try! handle.write(contentsOf: Data("\n".utf8))
        }
    }
```

```swift
// FILE: NotchNookTests/Claude/ClaudeProfileTests.swift
import XCTest
@testable import NotchNook

final class ClaudeProfileTests: XCTestCase {
    private var home: URL!

    override func setUp() { home = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: home) }

    private func makeProjects(_ dir: String) {
        try! FileManager.default.createDirectory(at: home.appending(path: "\(dir)/projects"), withIntermediateDirectories: true)
    }

    func testLabelsComeFromFolderSuffixNeverOrgNames() {
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude"), "Work")
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude-personal"), "Personal")
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude-side-project"), "Side-project")
    }

    func testDiscoversDefaultAndPersonalWithTheirOwnOrganizations() {
        makeProjects(".claude")
        makeProjects(".claude-personal")
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: home.appending(path: ".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: home.appending(path: ".claude-personal/.claude.json"))

        let profiles = ClaudeProfileDiscovery.discover(home: home)

        XCTAssertEqual(profiles.map(\.label), ["Work", "Personal"])
        XCTAssertEqual(profiles.map(\.organization), ["org-work", "org-personal"])
        XCTAssertEqual(profiles[0].roots.count, 1)
        XCTAssertEqual(Set(profiles.map(\.id)).count, 2)
    }

    func testDefaultProfileAlsoWatchesXDGConfigRoot() {
        makeProjects(".claude")
        try! FileManager.default.createDirectory(at: home.appending(path: ".config/claude/projects"), withIntermediateDirectories: true)
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home)[0].roots.count, 2)
    }

    func testFoldersWithoutProjectsAreIgnored() {
        makeProjects(".claude")
        try! FileManager.default.createDirectory(at: home.appending(path: ".claude-empty"), withIntermediateDirectories: true)
        try! Data("{}".utf8).write(to: home.appending(path: ".claude.json.backup"))
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home).map(\.label), ["Work"])
    }

    func testNoClaudeAtAllMeansNoProfiles() {
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home), [])
    }

    func testMissingOrGarbageAccountFileMeansNoOrganization() {
        makeProjects(".claude")
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
        try! Data("not json".utf8).write(to: home.appending(path: ".claude.json"))
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
        try! Data(#"{"oauthAccount":{}}"#.utf8).write(to: home.appending(path: ".claude.json"))
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
    }
}
```

```swift
// FILE: NotchNookTests/Claude/ClaudeLogTailerTests.swift
import XCTest
@testable import NotchNook

final class ClaudeLogTailerTests: XCTestCase {
    private var dir: URL!
    private var file: URL { dir.appending(path: "log.jsonl") }

    override func setUp() { dir = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func text(_ lines: [Data]) -> [String] { lines.map { String(decoding: $0, as: UTF8.self) } }

    func testReadsCompleteLinesOnceAndOnlyNewOnesAfter() {
        var cursor = ClaudeLogCursor()
        ClaudeFixtures.append([Data("one".utf8), Data("two".utf8)], to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["one", "two"])
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        ClaudeFixtures.append([Data("three".utf8)], to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["three"])
    }

    func testLineWrittenInPiecesIsHeldUntilItsNewline() {
        var cursor = ClaudeLogCursor()
        let handle: FileHandle = {
            FileManager.default.createFile(atPath: file.path, contents: nil)
            return try! FileHandle(forWritingTo: file)
        }()
        defer { try? handle.close() }
        try! handle.write(contentsOf: Data("{\"type\":\"assis".utf8))
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        try! handle.write(contentsOf: Data("tant\"}\n".utf8))
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["{\"type\":\"assistant\"}"])
    }

    func testTruncatedFileResetsCursorAndRereads() {
        var cursor = ClaudeLogCursor()
        ClaudeFixtures.append([Data("a-long-first-line".utf8), Data("second".utf8)], to: file)
        _ = ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)
        cursor.state.turnOpen = true
        try! Data("new\n".utf8).write(to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["new"])
        XCTAssertFalse(cursor.state.turnOpen, "a rotated file must not inherit the old turn")
    }

    func testBlankLinesAreSkippedAndMissingFileIsEmpty() {
        var cursor = ClaudeLogCursor()
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        try! Data("a\n\n\nb\n".utf8).write(to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["a", "b"])
    }

    func testLineLargerThanOneChunkIsReadIntact() {
        var cursor = ClaudeLogCursor()
        let big = String(repeating: "x", count: ClaudeLogTailer.chunkSize + 123_456)
        ClaudeFixtures.append([Data(big.utf8), Data("tail".utf8)], to: file)
        let lines = ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, big.utf8.count)
        XCTAssertEqual(String(decoding: lines[1], as: UTF8.self), "tail")
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run the one-class test command for `ClaudeProfileTests` then `ClaudeLogTailerTests`. Expected: build FAILS (missing `ClaudeProfileDiscovery`, `ClaudeLogCursor`).

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/claude/ClaudeProfile.swift
import Foundation

/// One Claude config directory: where its session logs live and which
/// account it is signed in to.
struct ClaudeProfile: Equatable, Identifiable {
    /// The config directory path.
    let id: String
    let label: String
    /// Existing `projects` folders to watch.
    let roots: [URL]
    /// The account's organization, when its profile file says.
    let organization: String?
}

enum ClaudeProfileDiscovery {
    private static let maximumProfileFileSize = 16 << 20

    /// `.claude` is the work profile on this setup; `.claude-foo` is "Foo".
    /// Never the org name: a personal account's can be a private-relay address.
    static func label(forDirectoryNamed name: String) -> String {
        guard name.hasPrefix(".claude-") else { return "Work" }
        let suffix = String(name.dropFirst(".claude-".count))
        guard let first = suffix.first else { return "Claude" }
        return first.uppercased() + suffix.dropFirst()
    }

    /// The default profile first, then every `~/.claude-*` folder that has
    /// session logs (the usual home of a `CLAUDE_CONFIG_DIR` alias).
    static func discover(home: URL, fileManager: FileManager = .default) -> [ClaudeProfile] {
        var profiles: [ClaudeProfile] = []

        let defaultRoots = [".claude/projects", ".config/claude/projects"]
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { isDirectory($0, fileManager) }
            .map { $0.resolvingSymlinksInPath() }
        if !defaultRoots.isEmpty {
            profiles.append(ClaudeProfile(id: home.appending(path: ".claude").path,
                                          label: label(forDirectoryNamed: ".claude"), roots: defaultRoots,
                                          organization: organization(inJSONAt: home.appending(path: ".claude.json"))))
        }

        let names = (try? fileManager.contentsOfDirectory(atPath: home.path)) ?? []
        for name in names.sorted() where name.hasPrefix(".claude-") {
            let directory = home.appending(path: name, directoryHint: .isDirectory)
            let projects = directory.appending(path: "projects", directoryHint: .isDirectory)
            guard isDirectory(projects, fileManager) else { continue }
            profiles.append(ClaudeProfile(id: directory.path, label: label(forDirectoryNamed: name),
                                          roots: [projects.resolvingSymlinksInPath()],
                                          organization: organization(inJSONAt: directory.appending(path: ".claude.json"))))
        }
        return profiles
    }

    /// `oauthAccount.organizationUuid`, and nothing else from the file.
    static func organization(inJSONAt url: URL) -> String? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= maximumProfileFileSize,
              let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let account = json["oauthAccount"] as? [String: Any],
              let organization = account["organizationUuid"] as? String, !organization.isEmpty else { return nil }
        return organization
    }

    private static func isDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
        var directory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }
}
```

```swift
// FILE: NotchNook/models/claude/ClaudeLogTailer.swift
import Foundation

/// Where reading a log stopped, and what the parser knew there.
struct ClaudeLogCursor {
    var offset: UInt64 = 0
    /// The unfinished last line, held until its newline is written.
    var partial = Data()
    var state = ClaudeLogState()
}

enum ClaudeLogTailer {
    static let chunkSize = 4 << 20

    /// The complete lines written since the cursor, in order. A file smaller
    /// than the cursor was rotated or truncated: the cursor starts over.
    static func readNewLines(at url: URL, cursor: inout ClaudeLogCursor) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [] }
        if size < cursor.offset { cursor = ClaudeLogCursor() }
        guard size > cursor.offset else { return [] }
        do { try handle.seek(toOffset: cursor.offset) } catch { return [] }

        var lines: [Data] = []
        var buffer = cursor.partial
        var position = cursor.offset
        while position < size {
            let wanted = Int(min(UInt64(chunkSize), size - position))
            guard let chunk = try? handle.read(upToCount: wanted), !chunk.isEmpty else { break }
            position += UInt64(chunk.count)
            buffer.append(chunk)
            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                if newline > lineStart { lines.append(Data(buffer[lineStart..<newline])) }
                lineStart = buffer.index(after: newline)
            }
            buffer = Data(buffer[lineStart...])
        }
        cursor.offset = position
        cursor.partial = buffer
        return lines
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command for each of `ClaudeProfileTests` (6 cases) and `ClaudeLogTailerTests` (5 cases). Expected: `TEST SUCCEEDED` for both.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeProfile.swift NotchNook/models/claude/ClaudeLogTailer.swift NotchNookTests/Claude/ClaudeFixtures.swift NotchNookTests/Claude/ClaudeProfileTests.swift NotchNookTests/Claude/ClaudeLogTailerTests.swift
git commit -m "feat(claude): profile discovery and incremental log tailer"
```

---

## Task 7: Polling engine

**Files:**
- Create: `NotchNook/models/claude/ClaudeUsageEngine.swift`
- Test: `NotchNookTests/Claude/ClaudeUsageEngineTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: `final class ClaudeUsageEngine { init(home: URL); func poll(now: Date = Date()) -> Output }` with `Output { profiles: [ClaudeProfileSnapshot]; finished: [ClaudeFinishedTurn] }`. The first `poll` primes from today's history and returns no `finished`. Confined to one thread/queue by its caller.

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeUsageEngineTests.swift
import XCTest
@testable import NotchNook

final class ClaudeUsageEngineTests: XCTestCase {
    private var home: URL!
    private let now = Date()

    override func setUp() { home = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: home) }

    private func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }
    private func log(_ relative: String) -> URL { home.appending(path: relative) }
    private let work = ".claude/projects/-Users-x-Sites-anywhere/s1.jsonl"

    private func makeProjects(_ dir: String) {
        try! FileManager.default.createDirectory(at: home.appending(path: "\(dir)/projects"), withIntermediateDirectories: true)
    }

    private func snapshot(_ output: ClaudeUsageEngine.Output, _ label: String) -> ClaudeProfileSnapshot? {
        output.profiles.first { $0.label == label }
    }

    func testPrimingReplaysHistoryWithoutAnnouncingAndStillTotalsIt() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(300)),
                               ClaudeFixtures.assistant(at: ago(200), stop: "end_turn", input: 1_000, output: 500)], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(output.finished, [], "history replayed at launch must never alert")
        XCTAssertEqual(snapshot(output, "Work")?.today.requests, 1)
        XCTAssertEqual(snapshot(output, "Work")?.today.tokens.output, 500)
        XCTAssertEqual(snapshot(output, "Work")?.live, [])
    }

    func testTurnAlreadyRunningAtLaunchShowsAsWorking() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(40)),
                               ClaudeFixtures.assistant(at: ago(20), stop: "tool_use")], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(output.finished, [])
        let live = snapshot(output, "Work")?.live
        XCTAssertEqual(live?.count, 1)
        XCTAssertEqual(live?.first?.project, "anywhere")
        XCTAssertEqual(live?.first?.profileLabel, "Work")
    }

    func testStaleOpenTurnFromHistoryIsDroppedSilently() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(3_600))], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(snapshot(output, "Work")?.live, [])
        XCTAssertEqual(output.finished, [])
    }

    func testTurnFinishingAfterLaunchAnnouncesOnce() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        XCTAssertEqual(engine.poll(now: ago(30)).finished, [])

        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20))], to: log(work))
        let working = engine.poll(now: ago(19))
        XCTAssertEqual(snapshot(working, "Work")?.live.count, 1)
        XCTAssertEqual(working.finished, [])

        ClaudeFixtures.append([ClaudeFixtures.assistant(at: ago(5), stop: "end_turn")], to: log(work))
        let done = engine.poll(now: ago(4))
        XCTAssertEqual(done.finished.count, 1)
        XCTAssertTrue(done.finished[0].completed)
        XCTAssertEqual(done.finished[0].project, "anywhere")
        XCTAssertEqual(done.finished[0].duration, 15, accuracy: 0.01)
        XCTAssertEqual(snapshot(done, "Work")?.live, [])
        XCTAssertEqual(engine.poll(now: now).finished, [], "an announced turn is not announced again")
    }

    func testInterruptedTurnIsReportedIncomplete() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        _ = engine.poll(now: ago(30))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20)), ClaudeFixtures.interrupt(at: ago(10))], to: log(work))
        let output = engine.poll(now: ago(9))
        XCTAssertEqual(output.finished.count, 1)
        XCTAssertFalse(output.finished[0].completed)
    }

    func testSubagentFilesCountTokensButNeverOpenOrCloseTheParentTurn() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        _ = engine.poll(now: ago(30))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20))], to: log(work))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(15), sidechain: true),
                               ClaudeFixtures.assistant(at: ago(10), stop: "end_turn", messageID: "side", input: 77, sidechain: true)],
                              to: log(".claude/projects/-Users-x-Sites-anywhere/s1/subagents/agent-1.jsonl"))
        let output = engine.poll(now: ago(9))
        XCTAssertEqual(output.finished, [])
        XCTAssertEqual(snapshot(output, "Work")?.live.count, 1, "the parent turn is still running")
        XCTAssertEqual(snapshot(output, "Work")?.today.tokens.input, 77)
    }

    func testPersonalLimitsAttachOnlyToThePersonalProfile() {
        makeProjects(".claude")
        makeProjects(".claude-personal")
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: log(".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: log(".claude-personal/.claude.json"))
        let sampleMs = Int(ago(60).timeIntervalSince1970 * 1_000)
        let history = #"{"version":2,"samples":[{"t":\#(sampleMs),"org":"org-personal","u":{"fh":21,"sd":13}}]}"#
        let planURL = ClaudePlanLimits.historyURL(home: home)
        try! FileManager.default.createDirectory(at: planURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(history.utf8).write(to: planURL)

        let output = ClaudeUsageEngine(home: home).poll(now: now)

        XCTAssertEqual(output.profiles.map(\.label), ["Work", "Personal"])
        XCTAssertEqual(snapshot(output, "Work")?.limits, [])
        XCTAssertEqual(snapshot(output, "Personal")?.limits.map(\.kind), [.session, .weekly])
        XCTAssertEqual(snapshot(output, "Personal")?.limits.first?.usedPercent, 21)
    }

    func testUnknownOrMissingAccountOrHistoryMeansNoLimitsNotACrash() {
        makeProjects(".claude")
        try! Data("garbage".utf8).write(to: log(".claude.json"))
        let planURL = ClaudePlanLimits.historyURL(home: home)
        try! FileManager.default.createDirectory(at: planURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(#"{"version":99}"#.utf8).write(to: planURL)
        XCTAssertEqual(snapshot(ClaudeUsageEngine(home: home).poll(now: now), "Work")?.limits, [])
    }

    func testTwoProfilesKeepSeparateTurns() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(10), session: "w")], to: log(".claude/projects/-a/w.jsonl"))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(8), session: "p")], to: log(".claude-personal/projects/-b/p.jsonl"))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(snapshot(output, "Work")?.live.count, 1)
        XCTAssertEqual(snapshot(output, "Personal")?.live.count, 1)
    }

    func testFilesNotTouchedTodayAreNotRead() throws {
        let old = log(work)
        ClaudeFixtures.append([ClaudeFixtures.assistant(at: ago(5 * 86_400), stop: "end_turn", input: 999)], to: old)
        try FileManager.default.setAttributes([.modificationDate: ago(5 * 86_400)], ofItemAtPath: old.path)
        XCTAssertEqual(snapshot(ClaudeUsageEngine(home: home).poll(now: now), "Work")?.today.requests, 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeUsageEngineTests`. Expected: build FAILS ("cannot find 'ClaudeUsageEngine' in scope").

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/claude/ClaudeUsageEngine.swift
import Foundation

/// Reads Claude Code's session logs where they are, incrementally, and turns
/// them into per-profile snapshots and finished turns. Synchronous and free
/// of timers and UI so it can be tested against a temporary home folder; the
/// caller owns the thread and calls `poll` every couple of seconds.
final class ClaudeUsageEngine {
    struct Output {
        var profiles: [ClaudeProfileSnapshot]
        var finished: [ClaudeFinishedTurn]
    }

    static let discoveryInterval: TimeInterval = 60

    private let home: URL
    private var profiles: [ClaudeProfile] = []
    private var lastDiscovery = Date.distantPast
    private var cursors: [String: ClaudeLogCursor] = [:]
    private var tracker = ClaudeTurnTracker()
    private var ledgers: [String: ClaudeUsageLedger] = [:]
    private var planSamples: [ClaudePlanLimits.Sample] = []
    private var planModified: Date?
    private var primed = false

    init(home: URL) {
        self.home = home
    }

    /// The first call reads today's history and reports nothing as finished, so
    /// replayed turns never alert; a turn still running then shows as working.
    func poll(now: Date = Date()) -> Output {
        refreshProfiles(now: now)
        refreshPlanHistory()
        let dayStart = Calendar.current.startOfDay(for: now)
        var finished: [ClaudeFinishedTurn] = []

        for profile in profiles {
            for file in logFiles(in: profile, modifiedSince: dayStart) {
                var cursor = cursors[file.url.path] ?? ClaudeLogCursor()
                guard file.size != cursor.offset else { continue }
                for line in ClaudeLogTailer.readNewLines(at: file.url, cursor: &cursor) {
                    for event in ClaudeLogParser.parse(line, state: &cursor.state, now: now) {
                        if case .usage(let record) = event { ledgers[profile.id, default: ClaudeUsageLedger()].add(record) }
                        let key = profile.id + "|" + cursor.state.session
                        if let done = tracker.apply(event, key: key, profileID: profile.id, project: cursor.state.project,
                                                    busy: !cursor.state.runningCommands.isEmpty) {
                            finished.append(done)
                        }
                    }
                }
                cursors[file.url.path] = cursor
            }
        }
        finished += tracker.closeIdle(now: now)

        let cutoff = now.addingTimeInterval(-ClaudeUsageLedger.retention)
        for id in ledgers.keys { ledgers[id]?.prune(before: cutoff) }

        if !primed {
            primed = true
            finished = []
        }
        return Output(profiles: snapshots(now: now, dayStart: dayStart), finished: finished)
    }

    // MARK: Discovery

    private func refreshProfiles(now: Date) {
        guard now.timeIntervalSince(lastDiscovery) >= Self.discoveryInterval else { return }
        lastDiscovery = now
        profiles = ClaudeProfileDiscovery.discover(home: home)
    }

    private func refreshPlanHistory() {
        let url = ClaudePlanLimits.historyURL(home: home)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != planModified else { return }
        planModified = modified
        planSamples = (try? Data(contentsOf: url)).flatMap(ClaudePlanLimits.samples(from:)) ?? []
    }

    /// Every `.jsonl` under the profile's roots written today, with its size
    /// from the directory walk so unchanged files cost no open.
    private func logFiles(in profile: ClaudeProfile, modifiedSince cutoff: Date) -> [(url: URL, size: UInt64)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        var files: [(url: URL, size: UInt64)] = []
        for root in profile.roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in walker where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                      let modified = values.contentModificationDate, modified >= cutoff else { continue }
                files.append((url, UInt64(values.fileSize ?? 0)))
            }
        }
        return files
    }

    // MARK: Snapshots

    private func snapshots(now: Date, dayStart: Date) -> [ClaudeProfileSnapshot] {
        let open = tracker.openTurns
        return profiles.map { profile in
            let ledger = ledgers[profile.id] ?? ClaudeUsageLedger()
            let live = open.filter { $0.profileID == profile.id }.map {
                ClaudeLiveSession(id: $0.key, profileID: profile.id, profileLabel: profile.label, project: $0.project,
                                  started: $0.started, lastActivity: $0.lastActivity)
            }
            let sessionStart = ClaudeSessionBlock.currentStart(
                ledger.dates(since: now.addingTimeInterval(-ClaudeSessionBlock.lookback)), now: now)
            let limits = ClaudePlanLimits.windows(from: planSamples, organization: profile.organization,
                                                  sessionStart: sessionStart, now: now)
            return ClaudeProfileSnapshot(id: profile.id, label: profile.label, live: live,
                                         today: ledger.summary(since: dayStart), limits: limits)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the one-class test command with `ClaudeUsageEngineTests`. Expected: `TEST SUCCEEDED`, 10 cases. If `testTurnFinishingAfterLaunchAnnouncesOnce` fails on discovery, remember `poll(now:)` only rediscovers profiles every 60s of the passed `now`: the test creates `.claude/projects` before the first poll for exactly this reason.

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeUsageEngine.swift NotchNookTests/Claude/ClaudeUsageEngineTests.swift
git commit -m "feat(claude): polling engine tying logs, turns, usage and limits together"
```

---

## Task 8: Widget settings and plumbing

Adds the `claudeUsage` widget case and its settings so the Nook knows the widget and its width everywhere. `NookView` and the settings tab already have `default:` branches, so the build stays green before the views exist (Task 10).

**Files:**
- Create: `NotchNook/models/settings/Nook/widgets/ClaudeUsageWidgetSettings.swift`
- Modify: `NotchNook/models/enums/NookWidgetEnum.swift`, `NotchNook/extensions/Defaults.swift`, `NotchNook/extensions/EnvironmentValues/Defaults/PerWidgetSettingsKeys.swift`, `NotchNook/views/RootView.swift`, `NotchNook/views/NotchView/modifiers/EnvironmentsModifier/EnvironmentsModifier.swift`, `NotchNook/extensions/View/subToAllWidgetsSettingsChanges.swift`
- Test: `NotchNookTests/Claude/ClaudeUsageWidgetSettingsTests.swift`

**Interfaces:**
- Produces: `ClaudeUsageWidgetSettings: WidgetPrefs` (`size`, `notifyOnFinish`, `playSound`, `minFinishSeconds: Double`); `Defaults.Keys.claudeUsageWidgetSettings`; `EnvironmentValues.claudeUsageWidgetSettings`; `NookWidget.claudeUsage`.

- [ ] **Step 1: Write the failing test**

```swift
// FILE: NotchNookTests/Claude/ClaudeUsageWidgetSettingsTests.swift
import XCTest
@testable import NotchNook

final class ClaudeUsageWidgetSettingsTests: XCTestCase {
    func testDefaultsMatchTheSpec() {
        let settings = ClaudeUsageWidgetSettings()
        XCTAssertEqual(settings.size, NookGrid.Size(width: 4, height: 2))
        XCTAssertTrue(settings.notifyOnFinish)
        XCTAssertTrue(settings.playSound)
        XCTAssertEqual(settings.minFinishSeconds, 10)
    }

    func testSettingsSurviveEncoding() throws {
        var settings = ClaudeUsageWidgetSettings()
        settings.size.width = NookGrid.Point(6)
        settings.minFinishSeconds = 30
        let decoded = try JSONDecoder().decode(ClaudeUsageWidgetSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
    }

    func testWidgetIsKnownToTheNook() {
        let widget = NookWidget.claudeUsage
        XCTAssertTrue(NookWidget.allCases.contains(widget))
        XCTAssertTrue(widget.isImplemented)
        XCTAssertEqual(widget.icon, "sparkle")
        XCTAssertFalse(widget.name.isEmpty)
        guard case .variable = widget.gridSizeType else { return XCTFail("width is user-sized like Timer") }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeUsageWidgetSettingsTests`. Expected: build FAILS ("cannot find 'ClaudeUsageWidgetSettings'").

- [ ] **Step 3: Implement**

```swift
// FILE: NotchNook/models/settings/Nook/widgets/ClaudeUsageWidgetSettings.swift
import SwiftUI

struct ClaudeUsageWidgetSettings: WidgetPrefs {
    var size: NookGrid.Size = .init(width: 4, height: 2)
    var notifyOnFinish: Bool = true
    var playSound: Bool = true
    /// Turns shorter than this finish without an alert.
    var minFinishSeconds: Double = 10
}
```

Edit `NotchNook/models/enums/NookWidgetEnum.swift` (five places, each right after the matching `.timer` line):

```swift
// 1. in the case list, after `case timer`:
    case claudeUsage
// 2. icon:           after `case .timer: "timer"`
            case .claudeUsage: "sparkle"
// 3. name:           after `case .timer: String(localized: "Timer")`
            case .claudeUsage: String(localized: "Claude Usage")
// 4. prefs:          after `case .timer: Defaults[.timerWidgetSettings]`
            case .claudeUsage: Defaults[.claudeUsageWidgetSettings]
// 5. gridSizeType:   after `case .timer: .variable`
            case .claudeUsage: .variable
```

Edit `NotchNook/extensions/Defaults.swift`, after the `timerWidgetSettings` key:

```swift
    static let claudeUsageWidgetSettings = Key<ClaudeUsageWidgetSettings>("claudeUsageWidgetSettings", default: .init())
```

Append to `NotchNook/extensions/EnvironmentValues/Defaults/PerWidgetSettingsKeys.swift`:

```swift
// MARK: - ClaudeUsageWidgetSettings

private struct ClaudeUsageWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = ClaudeUsageWidgetSettings()
}

extension EnvironmentValues {
    var claudeUsageWidgetSettings: ClaudeUsageWidgetSettings {
        get { self[ClaudeUsageWidgetSettingsKey.self] }
        set { self[ClaudeUsageWidgetSettingsKey.self] = newValue }
    }
}
```

Edit `NotchNook/views/RootView.swift`: after `@Default(.timerWidgetSettings) private var timerWidgetSettings` add

```swift
    @Default(.claudeUsageWidgetSettings) private var claudeUsageWidgetSettings
```

and after `.environment(\.timerWidgetSettings, timerWidgetSettings)` add

```swift
            .environment(\.claudeUsageWidgetSettings, claudeUsageWidgetSettings)
```

Edit `NotchNook/views/NotchView/modifiers/EnvironmentsModifier/EnvironmentsModifier.swift`: after `@Environment(\.timerWidgetSettings) internal var timerWidgetSettings` add

```swift
        @Environment(\.claudeUsageWidgetSettings) internal var claudeUsageWidgetSettings
```

and in `nookWidgetsWidth`'s switch, after `case .timer: timerWidgetSettings.size.width` add

```swift
                    case .claudeUsage: claudeUsageWidgetSettings.size.width
```

Edit `NotchNook/extensions/View/subToAllWidgetsSettingsChanges.swift`: after the `timerWidgetSettings` `@Environment` line add `@Environment(\.claudeUsageWidgetSettings) private var claudeUsageWidgetSettings`, and after `.animation(animation, value: timerWidgetSettings)` add `.animation(animation, value: claudeUsageWidgetSettings)`.

- [ ] **Step 4: Build and run tests**

Run the build command (expected `** BUILD SUCCEEDED **`) then the one-class test command with `ClaudeUsageWidgetSettingsTests` (3 cases, `TEST SUCCEEDED`).

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/models/settings/Nook/widgets/ClaudeUsageWidgetSettings.swift NotchNook/models/enums/NookWidgetEnum.swift NotchNook/extensions/Defaults.swift NotchNook/extensions/EnvironmentValues/Defaults/PerWidgetSettingsKeys.swift NotchNook/views/RootView.swift NotchNook/views/NotchView/modifiers/EnvironmentsModifier/EnvironmentsModifier.swift NotchNook/extensions/View/subToAllWidgetsSettingsChanges.swift NotchNookTests/Claude/ClaudeUsageWidgetSettingsTests.swift
git commit -m "feat(claude): usage widget settings and Nook plumbing"
```

---

## Task 9: Store, live activities and finish alerts

**Files:**
- Create: `NotchNook/models/claude/ClaudeFinishedAlert.swift`, `NotchNook/models/singletons/ClaudeUsageStore.swift`, `NotchNook/components/Notch/TopBar/liveActivities/activities/Claude/ClaudeLiveActivityViews.swift`
- Modify: `NotchNook/models/enums/LiveActivityEnum.swift`, `NotchNook/models/singletons/ActiveLiveActivitiesManager.swift`, `NotchNook/models/singletons/LiveActivitySelectionManager.swift`, `NotchNook/components/Notch/TopBar/liveActivities/LiveActivityView.swift`, `NotchNook/views/Settings/panes/LiveActivitiesSettings/tabs/LiveActivitiesCustomizeSettingsTab/MockTopBar.swift`, `.../LiveActivitiesCustomizeSettingsTabView.swift`, `NotchNook/models/settings/LiveActivities/LiveActivitiesSettings.swift`, `NotchNook/AppDelegate.swift`
- Test: `NotchNookTests/Claude/ClaudeFinishedAlertTests.swift`, `NotchNookTests/Claude/ClaudeLiveActivityTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageEngine`, `ClaudeProfileSnapshot`, `ClaudeFinishedTurn`, `ClaudeUsageWidgetSettings`, `ClaudeFormat`.
- Produces: `ClaudeFinishedAlert(profileLabel:project:duration:)` with `static alerts(from:profiles:notify:minimumSeconds:)`; `ClaudeUsageStore.shared` (`profiles`, `isLoaded`, `workingSession`, `currentFinished`); `LiveActivity.claudeWorking` / `.claudeFinished`; `ActiveLiveActivitiesManager.visible(_:liveActivitiesEnabled:enabled:)`; `ClaudeStyle.orange`; wing views `ClaudeWorkingIconView`, `ClaudeElapsedView`, `ClaudeFinishedIconView`, `ClaudeFinishedDurationView`.

- [ ] **Step 1: Write the failing tests**

```swift
// FILE: NotchNookTests/Claude/ClaudeFinishedAlertTests.swift
import XCTest
@testable import NotchNook

final class ClaudeFinishedAlertTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private let profiles = [ClaudeProfileSnapshot(id: "p1", label: "Personal", live: [], today: ClaudeUsageSummary(), limits: [])]

    private func turn(_ duration: TimeInterval, completed: Bool = true, profile: String = "p1") -> ClaudeFinishedTurn {
        ClaudeFinishedTurn(profileID: profile, project: "anywhere", started: t0, duration: duration, completed: completed)
    }

    func testOnlyCompletedTurnsAtOrAboveTheThresholdAlert() {
        let alerts = ClaudeFinishedAlert.alerts(from: [turn(9.9), turn(10), turn(60, completed: false), turn(61)],
                                                profiles: profiles, notify: true, minimumSeconds: 10)
        XCTAssertEqual(alerts.map(\.duration), [10, 61])
    }

    func testNotifyOffProducesNothing() {
        XCTAssertEqual(ClaudeFinishedAlert.alerts(from: [turn(120)], profiles: profiles, notify: false, minimumSeconds: 0), [])
    }

    func testLabelAndProjectComeFromTheTurn() {
        let alert = ClaudeFinishedAlert.alerts(from: [turn(30)], profiles: profiles, notify: true, minimumSeconds: 10)[0]
        XCTAssertEqual(alert, ClaudeFinishedAlert(profileLabel: "Personal", project: "anywhere", duration: 30))
        XCTAssertEqual(alert.accessibilityText, "Personal finished in anywhere after 30s")
    }

    func testUnknownProfileFallsBackToClaude() {
        let alert = ClaudeFinishedAlert.alerts(from: [turn(30, profile: "gone")], profiles: profiles, notify: true, minimumSeconds: 0)[0]
        XCTAssertEqual(alert.profileLabel, "Claude")
    }
}
```

```swift
// FILE: NotchNookTests/Claude/ClaudeLiveActivityTests.swift
import XCTest
@testable import NotchNook

final class ClaudeLiveActivityTests: XCTestCase {
    func testOnlyTheWorkingActivityIsUserConfigurable() {
        XCTAssertTrue(LiveActivity.claudeWorking.isUserConfigurable)
        XCTAssertFalse(LiveActivity.claudeFinished.isUserConfigurable)
        XCTAssertFalse(LiveActivity.timerExpired.isUserConfigurable)
    }

    func testPriorityOrder() {
        let manager = LiveActivitySelectionManager.shared
        let calendar = CalendarLiveActivitySettings()
        XCTAssertEqual(manager.selectActivity(from: [.timerExpired, .claudeFinished], calendarSettings: calendar), .timerExpired)
        XCTAssertEqual(manager.selectActivity(from: [.media, .tray, .claudeFinished], calendarSettings: calendar), .claudeFinished)
        XCTAssertEqual(manager.selectActivity(from: [.media, .claudeWorking], calendarSettings: calendar), .claudeWorking)
    }

    func testAlwaysOnActivitiesSurviveTheMasterSwitchAndTheToggleList() {
        let active: Set<LiveActivity> = [.claudeFinished, .claudeWorking, .media, .timerExpired]
        XCTAssertEqual(ActiveLiveActivitiesManager.visible(active, liveActivitiesEnabled: false, enabled: [.media, .claudeWorking]),
                       [.claudeFinished, .timerExpired])
        XCTAssertEqual(ActiveLiveActivitiesManager.visible(active, liveActivitiesEnabled: true, enabled: [.claudeWorking]),
                       [.claudeFinished, .claudeWorking, .timerExpired])
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run the one-class test command for `ClaudeFinishedAlertTests`. Expected: build FAILS (missing `ClaudeFinishedAlert`, `LiveActivity.claudeWorking`).

- [ ] **Step 3: Implement the alert model and enum cases**

```swift
// FILE: NotchNook/models/claude/ClaudeFinishedAlert.swift
import Foundation

/// A turn worth telling the person about.
struct ClaudeFinishedAlert: Equatable {
    let profileLabel: String
    let project: String
    let duration: TimeInterval

    var accessibilityText: String {
        "\(profileLabel) finished in \(project) after \(ClaudeFormat.duration(duration))"
    }

    /// Only completed turns at least `minimumSeconds` long, and only when notifying.
    static func alerts(from finished: [ClaudeFinishedTurn], profiles: [ClaudeProfileSnapshot],
                       notify: Bool, minimumSeconds: TimeInterval) -> [ClaudeFinishedAlert] {
        guard notify else { return [] }
        return finished
            .filter { $0.completed && $0.duration >= minimumSeconds }
            .map { turn in
                ClaudeFinishedAlert(profileLabel: profiles.first { $0.id == turn.profileID }?.label ?? "Claude",
                                    project: turn.project, duration: turn.duration)
            }
    }
}
```

Edit `NotchNook/models/enums/LiveActivityEnum.swift`:

```swift
// case list: after `case timerExpired`
    /// Shown while a Claude turn runs; the person can turn it off like the others.
    case claudeWorking
    /// Transient — fired by ClaudeUsageStore when a long turn completes. Always surfaces.
    case claudeFinished

// isUserConfigurable becomes:
    var isUserConfigurable: Bool {
        self != .timerExpired && self != .claudeFinished
    }

// icon switch, after `case .timerExpired: "timer"`:
            case .claudeWorking: "sparkle"
            case .claudeFinished: "checkmark.circle.fill"

// name switch, after `case .timerExpired: String(localized: "Timer Ended")`:
            case .claudeWorking: String(localized: "Claude")
            case .claudeFinished: String(localized: "Claude Finished")
```

Edit `NotchNook/models/singletons/ActiveLiveActivitiesManager.swift`: replace the `activeLiveActivities` getter body so the filter lives in a testable static, keeping behaviour identical for existing activities:

```swift
    /// Activities that surface regardless of the user's toggle list or the master switch.
    static let alwaysOn: Set<LiveActivity> = [.timerExpired, .claudeFinished]

    static func visible(_ active: Set<LiveActivity>, liveActivitiesEnabled: Bool, enabled: Set<LiveActivity>) -> Set<LiveActivity> {
        guard liveActivitiesEnabled else { return active.intersection(alwaysOn) }
        return active.filter { alwaysOn.contains($0) || enabled.contains($0) }
    }

    var activeLiveActivities: Set<LiveActivity> {
        get {
            Self.visible(_activeLiveActivities, liveActivitiesEnabled: liveActivitiesSettingsCache.enabled,
                         enabled: liveActivitiesSettingsCache.enabledLiveActivities)
        }
        set {
            Task { @MainActor in
                withAnimation(TopBarView.animation) { _activeLiveActivities = newValue }
            }
        }
    }
```

Edit `NotchNook/models/singletons/LiveActivitySelectionManager.swift` priority list (every case must be listed or `sortActivitiesByPriority` is inconsistent):

```swift
    // .timerExpired and .claudeFinished are alerts: they cut to the front.
    private var activitiesByPriority: [LiveActivity] = [.timerExpired, .claudeFinished, .bluetoothDevice, .batteryVisualizer, .tray, .calendar, .claudeWorking, .updateAvailable, .media]
```

Edit `NotchNook/models/settings/LiveActivities/LiveActivitiesSettings.swift`: `var enabledLiveActivities: Set<LiveActivity> = [.tray, .media, .updateAvailable, .claudeWorking]` (new installs only; existing users toggle it in Settings → Live Activities).

- [ ] **Step 4: Implement the store**

```swift
// FILE: NotchNook/models/singletons/ClaudeUsageStore.swift
import SwiftUI
import AppKit
import Defaults

/// Runs `ClaudeUsageEngine` every two seconds while the Claude Usage widget is
/// in the Nook, publishes its snapshots, and drives the two Claude live
/// activities. One instance only: nootch has a window per screen, and a
/// watcher per view would fire every alert twice.
@Observable
final class ClaudeUsageStore {
    static let shared = ClaudeUsageStore()

    private(set) var profiles: [ClaudeProfileSnapshot] = []
    /// False until the first poll has read today's history.
    private(set) var isLoaded = false
    /// FIFO of finished turns waiting their few seconds in the notch.
    private(set) var finishedQueue: [ClaudeFinishedAlert] = []

    var currentFinished: ClaudeFinishedAlert? { finishedQueue.first }
    /// The longest-running turn across profiles.
    var workingSession: ClaudeLiveSession? { profiles.flatMap(\.live).min { $0.started < $1.started } }

    @ObservationIgnored private let queue = DispatchQueue(label: "lo.cafe.notchnook.claude-usage", qos: .utility)
    @ObservationIgnored private var timer: DispatchSourceTimer?
    @ObservationIgnored private var prefsTask: Task<Void, Never>?
    @ObservationIgnored private var workingShown = false

    private init() {
        // Starts and stops with the widget being in the Nook; nothing is read otherwise.
        prefsTask = Task { @MainActor [weak self] in
            for await settings in Defaults.updates(.nookSettings) {
                self?.setRunning(settings.enabledWidgets.contains(.claudeUsage))
            }
        }
    }

    deinit { prefsTask?.cancel() }

    // MARK: Lifecycle

    private func setRunning(_ running: Bool) {
        if running { start() } else { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        let engine = ClaudeUsageEngine(home: FileManager.default.homeDirectoryForCurrentUser)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(500))
        source.setEventHandler { [weak self] in
            // The engine is only ever touched on this queue.
            let output = engine.poll()
            DispatchQueue.main.async { self?.apply(output) }
        }
        timer = source
        source.resume()
    }

    private func stop() {
        guard let source = timer else { return }
        source.cancel()
        timer = nil
        profiles = []
        isLoaded = false
        finishedQueue.removeAll()
        setWorking(false)
        MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.removeSync(.claudeFinished) }
    }

    // MARK: Output

    private func apply(_ output: ClaudeUsageEngine.Output) {
        guard timer != nil else { return }   // a poll already in flight when the widget was removed
        if output.profiles != profiles { profiles = output.profiles }
        if !isLoaded { isLoaded = true }
        setWorking(workingSession != nil)

        let settings = Defaults[.claudeUsageWidgetSettings]
        let alerts = ClaudeFinishedAlert.alerts(from: output.finished, profiles: output.profiles,
                                                notify: settings.notifyOnFinish, minimumSeconds: settings.minFinishSeconds)
        for alert in alerts { enqueue(alert, playSound: settings.playSound) }
    }

    private func setWorking(_ working: Bool) {
        guard working != workingShown else { return }
        workingShown = working
        MainActor.assumeIsolated {
            if working { ActiveLiveActivitiesManager.shared.insertSync(.claudeWorking) }
            else { ActiveLiveActivitiesManager.shared.removeSync(.claudeWorking) }
        }
    }

    // MARK: Finished alerts (same queue-and-dismiss shape as NookTimersStore)

    private func enqueue(_ alert: ClaudeFinishedAlert, playSound: Bool) {
        let wasEmpty = finishedQueue.isEmpty
        finishedQueue.append(alert)
        if playSound { NSSound(named: NSSound.Name("Hero"))?.play() }
        if wasEmpty {
            MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.insertSync(.claudeFinished) }
            scheduleNextDismiss()
        }
    }

    private func popFinished() {
        guard !finishedQueue.isEmpty else { return }
        finishedQueue.removeFirst()
        if finishedQueue.isEmpty {
            MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.removeSync(.claudeFinished) }
        } else {
            scheduleNextDismiss()
        }
    }

    private func scheduleNextDismiss() {
        let dismiss = Timer(timeInterval: 5, repeats: false) { [weak self] _ in self?.popFinished() }
        RunLoop.main.add(dismiss, forMode: .common)
        TimersManager.shared.replaceMainThreadTimer("ClaudeFinishedLADismiss", timer: dismiss)
    }
}
```

Edit `NotchNook/AppDelegate.swift`: after `_ = FullscreenMonitor.shared` add

```swift
        _ = ClaudeUsageStore.shared
```

- [ ] **Step 5: Implement the wing views and wire the switches**

```swift
// FILE: NotchNook/components/Notch/TopBar/liveActivities/activities/Claude/ClaudeLiveActivityViews.swift
import SwiftUI

enum ClaudeStyle {
    /// Claude's brand orange.
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)
}

/// Left wing while Claude works: a pulsing mark.
struct ClaudeWorkingIconView: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ClaudeStyle.orange)
            .symbolEffect(.pulse, options: .repeating)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Claude is working")
    }
}

/// Right wing while Claude works: how long the longest turn has run.
struct ClaudeElapsedView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let session = store.workingSession {
                Text(verbatim: ClaudeFormat.clock(context.date.timeIntervalSince(session.started)))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(ClaudeStyle.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Left wing when a turn finishes.
struct ClaudeFinishedIconView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(ClaudeStyle.orange)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(store.currentFinished?.accessibilityText ?? "Claude finished")
    }
}

/// Right wing when a turn finishes: how long it took. The wing is only 35pt
/// wide, so the profile and project live in the accessibility label and the widget.
struct ClaudeFinishedDurationView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        if let alert = store.currentFinished {
            Text(verbatim: ClaudeFormat.duration(alert.duration))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
        }
    }
}
```

Edit `LiveActivityView.swift`: after the `.timerExpired` case (the last in the switch) add

```swift
                    case .claudeWorking:
                        switch side {
                            case .left: ClaudeWorkingIconView()
                            case .right: ClaudeElapsedView()
                        }

                    case .claudeFinished:
                        switch side {
                            case .left: ClaudeFinishedIconView()
                            case .right: ClaudeFinishedDurationView()
                        }
```

Edit `MockTopBar.swift`: in the left `Group`'s switch, after `case .timerExpired: EmptyView()` add `case .claudeWorking: ClaudeWorkingIconView()` and `case .claudeFinished: EmptyView()`; in the right `Group`'s switch, after its `case .timerExpired: EmptyView()` add

```swift
                    case .claudeWorking:
                        Text(verbatim: "2:14")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(ClaudeStyle.orange)
                    case .claudeFinished:
                        EmptyView()
```

Edit `LiveActivitiesCustomizeSettingsTabView.swift`: change `case .bluetoothDevice, .updateAvailable, .timerExpired:` to `case .bluetoothDevice, .updateAvailable, .timerExpired, .claudeWorking, .claudeFinished:`.

- [ ] **Step 6: Build and run tests**

Run the build command (`** BUILD SUCCEEDED **`; if a "switch must be exhaustive" error names a file not listed above, add the two Claude cases there the same way), then the one-class test command for `ClaudeFinishedAlertTests` (4 cases) and `ClaudeLiveActivityTests` (3 cases). Expected: `TEST SUCCEEDED`.

- [ ] **Step 7: Commit (after user okays committing)**

```bash
git add NotchNook/models/claude/ClaudeFinishedAlert.swift NotchNook/models/singletons/ClaudeUsageStore.swift NotchNook/components/Notch/TopBar/liveActivities/activities/Claude/ClaudeLiveActivityViews.swift NotchNook/models/enums/LiveActivityEnum.swift NotchNook/models/singletons/ActiveLiveActivitiesManager.swift NotchNook/models/singletons/LiveActivitySelectionManager.swift NotchNook/components/Notch/TopBar/liveActivities/LiveActivityView.swift NotchNook/views/Settings/panes/LiveActivitiesSettings/tabs/LiveActivitiesCustomizeSettingsTab/MockTopBar.swift NotchNook/views/Settings/panes/LiveActivitiesSettings/tabs/LiveActivitiesCustomizeSettingsTab/LiveActivitiesCustomizeSettingsTabView.swift NotchNook/models/settings/LiveActivities/LiveActivitiesSettings.swift NotchNook/AppDelegate.swift NotchNookTests/Claude/ClaudeFinishedAlertTests.swift NotchNookTests/Claude/ClaudeLiveActivityTests.swift
git commit -m "feat(claude): usage store with working and finished live activities"
```

---

## Task 10: The widget and its settings pane

**Files:**
- Create: `NotchNook/components/Notch/Nook/Widgets/ClaudeUsageWidget/ClaudeUsageWidgetView.swift`, `NotchNook/views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/perWidgetSettings/ClaudeUsageWidgetSettingsView.swift`
- Modify: `NotchNook/components/Notch/Nook/NookView.swift`, `NotchNook/views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/WidgetsSettingsTabView.swift`
- Test: `NotchNookTests/Claude/ClaudeUsageLevelTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageStore`, `ClaudeProfileSnapshot`, `ClaudeLimitWindow`, `ClaudeFormat`, `ClaudeStyle`, `TimerInsets` (existing, in `TimerWidgetView.swift`), `ClaudeUsageWidgetSettings`.
- Produces: `ClaudeUsageWidgetView(arrayPosition:internalPadding:)`, `ClaudeUsageLevel.level(forUsedFraction:)`, `ClaudeUsageWidgetSettingsView`.

- [ ] **Step 1: Write the failing test**

```swift
// FILE: NotchNookTests/Claude/ClaudeUsageLevelTests.swift
import XCTest
@testable import NotchNook

final class ClaudeUsageLevelTests: XCTestCase {
    func testLevelsByUsedFraction() {
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 0), .normal)
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 0.69), .normal)
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 0.7), .warning)
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 0.89), .warning)
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 0.9), .critical)
        XCTAssertEqual(ClaudeUsageLevel.level(forUsedFraction: 1), .critical)
    }

    func testLimitWindowFractionIsClamped() {
        XCTAssertEqual(ClaudeLimitWindow(kind: .session, usedPercent: 150, resetsAt: nil, isEstimate: false).usedFraction, 1)
        XCTAssertEqual(ClaudeLimitWindow(kind: .weekly, usedPercent: -3, resetsAt: nil, isEstimate: false).usedFraction, 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the one-class test command with `ClaudeUsageLevelTests`. Expected: build FAILS ("cannot find 'ClaudeUsageLevel'").

- [ ] **Step 3: Implement the widget**

```swift
// FILE: NotchNook/components/Notch/Nook/Widgets/ClaudeUsageWidget/ClaudeUsageWidgetView.swift
import SwiftUI

enum ClaudeUsageLevel: Equatable {
    case normal, warning, critical

    static func level(forUsedFraction fraction: Double) -> ClaudeUsageLevel {
        fraction >= 0.9 ? .critical : fraction >= 0.7 ? .warning : .normal
    }

    var color: Color {
        switch self {
        case .normal: ClaudeStyle.orange
        case .warning: .yellow
        case .critical: .red
        }
    }
}

/// Plan limits, today's usage and what Claude is doing now, per profile.
/// Honours the same width, padding and corner-inset contract as the Timer widget.
struct ClaudeUsageWidgetView: View {
    var arrayPosition: ArrayPosition
    var internalPadding: Double

    @Environment(\.claudeUsageWidgetSettings) private var prefs
    @Environment(\.generalSettings) private var generalSettings
    @State private var store = ClaudeUsageStore.shared

    private var insets: TimerInsets {
        TimerInsets(arrayPosition: arrayPosition, contentPadding: generalSettings.contentPadding,
                    widgetPadding: internalPadding)
    }

    private var visibleProfiles: [ClaudeProfileSnapshot] { store.profiles.filter(\.hasActivity) }

    var body: some View {
        Group {
            if !store.isLoaded {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleProfiles.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(visibleProfiles) { ClaudeProfileBlock(profile: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, insets.top)
        .padding(.bottom, insets.bottom)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paddingDependingOnArrPos(arrayPosition: arrayPosition, padding: internalPadding)
        // Width from the grid; height fills the band the Nook gives us.
        .frame(width: prefs.size.width.screenPoints, alignment: .leading)
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 24))
                .foregroundStyle(Color.white.opacity(0.28))
            Text("No Claude activity yet")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClaudeProfileBlock: View {
    let profile: ClaudeProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ClaudeStyle.orange)
                Text(verbatim: profile.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 4)
                status
            }
            limits
            usage
        }
    }

    @ViewBuilder private var status: some View {
        if let session = profile.live.min(by: { $0.started < $1.started }) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(verbatim: "\(session.project) · \(ClaudeFormat.clock(context.date.timeIntervalSince(session.started)))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(ClaudeStyle.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Text("Idle")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder private var limits: some View {
        if profile.limits.isEmpty {
            Text("Limits unavailable")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        } else {
            HStack(alignment: .top, spacing: 10) {
                ForEach(profile.limits) { ClaudeLimitMeter(window: $0) }
            }
        }
    }

    @ViewBuilder private var usage: some View {
        if profile.today.requests == 0 {
            Text("No usage today")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        } else {
            let today = profile.today
            Text(verbatim: "\(ClaudeFormat.tokens(today.tokens.total)) tok · \(ClaudeFormat.cost(today.cost, approximate: today.hasUnpriced)) today")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ClaudeLimitMeter: View {
    let window: ClaudeLimitWindow

    private var level: ClaudeUsageLevel { .level(forUsedFraction: window.usedFraction) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(window.kind == .session ? "5h" : "Week")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                Text(verbatim: "\(Int(window.usedPercent.rounded()))%")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(level.color)
                            .frame(width: max(4, proxy.size.width * window.usedFraction))
                    }
                }
            if let resets = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(verbatim: "resets \(window.isEstimate ? "~" : "")\(ClaudeFormat.resetIn(resets, now: context.date))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
```

```swift
// FILE: NotchNook/views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/perWidgetSettings/ClaudeUsageWidgetSettingsView.swift
import SwiftUI
import Settings
import Defaults

struct ClaudeUsageWidgetSettingsView: View {
    @Default(.claudeUsageWidgetSettings) private var settings

    var body: some View {
        Settings.Container(contentWidth: 320) {
            Settings.Section(title: "", bottomDivider: true) {
                Text("Width:")
                SliderPlus(value: $settings.size.width.double, range: 3...8)
            }

            Settings.Section(title: "", bottomDivider: true) {
                Toggle(String(localized: "Notify when Claude finishes"), isOn: $settings.notifyOnFinish)
                    .padding(.vertical, 4)
            }

            Settings.Section(title: "", bottomDivider: true) {
                Toggle(String(localized: "Play sound when Claude finishes"), isOn: $settings.playSound)
                    .padding(.vertical, 4)
            }

            Settings.Section(title: "") {
                Text(verbatim: String(localized: "Only for turns longer than") + " \(Int(settings.minFinishSeconds))s")
                SliderPlus(value: $settings.minFinishSeconds, range: 0...120, step: 5)
            }
        }
        .padding(0)
    }
}
```

Edit `NotchNook/components/Notch/Nook/NookView.swift`: after the `.timer` case add

```swift
                    case .claudeUsage:
                        ClaudeUsageWidgetView(arrayPosition: arrPos, internalPadding: nookSettings.widgetsPadding)
```

Edit `WidgetsSettingsTabView.swift`: after `case .timer: TimerWidgetSettingsView()` add

```swift
                    case .claudeUsage: ClaudeUsageWidgetSettingsView()
```

- [ ] **Step 4: Build and run tests**

Run the build command (`** BUILD SUCCEEDED **`) then the one-class test command with `ClaudeUsageLevelTests` (2 cases, `TEST SUCCEEDED`).

- [ ] **Step 5: Commit (after user okays committing)**

```bash
git add NotchNook/components/Notch/Nook/Widgets/ClaudeUsageWidget/ClaudeUsageWidgetView.swift NotchNook/views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/perWidgetSettings/ClaudeUsageWidgetSettingsView.swift NotchNook/components/Notch/Nook/NookView.swift NotchNook/views/Settings/panes/NookSettings/tabs/WidgetsSettingsTab/WidgetsSettingsTabView.swift NotchNookTests/Claude/ClaudeUsageLevelTests.swift
git commit -m "feat(claude): usage widget view and settings pane"
```

---

## Task 11: Full verification against real logs

No new code unless a defect turns up. This is where real-world behaviour is checked; fix any defect in the owning task's file with a failing test first.

- [ ] **Step 1: Full test run and clean build**

```bash
xcodebuild test -project NotchNook.xcodeproj -scheme NotchNook -destination 'platform=macOS' 2>&1 | /usr/bin/grep -E "error:|failed|TEST (SUCCEEDED|FAILED)"
```
Expected: `TEST SUCCEEDED` (all Claude suites plus the pre-existing `SideEffectsModifierTests`). Then the plain build command: `** BUILD SUCCEEDED **`, and `/usr/bin/grep -c "warning:.*Claude" ` over its output should be 0 (fix any warning in the new files).

- [ ] **Step 2: Enable the widget (needs the user)**

The built app shares the user's real preferences. Ask the user to quit any running NotchNook, then launch the fresh build and in Settings → Nook → Widgets turn on **Claude Usage**, and in Settings → Live Activities turn on **Claude**. (Do not edit their preferences with `defaults write` without asking.) Find and launch the build:

```bash
BUILT=$(xcodebuild -project NotchNook.xcodeproj -scheme NotchNook -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')
open "$BUILT/NotchNook.app"
```

- [ ] **Step 3: Real turns on both profiles**

Lower **Only for turns longer than** to 0s so short test turns alert. Then, one at a time, with the notch closed:

```bash
claude -p "reply with the single word ok"
CLAUDE_CONFIG_DIR=~/.claude-personal claude -p "reply with the single word ok"
```

Expected for each: the closed notch shows the sparkle and a running clock (`.claudeWorking`), then a check with the duration (`.claudeFinished`) for about 5s, then clears. If the personal run asks to log in, skip it and say so.

- [ ] **Step 4: Screenshot the real UI**

With the Nook open (user hovers the notch, or drive the pointer if a computer-use tool is available), capture and send each state with SendUserFile:

```bash
screencapture -x "$TMPDIR/claude-nook.png"
```

Check and report: (a) widget at width 3, 4 and 8; (b) widget first, middle and last in the Nook (reorder in settings) with the corner insets matching Timer; (c) work profile shows "Limits unavailable" and the personal profile shows the 5h and Week meters from the desktop app's file; (d) today's tokens and cost look plausible against a manual `ls`/size check of today's logs; (e) the working and finished wings fit in the 35pt wings without clipping.

- [ ] **Step 5: Check the privacy and hygiene constraints**

```bash
git status --short
git diff --stat
```
Confirm: only intended files changed; the three pre-existing modified files are either untouched or, for `Localizable.xcstrings`, only gained auto-extracted strings from the build (never staged). Confirm nothing under `NotchNook/models/claude/` logs prompt, reply or tool text (`/usr/bin/grep -rn "print(\|NSLog\|os_log\|Logger" NotchNook/models/claude NotchNook/models/singletons/ClaudeUsageStore.swift` returns nothing).

- [ ] **Step 6: Report**

Summarise for the user what was verified live vs only by unit test, list the spec deviation (finished wing shows duration, not project text), and note the manual setup steps (enable widget and Claude live activity). Offer the branch for review; do not push or open a PR unasked.

---

## Self-review (spec coverage)

| Spec section | Task |
|---|---|
| Profiles: discovery, org, labels | 6 |
| Tail logs, byte filter, partial lines, rotation | 2, 6 |
| Turn tracking rules, idle timeout, sidechain | 2, 3, 7 |
| Finish events only after history read, min duration | 7, 9 |
| Today's usage, de-dup, pricing, unpriced "+" | 1, 4 |
| Plan limits, per-profile org match, reset math | 5, 7 |
| `.claudeWorking` / `.claudeFinished`, priority, always-on | 9 |
| Widget contract (width, insets, scroll, empty state) | 8, 10 |
| Settings: width, notify, sound, threshold | 8, 10 |
| Wiring checklist (every switch) | 8, 9, 10 |
| Privacy, error handling | 2, 5, 6, 7, 11 |
| Manual verification with screenshots | 11 |
