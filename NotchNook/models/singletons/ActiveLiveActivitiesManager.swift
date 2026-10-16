//
//  ActiveLiveActivitiesManager.swift
//  NotchNook
//
//  Created by Igor Marcossi on 25/06/24.
//

import SwiftUI
import Defaults

@Observable
class ActiveLiveActivitiesManager {
    
    static let shared = ActiveLiveActivitiesManager()
    
    /// Activities that surface regardless of the user's toggle list or the master switch.
    static let alwaysOn: Set<LiveActivity> = [.timerExpired, .claudeFinished, .claudeWorking]

    static func visible(_ active: Set<LiveActivity>, liveActivitiesEnabled: Bool, enabled: Set<LiveActivity>) -> Set<LiveActivity> {
        guard liveActivitiesEnabled else { return active.intersection(alwaysOn) }
        return active.filter { alwaysOn.contains($0) || enabled.contains($0) }
    }

    var activeLiveActivities: Set<LiveActivity> {
        get {
            Self.visible(_activeLiveActivities, liveActivitiesEnabled: liveActivitiesSettingsCache.enabled,
                         enabled: liveActivitiesSettingsCache.enabledLiveActivities)
        }
        set {
            Task { @MainActor in
                withAnimation(TopBarView.animation) { _activeLiveActivities = newValue }
            }
        }
    }
    private var _activeLiveActivities = Set<LiveActivity>()
    private var liveActivitiesSettingsCache: LiveActivitiesSettings = Defaults[.liveActivitiesSettings]
    private var task: Task<Void, Never>?
    
    private init() {
        task = Task {
            for await value in Defaults.updates(.liveActivitiesSettings) {
                self.liveActivitiesSettingsCache = value
            }
        }
    }
    
    deinit {
        task?.cancel()
    }

    // MARK: - Synchronous main-thread mutations
    // Use these from @MainActor call sites to avoid the async Task hop in the
    // computed-property setter — the hop defers the write to the next run-loop
    // cycle, which means the view reads an empty set during the first layout pass
    // after insertion (notch grows but content is blank).

    @MainActor func insertSync(_ activity: LiveActivity) {
        _ = withAnimation(TopBarView.animation) { _activeLiveActivities.insert(activity) }
    }

    @MainActor func removeSync(_ activity: LiveActivity) {
        _ = withAnimation(TopBarView.animation) { _activeLiveActivities.remove(activity) }
    }
}
