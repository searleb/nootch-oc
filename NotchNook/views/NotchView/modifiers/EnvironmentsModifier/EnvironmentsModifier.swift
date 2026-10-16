//
//  EnvironmentsModifier.swift
//  NotchNook
//
//  Created by Igor Marcossi on 28/06/24.
//

import SwiftUI
import Defaults

extension NotchView {
    struct EnvironmentsModifier: ViewModifier {
        var state: NotchViewModel

        @Environment(\.mediaWidgetSettings) internal var mediaWidgetSettings
        @Environment(\.notesWidgetSettings) internal var notesWidgetSettings
        @Environment(\.mirrorWidgetSettings) internal var mirrorWidgetSettings
        @Environment(\.calendarWidgetSettings) internal var calendarWidgetSettings
        @Environment(\.shortcutsWidgetSettings) internal var shortcutsWidgetSettings
        @Environment(\.todoListWidgetSettings) internal var todoListWidgetSettings
        @Environment(\.quickAppsWidgetSettings) internal var quickAppsWidgetSettings
        @Environment(\.timerWidgetSettings) internal var timerWidgetSettings
        @Environment(\.claudeUsageWidgetSettings) internal var claudeUsageWidgetSettings
        
        @Default(.nookSettings) internal var nookSettings
        @Namespace internal var ns
        @Environment(\.generalSettings) private var generalSettings
        @Environment(\.notchNook) internal var notchNook
        @Environment(\.resignFirstResponder) internal var resignFirstResponder
        @Environment(\.isEditingText) internal var isEditingText
        
        var nookWidgetsWidth: NookGrid.Point {
            return nookSettings.enabledWidgets.reduce(.zero) {
                let adding = switch $1 {
                    case .calendar: calendarWidgetSettings.size.width
                    case .media: mediaWidgetSettings.size.width
                    case .mirror: mirrorWidgetSettings.size.width
                    case .notes: notesWidgetSettings.size.width
                    case .quickApps: quickAppsWidgetSettings.size.width
                    case .shortcuts: shortcutsWidgetSettings.size.width
                    case .todoList: todoListWidgetSettings.size.width
                    case .timer: timerWidgetSettings.size.width
                    case .claudeUsage: claudeUsageWidgetSettings.size.width
                }
                return $0 + adding
            }
        }
        
        func body(content: Content) -> some View {
            content
                .environment(\.hideNotch, hideNotch)
                .environment(\.closeNotch, closeNotch)
                .environment(\.openNotch, openNotch)
                .environment(\.nookWidgetsWidth, nookWidgetsWidth)
                .environment(\.namespace, ns)
                .transformEnvironment(\.notchSize) { if $0.width != 0 { $0.width += generalSettings.notchWidthFineTune } }
                .transformEnvironment(\.notchSize) { if $0.height != 0 { $0.height += generalSettings.notchHeightFineTune } }
                .preferredColorScheme(.dark)
        }
    }
}
