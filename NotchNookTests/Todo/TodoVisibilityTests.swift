import XCTest
@testable import NotchNook

final class TodoVisibilityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func ago(days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    private func item(_ id: String, created: Double = 1, completed: Double? = nil, priority: Bool = false) -> TodoTask {
        TodoTask(id: id, title: id, isCompleted: completed != nil, isPriority: priority,
                 createdAt: ago(days: created), completedAt: completed.map { ago(days: $0) })
    }

    func testPriorityFirstThenNewestFirst() {
        let items = [item("old", created: 5), item("new", created: 1), item("star-old", created: 9, priority: true),
                     item("star-new", created: 2, priority: true)]
        let visible = TodoVisibility.visible(items, showCompleted: true, archiveAfterDays: 0, now: now)
        XCTAssertEqual(visible.map(\.id), ["star-new", "star-old", "new", "old"])
    }

    func testCompletedAreHiddenWhenTurnedOff() {
        let items = [item("open"), item("done", completed: 0.1)]
        XCTAssertEqual(TodoVisibility.visible(items, showCompleted: false, archiveAfterDays: 0, now: now).map(\.id), ["open"])
    }

    func testArchiveUsesWhenItWasCompletedNotWhenItWasCreated() {
        let items = [item("created-long-ago-done-today", created: 30, completed: 0.5),
                     item("done-last-month", created: 31, completed: 20),
                     item("open-and-old", created: 400)]
        let visible = TodoVisibility.visible(items, showCompleted: true, archiveAfterDays: 7, now: now)
        XCTAssertEqual(Set(visible.map(\.id)), ["created-long-ago-done-today", "open-and-old"])
    }

    func testZeroDaysKeepsCompletedForever() {
        let items = [item("ancient", created: 900, completed: 800)]
        XCTAssertEqual(TodoVisibility.visible(items, showCompleted: true, archiveAfterDays: 0, now: now).count, 1)
    }

    func testCompletedWithoutADateIsKept() {
        let undated = TodoTask(id: "x", title: "x", isCompleted: true, isPriority: false, createdAt: nil, completedAt: nil)
        XCTAssertEqual(TodoVisibility.visible([undated], showCompleted: true, archiveAfterDays: 7, now: now).count, 1)
    }

    func testStarMapsToHighPriorityAndBack() {
        XCTAssertEqual(TodoPriority.reminderPriority(starred: true), 1)
        XCTAssertEqual(TodoPriority.reminderPriority(starred: false), 0)
        XCTAssertTrue(TodoPriority.isStarred(reminderPriority: 1))
        XCTAssertTrue(TodoPriority.isStarred(reminderPriority: 4), "1-4 is Reminders' high band")
        XCTAssertFalse(TodoPriority.isStarred(reminderPriority: 5))
        XCTAssertFalse(TodoPriority.isStarred(reminderPriority: 0))
    }
}
