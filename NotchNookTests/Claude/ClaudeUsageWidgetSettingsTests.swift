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
