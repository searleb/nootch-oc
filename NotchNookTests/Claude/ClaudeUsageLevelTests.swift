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
