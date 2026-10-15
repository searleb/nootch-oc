import XCTest
@testable import NotchNook

final class ClaudeLiveActivityTests: XCTestCase {
    func testClaudeActivitiesAreNotUserConfigurable() {
        XCTAssertFalse(LiveActivity.claudeWorking.isUserConfigurable, "the Claude widget being in the Nook is the opt-in")
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
        XCTAssertEqual(ActiveLiveActivitiesManager.visible(active, liveActivitiesEnabled: false, enabled: [.media]),
                       [.claudeFinished, .claudeWorking, .timerExpired])
        // The user's saved toggle list predates Claude and never contains it: it must still beat music.
        XCTAssertEqual(ActiveLiveActivitiesManager.visible(active, liveActivitiesEnabled: true, enabled: [.media, .calendar, .tray]),
                       [.claudeFinished, .claudeWorking, .media, .timerExpired])
    }
}
