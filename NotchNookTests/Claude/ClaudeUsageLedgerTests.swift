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
