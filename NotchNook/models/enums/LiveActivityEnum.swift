//
//  LiveActivity.swift
//  NotchNook
//
//  Created by Igor Marcossi on 27/05/24.
//

import SwiftUI

enum LiveActivity: String, Codable, MetaInfo, CaseIterable {
    
    case media
    case tray
    case calendar
    case updateAvailable
    case bluetoothDevice
    case batteryVisualizer
    /// Transient — fired by NookTimersStore.expire(). Always surfaces regardless of enabledLiveActivities.
    case timerExpired
    /// Shown while a Claude turn runs. Always surfaces: the Claude widget being in the Nook is the opt-in.
    case claudeWorking
    /// Transient — fired by ClaudeUsageStore when a long turn completes. Always surfaces.
    case claudeFinished
    
    var id: String { self.rawValue }
    
    var description: String? { nil }
    
    /// Whether this activity appears in the Live Activities settings list.
    /// `.timerExpired` is always-on (it's a user-initiated event) and has no settings toggle.
    var isImplemented: Bool {
        true
    }
    
    /// Whether this activity can be toggled by the user in settings.
    var isUserConfigurable: Bool {
        self != .timerExpired && self != .claudeFinished && self != .claudeWorking
    }
    
    var icon: String {
        return switch self {
            case .media: "music.note"
            case .tray: "tray.fill"
            case .calendar: "calendar.badge.clock.rtl"
            case .updateAvailable: "arrow.down.circle"
            case .bluetoothDevice: "airpods"
            case .batteryVisualizer: "bolt.fill"
            case .timerExpired: "timer"
            case .claudeWorking: "sparkle"
            case .claudeFinished: "checkmark.circle.fill"
        }
    }
    
    var name: String {
        return switch self {
            case .media: String(localized: "Media")
            case .tray: String(localized: "Files Tray")
            case .calendar: String(localized: "Calendar")
            case .updateAvailable: String(localized: "New Update")
            case .bluetoothDevice: String(localized: "Bluetooth")
            case .batteryVisualizer: String(localized: "Battery")
            case .timerExpired: String(localized: "Timer Ended")
            case .claudeWorking: String(localized: "Claude")
            case .claudeFinished: String(localized: "Claude Finished")
        }
    }
}
