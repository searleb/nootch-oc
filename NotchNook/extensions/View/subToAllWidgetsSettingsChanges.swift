//
//  subToAllWidgetsSettingsChanges.swift
//  NotchNook
//
//  Created by Igor Marcossi on 31/07/24.
//

import SwiftUI
import Defaults

struct SubToAllWidgetsSettingsChangesModifier: ViewModifier {
    var animation: Animation
    
    @Environment(\.mediaWidgetSettings) private var mediaWidgetSettings
    @Environment(\.mirrorWidgetSettings) private var mirrorWidgetSettings
    @Environment(\.shortcutsWidgetSettings) private var shortcutsWidgetSettings
    @Environment(\.calendarWidgetSettings) private var calendarWidgetSettings
    @Environment(\.notesWidgetSettings) private var notesWidgetSettings
    @Environment(\.quickAppsWidgetSettings) private var quickAppsWidgetSettings
    @Environment(\.todoListWidgetSettings) private var todoListWidgetSettings
    @Environment(\.timerWidgetSettings) private var timerWidgetSettings
    @Environment(\.claudeUsageWidgetSettings) private var claudeUsageWidgetSettings
    
    func body(content: Content) -> some View {
        content
            .animation(animation, value: mediaWidgetSettings)
            .animation(animation, value: mirrorWidgetSettings)
            .animation(animation, value: shortcutsWidgetSettings)
            .animation(animation, value: calendarWidgetSettings)
            .animation(animation, value: notesWidgetSettings)
            .animation(animation, value: quickAppsWidgetSettings)
            .animation(animation, value: todoListWidgetSettings)
            .animation(animation, value: timerWidgetSettings)
            .animation(animation, value: claudeUsageWidgetSettings)
    }
}

extension View {
    func subToAllWidgetsSettingsChanges(animation: Animation = .spring) -> some View {
        self
            .modifier(SubToAllWidgetsSettingsChangesModifier(animation: animation))
    }
}
