//
//  NookView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 20/05/24.
//

import SwiftUI
import Defaults

struct NookView: View {
    @Environment(\.nookSettings) private var nookSettings

    /// Extra height added on top of the integer grid height (N × 50pt). Bumps the
    /// default 2-row Nook from 100pt to 125pt.
    static let extraHeight: CGFloat = 25

    var body: some View {
        let widgets = nookSettings.enabledWidgets
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.element) { i, widget in
                let arrPos = ArrayPosition(total: widgets.count, i: i)
                Group {
                    switch widget {
                    case .media:
                        MediaPlayerWidgetView(arrayPosition: arrPos)
                    case .shortcuts:
                        ShortcutsWidgetView(arrayPosition: ArrayPosition(total: widgets.count, i: i))
                    case .mirror:
                        MirrorWidgetView(arrayPosition: arrPos)
                    case .calendar:
                        CalendarWidgetView()
                    case .notes:
                        NotesWidgetView(arrayPosition: arrPos, internalPadding: nookSettings.widgetsPadding)
                    case .todoList:
                        TodoWidgetView(arrayPosition: arrPos, internalPadding: nookSettings.widgetsPadding)
                    case .timer:
                        TimerWidgetView(arrayPosition: arrPos, internalPadding: nookSettings.widgetsPadding)
                    case .claudeUsage:
                        ClaudeUsageWidgetView(arrayPosition: arrPos, internalPadding: nookSettings.widgetsPadding)
                    default: EmptyView()
                    }
                }
                .widgetDivider(arrPos: arrPos, disableDivider: !nookSettings.showDividers)
            }
        }
        .animation(.smooth, value: nookSettings.enabledWidgets)
        // Grid height (N × 50pt) plus a fixed extra band, so the default 2-row
        // Nook renders 125pt tall instead of 100. The grid is integer-only, so the
        // 25pt isn't grid-expressible — it's added here as a constant on top.
        .frame(height: nookSettings.size.height.screenPoints + NookView.extraHeight)
        .fixedSize()
//        .subToAllWidgetsSettingsChanges()
    }
}

struct VDivider: View {
    var color = Color.selected
    var body: some View {
        color
            .opacity(0.75)
            .frame(maxWidth: 1, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

private extension View {
    func widgetDivider(arrPos: ArrayPosition, disableDivider: Bool = false) -> some View {
        self
            .overlay(alignment: .trailing) { if arrPos != .last && arrPos != .single && !disableDivider { VDivider().opacity(0.75) } }
    }
}
