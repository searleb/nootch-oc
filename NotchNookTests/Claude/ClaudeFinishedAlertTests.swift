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
