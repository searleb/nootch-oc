//
//  LiveActivitiesCustomizeSettingsTabView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 26/05/24.
//

import SwiftUI
import Defaults

struct LiveActivitiesCustomizeSettingsTabView: View {
    
    @Default(.liveActivitiesSettings) private var liveActivitiesSettings
    
    var body: some View {
        MultipleSettingsPicker(
            // .timerExpired is always-on; exclude it from the user-configurable list
            elements: LiveActivity.allCases.filter(\.isUserConfigurable),
            activeElements: $liveActivitiesSettings.enabledLiveActivities
        ) { selectedActivity in
            MockLiveAcitivitiesView(activity: selectedActivity)
                .padding(.horizontal, 19)
        } settings: { selectedElement in
            switch selectedElement {
                case .media:
                    MediaLiveAcitivitySettingsView()
                case .tray:
                    TrayLiveActivitySettingsView()
                case .calendar:
                    CalendarLiveActivitySettingsView()
                    // TODO: uncomment when layout is sorted out
//                case .batteryVisualizer:
//                    BatteryLiveActivitySettingsView()
                case .batteryVisualizer:
                    BatteryLiveActivitySettingsView()
                case .bluetoothDevice, .updateAvailable, .timerExpired, .claudeWorking, .claudeFinished:
                    NoOptionsSettingsView()
            }
        }
    }
}

