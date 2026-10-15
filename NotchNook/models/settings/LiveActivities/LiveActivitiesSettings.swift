//
//  LiveActivitiesSettings.swift
//  NotchNook
//
//  Created by Igor Marcossi on 26/05/24.
//

import Foundation

struct LiveActivitiesSettings: Preferences {
    var enabled = true
    var hiddenInNonNotchedScreens = false
    var inactivityTimeoutInSecs: Double = 10
    var enabledLiveActivities: Set<LiveActivity> = [.tray, .media, .updateAvailable]
    var interactive = true
    var enableQuickPeek = true
    var enableHUDReplacement = false
    var HUDReplacementShouldShowInAllScreens = false
    var disableColorsOnAudioHUDReplacement = false
    var unhideAutomatically = true
    var quickPeekEvent = false
    /// LAs in this set are hidden when the current screen is in fullscreen.
    /// Empty by default — all LAs visible in fullscreen until user opts out.
    var liveActivitiesHiddenInFullscreen: Set<LiveActivity> = []
}
