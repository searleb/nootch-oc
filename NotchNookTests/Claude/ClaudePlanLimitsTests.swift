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
