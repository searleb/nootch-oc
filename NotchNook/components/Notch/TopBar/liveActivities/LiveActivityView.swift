//
//  LiveActivityView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 15/06/24.
//

import SwiftUI
import EventKit

struct LiveActivityView: View {
    
    enum ActivitySide {
        case left, right
    }
    var side: ActivitySide
    var activeActivities: Set<LiveActivity>
    
    @Environment(\.liveActivitiesSettings) private var liveActivitiesSettings
    @Environment(\.mediaLiveActivitySettings) private var mediaLiveActivitySettings
    @Environment(\.calendarLiveActivitySettings) private var calendarLiveActivitySettings
    
    @State private var batteryStatus: PowerMonitor.BatteryStatus?
    @State private var expiredTimerStore = NookTimersStore.shared
    
    var activitiesManager = LiveActivitySelectionManager.shared
    
    // MARK: Computed properties
    
    private var shouldShowEventTimeView: Bool {
        activitiesManager.shouldShowEventTimeView(settings: calendarLiveActivitySettings)
    }
    
    private var isFirstActivityCalendar: Bool {
        activitiesManager.isFirstActivityCalendar(activeActivities: activeActivities, settings: calendarLiveActivitySettings)
    }
    
    private var shouldEnableQuickPeekForTime: Bool {
        activitiesManager.shouldEnableQuickPeekForTime(isFirstActivityCalendar: isFirstActivityCalendar, liveActivitiesSettings: liveActivitiesSettings)
    }
    
    private var activityToShow: LiveActivity? {
        activitiesManager.selectActivity(from: activeActivities, batteryStatus: batteryStatus, calendarSettings: calendarLiveActivitySettings)
    }
    
    private var closestEvent: EKEvent? {
        CalendarManager.shared.closestEvent(settings: calendarLiveActivitySettings)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if let activityToShow {
                switch activityToShow {
                    case .calendar:
                        if let event = closestEvent {
                            switch side {
                                case .left:
                                    EventIconView(eventTitle: event.title, startDate: event.startDate, endDate: event.endDate, enableQuickPeek: liveActivitiesSettings.enableQuickPeek)
                                case .right:
                                    if shouldShowEventTimeView {
                                        EventTimeView(event: event, startDate: event.startDate, endDate: event.endDate)
                                            .environment(\.enableQuickPeek, shouldEnableQuickPeekForTime)
                                    } else {
                                        Spacer()
                                    }
                            }
                        }
                        
                    case .media:
                        switch side {
                            case .left:
                                MiniAlbumCoverView(enableQuickPeek: liveActivitiesSettings.enableQuickPeek,
                                                   quickPeekEvent: liveActivitiesSettings.quickPeekEvent,
                                                   albumCornerRadius: mediaLiveActivitySettings.albumCornerRadius)
                            case .right:
                                AudioAnimationView()
                        }
                        
                    case .tray:
                        switch side {
                            case .left:
                                LiveActivityIconView(liveActivity: .tray)
                            case .right:
                                TrayFilesCountView()
                        }
                        
                    case .updateAvailable:
                        switch side {
                            case .left:
                                UpdateAppIconView(enableQuickPeek: liveActivitiesSettings.enableQuickPeek)
                            case .right:
                                UpdateButtonIconView()
                        }
                        
                    case .bluetoothDevice:
                        switch side {
                            case .left:
                                BluetoothDeviceIconView()
                            case .right:
                                BluetoothConnectDisconnectView()
                        }
                        
                    case .batteryVisualizer:
                        switch side {
                            case .left:
                                BatteryIconView(batteryStatus: batteryStatus)
                            case .right:
                                TimeLeftView(batteryStatus: batteryStatus)
                        }
                        
                    case .timerExpired:
                        switch side {
                            case .left:
                                LiveActivityIconView(liveActivity: .timerExpired)
                            case .right:
                                Text(expiredTimerStore.currentExpiredLabel.isEmpty
                                     ? "Timer ended"
                                     : expiredTimerStore.currentExpiredLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                        }

                    case .claudeWorking:
                        switch side {
                            case .left:
                                ClaudeElapsedView()
                            case .right:
                                ClaudeWorkingIconView()
                        }

                    case .claudeFinished:
                        switch side {
                            case .left:
                                ClaudeFinishedDurationView()
                            case .right:
                                ClaudeFinishedIconView()
                        }
                }
            }
        }
        .transition(.scaleAndBlur)
        .onChange(of: PowerMonitor.shared.status) { _, status in
            batteryStatus = status
        }
    }

}
