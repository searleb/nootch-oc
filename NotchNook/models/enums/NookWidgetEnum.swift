//
//  NookWidget.swift
//  NotchNook
//
//  Created by Igor Marcossi on 27/05/24.
//

import SwiftUI
import Defaults

enum NookWidget: String, MetaInfo, Codable, CaseIterable {
    
    case calendar
    case media
    case shortcuts
    case mirror
    case notes
    case quickApps
    case todoList
    case timer
    case claudeUsage
    
    var id: String { self.rawValue }
    
    var description: String? {
        switch gridSizeType {
            case .unique(let size):
                "\(size.width.value) cells"
            default:
                "\(prefs.size.width.value) cells"
        }
    }
    
    var isImplemented: Bool {
        switch self {
            case .quickApps:
                false
            default:
                true
        }
    }
    
    var icon: String {
        switch self {
            case .media: "music.note"
            case .shortcuts: "sparkles"
            case .mirror: "web.camera.fill"
            case .calendar: "calendar"
            case .notes: "note.text"
            case .quickApps: "circle.grid.2x2.fill"
            case .todoList: "checklist"
            case .timer: "timer"
            case .claudeUsage: "sparkle"
        }
    }
    
    var name: String {
        switch self {
            case .media: String(localized: "Media Player")
            case .shortcuts: String(localized: "Shortcuts")
            case .mirror: String(localized: "Mirror")
            case .calendar: String(localized: "Calendar")
            case .notes: String(localized: "Notes")
            case .quickApps: String(localized: "Quick Apps")
            case .todoList: String(localized: "To-dos")
            case .timer: String(localized: "Timer")
            case .claudeUsage: String(localized: "Claude Usage")
        }
    }
    
    var prefs: any WidgetPrefs {
        switch self {
            case .calendar: Defaults[.calendarWidgetSettings]
            case .media: Defaults[.mediaWidgetSettings]
            case .shortcuts: Defaults[.shortcutsWidgetSettings]
            case .mirror: Defaults[.mirrorWidgetSettings]
            case .notes: Defaults[.notesWidgetSettings]
            case .quickApps: Defaults[.quickAppsWidgetSettings]
            case .todoList: Defaults[.todoListWidgetSettings]
            case .timer: Defaults[.timerWidgetSettings]
            case .claudeUsage: Defaults[.claudeUsageWidgetSettings]
        }
    }
    
    var gridSizeType: NookGridSizeType {
        switch self {
            case .media: .unique(.init(width: MediaWidgetSettings().size.width, height: MediaWidgetSettings().size.height))
            case .mirror: .unique(.init(width: MirrorWidgetSettings().size.width, height: MirrorWidgetSettings().size.height))
            case .quickApps: .unique(.init(width: MirrorWidgetSettings().size.width, height: MirrorWidgetSettings().size.height))
            case .calendar: .variable
            case .shortcuts: .variable
            case .notes: .variable
            case .todoList: .variable
            case .timer: .variable
            case .claudeUsage: .variable
        }
    }
    
    enum NookGridSizeType {
        case unique(NookGrid.Size)
        case multiple([NookGrid.Size])
        case variable
    }
}
