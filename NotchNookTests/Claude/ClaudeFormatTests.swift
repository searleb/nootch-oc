import XCTest
@testable import NotchNook

final class ClaudeFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(ClaudeFormat.clock(0), "0:00")
        XCTAssertEqual(ClaudeFormat.clock(134), "2:14")
        XCTAssertEqual(ClaudeFormat.clock(3_725), "1:02:05")
        XCTAssertEqual(ClaudeFormat.clock(-5), "0:00")
    }

    func testCompactClockFitsAThirtyFivePointWing() {
        XCTAssertEqual(ClaudeFormat.compactClock(42), "0:42")
        XCTAssertEqual(ClaudeFormat.compactClock(657), "10:57")
        XCTAssertEqual(ClaudeFormat.compactClock(3_599), "59:59")
        XCTAssertEqual(ClaudeFormat.compactClock(3_725), "1h02m", "an hour or more drops seconds instead of overflowing")
        XCTAssertEqual(ClaudeFormat.compactClock(36_000), "10h00m")
        XCTAssertEqual(ClaudeFormat.compactClock(-1), "0:00")
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

    func testCacheHitRateIsCacheReadsOverEverythingTheModelRead() {
        let tokens = ClaudeTokens(input: 50, cacheWrite: 50, cacheRead: 900, output: 5_000)
        XCTAssertEqual(tokens.cacheHitRate!, 0.9, accuracy: 1e-9, "output tokens are not part of what was read")
        XCTAssertEqual(ClaudeTokens(input: 0, cacheWrite: 0, cacheRead: 300, output: 1).cacheHitRate, 1)
        XCTAssertEqual(ClaudeTokens(input: 10, cacheWrite: 0, cacheRead: 0, output: 1).cacheHitRate, 0)
    }

    func testCacheHitRateIsNilWithNothingRead() {
        XCTAssertNil(ClaudeTokens().cacheHitRate)
        XCTAssertNil(ClaudeTokens(input: 0, cacheWrite: 0, cacheRead: 0, output: 99).cacheHitRate)
    }
}
