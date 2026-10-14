//
//  defaults.swift
//  NotchNook
//
//  Created by Ethan Bills on 5/23/24.
//

import SwiftUI
import Defaults


// Define the defaults keys
extension Defaults.Keys {
    static let lastVersionNumber = Key<String>("lastVersionNumber", default: "0")

    static let intro = Key<Bool>("intro", default: true)
    
    // General settings
    static let generalSettings = Key<GeneralSettings>("generalSettings", default: .init())
    static let gestureControlSettings = Key<GestureControlSettings>("gestureControlSettings", default: .init())
    static let liveActivitiesSettings = Key<LiveActivitiesSettings>("liveActivitiesSettings", default: .init())
    static let nookSettings = Key<NookSettings>("nookSettings", default: .init())
    static let traySettings = Key<TraySettings>("traySettings", default: .init())
    static let dropAreaSettings = Key<DropAreaSettings>("dropAreaSettings", default: .init())
    static let defaultMirrorDevice = Key<String>("defaultMirrorDevice", default: "")
    static let mirrorCameraInputWhenAvail = Key<Bool>("mirrorCameraInputWhenAvail", default: true)
    // Live activities settings
    static let mediaLiveActivitySettings = Key<MediaLiveActivitySettings>("mediaLiveActivitySettings", default: .init())
    static let calendarLiveActivitySettings = Key<CalendarLiveActivitySettings>("calendarLiveActivitySettings", default: .init())
    static let batteryLiveActivitySettings = Key<BatteryLiveActivitySettings>("batteryLiveActivitySettings", default: .init())
    
    // Widgets settings
    static let mediaWidgetSettings = Key<MediaWidgetSettings>("mediaWidgetSettings", default: .init())
    static let shortcutsWidgetSettings = Key<ShortcutsWidgetSettings>("shortcutsWidgetSettings", default: .init())
    static let mirrorWidgetSettings = Key<MirrorWidgetSettings>("mirrorWidgetSettings", default: .init())
    static let calendarWidgetSettings = Key<CalendarWidgetSettings>("calendarWidgetSettings", default: .init())
    static let notesWidgetSettings = Key<NotesWidgetSettings>("notesWidgetSettings", default: .init())
    static let todoListWidgetSettings = Key<TodoListWidgetSettings>("todoListWidgetSettings", default: .init())
    static let quickAppsWidgetSettings = Key<QuickAppsWidgetSettings>("quickAppsWidgetSettings", default: .init())
    static let timerWidgetSettings = Key<TimerWidgetSettings>("timerWidgetSettings", default: .init())
}
