//
//  TodoTask.swift
//  NotchNook
//

import Foundation

/// One to-do as the widget shows it, read from a reminder in the user's Reminders list.
struct TodoTask: Identifiable, Equatable {
    /// The reminder's `calendarItemIdentifier`.
    let id: String
    var title: String
    var isCompleted: Bool
    var isPriority: Bool
    var createdAt: Date?
    var completedAt: Date?
}

/// The star is Reminders' High priority: EventKit has no public access to "flagged".
enum TodoPriority {
    /// Reminders' own High priority value.
    static let high = 1

    static func reminderPriority(starred: Bool) -> Int { starred ? high : 0 }

    /// Reminders treats 1-4 as high, 5 as medium and 6-9 as low.
    static func isStarred(reminderPriority: Int) -> Bool { (1...4).contains(reminderPriority) }
}

enum TodoVisibility {
    /// What the widget lists: completed tasks only when shown and not yet archived (counted from
    /// when they were completed), starred first, then newest first.
    static func visible(_ tasks: [TodoTask], showCompleted: Bool, archiveAfterDays: Int, now: Date) -> [TodoTask] {
        let cutoff = archiveAfterDays > 0 ? now.addingTimeInterval(-Double(archiveAfterDays) * 86_400) : nil
        return tasks
            .filter { task in
                guard task.isCompleted else { return true }
                guard showCompleted else { return false }
                if let cutoff, let completedAt = task.completedAt, completedAt < cutoff { return false }
                return true
            }
            .sorted {
                if $0.isPriority != $1.isPriority { return $0.isPriority }
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
    }
}
