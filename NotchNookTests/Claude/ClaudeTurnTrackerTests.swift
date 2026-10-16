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
