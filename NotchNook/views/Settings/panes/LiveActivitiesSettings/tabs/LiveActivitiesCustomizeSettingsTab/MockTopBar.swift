//
//  MockTopBar.swift
//  NotchNook
//
//  Created by Igor Marcossi on 27/05/24.
//

import SwiftUI
import Defaults
import SwiftDate

struct MockTopBar: View {
    
    var activity: LiveActivity
    
    @Environment(\.notchSize) private var notchSize
    @Environment(\.mediaLiveActivitySettings) private var mediaLiveActivitySettings
    @Environment(\.gestureControlSettings) private var gestureControlSettings
    @Environment(\.liveActivitiesSettings) private var liveActivitiesSettings
    @Environment(\.calendarLiveActivitySettings) private var calendarLiveActivitySettings
    @Environment(\.nookSettings) private var nookSettings
    @Environment(\.traySettings) private var traySettings
    
    @SilentState private var fakeNow = Date()
    
    func staticNow() -> Date {
        fakeNow - calendarLiveActivitySettings.preEventWindow.minutes
    }
    
    var body: some View {
        let height = notchSize.height > ((TopBarView.maxHeight / 3) * 2) ? notchSize.height : TopBarView.maxHeight
        let mockedEvent = NookEvent(
            id: "mock-event",
            startDate: fakeNow,
            endDate: fakeNow + 1.hours,
            title: "",
            notes: nil
        )
        
        HStack(spacing: 0) {
            Group {
                switch activity {
                    case .calendar: 
                        EventIconView(
                            eventTitle: mockedEvent.title,
                            startDate: mockedEvent.startDate,
                            endDate: mockedEvent.endDate,
                            enableQuickPeek: liveActivitiesSettings.enableQuickPeek
                        )
                        .environment(\.getNow, staticNow)
                    case .media: 
                        AlbumCoverView(
                            id: "sample-album",
                            artwork: .loCafeAvatar,
                            cornerRadius: mediaLiveActivitySettings.albumCornerRadius
                        )
                        .padding(.all, 6)
                    case .tray: 
                        LiveActivityIconView(liveActivity: .tray)
                    case .updateAvailable:
                        UpdateAppIconView(enableQuickPeek: liveActivitiesSettings.enableQuickPeek)
                    case .bluetoothDevice:
                        LiveActivityIconView(liveActivity: .bluetoothDevice)
                    case .batteryVisualizer:
                        LiveActivityIconView(liveActivity: .batteryVisualizer)
                            .padding(.all, 6)
                            .foregroundStyle(.yellow)
                    case .timerExpired:
                        EmptyView()
                    case .claudeWorking:
                        Text(verbatim: "2:14")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(ClaudeStyle.orange)
                    case .claudeFinished:
                        EmptyView()
                }
            }
            .frame(width: TopBarView.liveActionWidth)
            .transition(NotchView.defaultTransition(anchor: .trailing, delay: 0.075))
            .allowsHitTesting(liveActivitiesSettings.interactive)
            
            TopBarSpacerView(height: height)
            
            Group {
                switch activity {
                    case .calendar:
                        EventTimeView(
                            startDate: mockedEvent.startDate,
                            endDate: mockedEvent.endDate
                        )
                        .environment(\.getNow, staticNow)
                    case .media:
                        // Force the effect to animate in the settings preview even when
                        // nothing is actually playing (otherwise it sits frozen).
                        AudioAnimationView(altIsPlaying: true)
                    case .tray:
                        TrayFilesCountView()
                    case .updateAvailable:
                        UpdateButtonIconView()
                    case .bluetoothDevice:
                        BluetoothConnectDisconnectView()
                            .padding(.top, 6)
                    case .batteryVisualizer:
                        TimeLeftView(batteryStatus: PowerMonitor.shared.status)
                    case .timerExpired:
                        EmptyView()
                    case .claudeWorking:
                        ClaudeWorkingIconView()
                    case .claudeFinished:
                        EmptyView()
                }
            }
            .frame(width: TopBarView.liveActionWidth)
            .transition(NotchView.defaultTransition(anchor: .leading, delay: 0.075))
            .allowsHitTesting(liveActivitiesSettings.interactive)
        }
        .animation(.smooth(extraBounce: 0.25), value: activity)
        .frame(height: height)
        .fixedSize(horizontal: false, vertical: true)
        .zIndex(1)
        .allowsHitTesting(false)
    }
}
