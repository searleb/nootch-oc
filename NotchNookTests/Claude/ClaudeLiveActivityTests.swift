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
