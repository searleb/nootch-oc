//
//  PerWidgetSettingsKeys.swift
//  NotchNook
//
//  Created by Igor Marcossi on 09/07/24.
//

import SwiftUI


// MARK: - MediaWidgetSettings

private struct MediaWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = MediaWidgetSettings()
}

extension EnvironmentValues {
    var mediaWidgetSettings: MediaWidgetSettings {
        get { self[MediaWidgetSettingsKey.self] }
        set { self[MediaWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - ShortcutsWidgetSettings

private struct ShortcutsWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = ShortcutsWidgetSettings()
}

extension EnvironmentValues {
    var shortcutsWidgetSettings: ShortcutsWidgetSettings {
        get { self[ShortcutsWidgetSettingsKey.self] }
        set { self[ShortcutsWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - MirrorWidgetSettings

private struct MirrorWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = MirrorWidgetSettings()
}

extension EnvironmentValues {
    var mirrorWidgetSettings: MirrorWidgetSettings {
        get { self[MirrorWidgetSettingsKey.self] }
        set { self[MirrorWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - CalendarWidgetSettings

private struct CalendarWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = CalendarWidgetSettings()
}

extension EnvironmentValues {
    var calendarWidgetSettings: CalendarWidgetSettings {
        get { self[CalendarWidgetSettingsKey.self] }
        set { self[CalendarWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - NotesWidgetSettings

private struct NotesWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = NotesWidgetSettings()
}

extension EnvironmentValues {
    var notesWidgetSettings: NotesWidgetSettings {
        get { self[NotesWidgetSettingsKey.self] }
        set { self[NotesWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - TodoListWidgetSettings

private struct TodoListWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = TodoListWidgetSettings()
}

extension EnvironmentValues {
    var todoListWidgetSettings: TodoListWidgetSettings {
        get { self[TodoListWidgetSettingsKey.self] }
        set { self[TodoListWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - QuickAppsWidgetSettings

private struct QuickAppsWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = QuickAppsWidgetSettings()
}

extension EnvironmentValues {
    var quickAppsWidgetSettings: QuickAppsWidgetSettings {
        get { self[QuickAppsWidgetSettingsKey.self] }
        set { self[QuickAppsWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - TimerWidgetSettings

private struct TimerWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = TimerWidgetSettings()
}

extension EnvironmentValues {
    var timerWidgetSettings: TimerWidgetSettings {
        get { self[TimerWidgetSettingsKey.self] }
        set { self[TimerWidgetSettingsKey.self] = newValue }
    }
}

// MARK: - ClaudeUsageWidgetSettings

private struct ClaudeUsageWidgetSettingsKey: EnvironmentKey {
    static var defaultValue = ClaudeUsageWidgetSettings()
}

extension EnvironmentValues {
    var claudeUsageWidgetSettings: ClaudeUsageWidgetSettings {
        get { self[ClaudeUsageWidgetSettingsKey.self] }
        set { self[ClaudeUsageWidgetSettingsKey.self] = newValue }
    }
}
