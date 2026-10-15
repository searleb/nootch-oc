//
//  LiveActivitySelectionManager.swift
//  NotchNook
//
//  Created by Lori Montenegro on 29/05/25.
//

import SwiftUI
import EventKit
//import Algorithms
//import SwiftDate
//import Defaults

@Observable
class LiveActivitySelectionManager {
    static let shared = LiveActivitySelectionManager()
    
    // .timerExpired and .claudeFinished are alerts: they cut to the front.
    private var activitiesByPriority: [LiveActivity] = [.timerExpired, .claudeFinished, .bluetoothDevice, .batteryVisualizer, .tray, .calendar, .claudeWorking, .updateAvailable, .media]
    
    func selectActivity(from activeActivities: Set<LiveActivity>, batteryStatus: PowerMonitor.BatteryStatus? = nil, calendarSettings: CalendarLiveActivitySettings) -> LiveActivity? {
        guard !activeActivities.isEmpty else { return nil }
        
        let orderedActivities = sortActivitiesByPriority(activeActivities)
        
        // First, try to select an activity without special conditions
        if let firstActivity = orderedActivities.first {
            // Special handling for calendar activity
            if firstActivity == .calendar {
                let shouldShowCalendar = shouldShowCalendarActivity(settings: calendarSettings)
                if !shouldShowCalendar {
                    // If calendar shouldn't be shown, try next activity
                    return orderedActivities.count > 1 ? orderedActivities[1] : nil
                }
            }
            
            // Special handling for battery visualizer
            if firstActivity == .batteryVisualizer {
                if batteryStatus == nil {
                    // If no battery status, try next activity
                    return orderedActivities.count > 1 ? orderedActivities[1] : nil
                }
            }
            
            return firstActivity
        }
        
        return nil
    }
    
    func sortActivitiesByPriority(_ activeActivities: Set<LiveActivity>) -> [LiveActivity] {
        return activeActivities.sorted { activity1, activity2 in
            guard let index1 = activitiesByPriority.firstIndex(of: activity1),
                  let index2 = activitiesByPriority.firstIndex(of: activity2) else {
                return false
            }
            return index1 < index2
        }
    }
    
    func shouldShowCalendarActivity(settings: CalendarLiveActivitySettings) -> Bool {
        guard let event = closestEvent(settings: settings) else { return false }
        return CalendarManager.shared.shouldShowCalendarActivity(event: event, settings: settings)
    }
    
    func shouldShowEventTimeView(settings: CalendarLiveActivitySettings) -> Bool {
        guard let event = closestEvent(settings: settings) else { return true }
        return event.startDate < Date() ? settings.showEventTimeLapsed : true
    }
    
    func isFirstActivityCalendar(activeActivities: Set<LiveActivity>, settings: CalendarLiveActivitySettings) -> Bool {
        let orderedActivities = sortActivitiesByPriority(activeActivities)
        return orderedActivities.first == .calendar &&
        shouldShowCalendarActivity(settings: settings) &&
        orderedActivities.count == 1
    }
    
    func shouldEnableQuickPeekForTime(isFirstActivityCalendar: Bool, liveActivitiesSettings: LiveActivitiesSettings) -> Bool {
        !isFirstActivityCalendar && liveActivitiesSettings.enableQuickPeek
    }
    
    func closestEvent(settings: CalendarLiveActivitySettings) -> EKEvent? {
        let events = CalendarManager.shared.events
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        
        let filteredEvents = events.filter { event in
            !event.isAllDay &&
            event.startDate >= yesterday &&
            event.startDate <= tomorrow &&
            event.endDate > now
        }
        
        // Check for events within pre-event window
        let preEventWindowEvents = filteredEvents.filter { event in
            let timeUntilEventStart = event.startDate.timeIntervalSince(now)
            return timeUntilEventStart > 0 && timeUntilEventStart <= Double(settings.preEventWindow * 60)
        }
        
        // If there are events within pre-event window, return the closest one
        if let closestPreEventWindowEvent = preEventWindowEvents.min(by: { $0.startDate < $1.startDate }) {
            return closestPreEventWindowEvent
        }
        
        return filteredEvents.min(by: { abs($0.startDate.timeIntervalSince(now)) < abs($1.startDate.timeIntervalSince(now)) })
    }
}
