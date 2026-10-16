import XCTest
@testable import NotchNook

final class ClaudeBurstTests: XCTestCase {
    func testEightRaysAlwaysWithinBounds() {
        for time in stride(from: 0.0, to: 5.0, by: 0.37) {
            let lengths = ClaudeBurst.rayLengths(at: time)
            XCTAssertEqual(lengths.count, ClaudeBurst.rayCount)
            XCTAssertTrue(lengths.allSatisfy { $0 >= ClaudeBurst.minimumLength - 1e-9 && $0 <= 1 + 1e-9 })
        }
    }

    func testRaysChaseAroundTheRingInsteadOfPulsingTogether() {
        let now = ClaudeBurst.rayLengths(at: 0)
        XCTAssertGreaterThan(now.max()! - now.min()!, 0.2, "rays are out of phase with each other")
        XCTAssertNotEqual(now, ClaudeBurst.rayLengths(at: ClaudeBurst.period / 4), "and the pattern moves")
    }

    func testLoopsSeamlesslyEveryPeriod() {
        let a = ClaudeBurst.rayLengths(at: 0.3)
        let b = ClaudeBurst.rayLengths(at: 0.3 + ClaudeBurst.period)
        for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: 1e-9) }
    }

    func testRotationAdvancesAndWraps() {
        XCTAssertEqual(ClaudeBurst.rotation(at: 0), 0)
        XCTAssertGreaterThan(ClaudeBurst.rotation(at: 1), 0)
        XCTAssertEqual(ClaudeBurst.rotation(at: ClaudeBurst.turnPeriod), 0, accuracy: 1e-9)
        XCTAssertLessThan(ClaudeBurst.rotation(at: ClaudeBurst.turnPeriod * 7.9), 2 * .pi)
    }
}
