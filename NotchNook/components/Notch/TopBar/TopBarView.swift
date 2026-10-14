//
//  TopBarView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 19/05/24.
//

import SwiftUI
import Defaults

struct TopBarView: View {
    
    static let animation: Animation = .bouncy(extraBounce: 0.075)
    static let maxHeight: CGFloat = 32
    /// Visual bottom edge of topbar buttons (pill height 26pt, centered in maxHeight).
    /// Widget content must start at or below this value to avoid overlapping tab buttons and gear.
    static let buttonsVisualBottom: CGFloat = 2
    static let liveActionWidth: CGFloat = 35
    static let collapsedTopBarHalfWidth: CGFloat = 88
    
    var panGestureCounter: Int
    var scaleX: Double = 1
    var scaleY: Double = 1
    var panPadding: EdgeInsets
    var isHidden: Bool
    var isDisabledDueToFullscreen: Bool
    
    private var liveActivities: Set<LiveActivity> {
        ActiveLiveActivitiesManager.shared.activeLiveActivities
    }
    @Environment(\.notchSize) private var notchSize
    @Environment(\.notchNook) private var notchNook
    @Environment(\.liveActivitiesSettings) private var liveActivitiesSettings
    @Environment(\.generalSettings) private var generalSettings

    private var shouldHide: Bool {
        if isHidden { return true }
        if notchSize.height != 0 {
            // for notched screen
            return false
        } else {
            // for non notched screen
            return notchNook.mode == .closed && (liveActivities.isEmpty || liveActivitiesSettings.hiddenInNonNotchedScreens)
        }
    }

    var body: some View {
        let height = getHeight(notchSize.height)
        let mode = notchNook.mode
        let shouldShowContent = !isHidden && (mode != .closed || !isDisabledDueToFullscreen)
        
        if !shouldHide {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if shouldShowContent {
                        TopBarContentView(isLeft: true, scaleX: scaleX, scaleY: scaleY, isScreenInFullscreen: isDisabledDueToFullscreen)
                    }
                    
                    if (mode != .closed && !isHidden) || !liveActivities.isEmpty {
                        TopBarSpacerView(height: height)
                    }
                    
                    if shouldShowContent {
                        TopBarContentView(isLeft: false, scaleX: scaleX, scaleY: scaleY, isScreenInFullscreen: isDisabledDueToFullscreen)
                    }
                }
                .animation(.smooth(extraBounce: 0.25), value: liveActivities)
                .animation(.smooth(extraBounce: 0.25), value: shouldHide)
                .background {
                    HStack(spacing: 0) {
                        TopBarBackgroundView(isLeft: true, panGestureCounter: panGestureCounter, scaleX: scaleX, scaleY: scaleY, panPadding: panPadding)
                        
                        TopBarSpacerView(height: height)
                        
                        TopBarBackgroundView(isLeft: false, panGestureCounter: panGestureCounter, scaleX: scaleX, scaleY: scaleY, panPadding: panPadding)
                    }
                }
                .frame(height: getHeight(notchSize.height))
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
            }
        }

        if let quickPeeks = notchNook.quickPeeks {
            QuickPeeksView(quickPeeks: quickPeeks)
                .id(quickPeeks)
                .transition(.scaleAndBlur(anchor: quickPeeks.first?.anchor ?? .topLeading, blur: 15))
        }
    }
    
    /// If notch height is bigger than 2/3 of minHeight, use it
    private func getHeight(_ notchHeight: CGFloat) -> CGFloat {
        if notchHeight == 0 {
            return isDisabledDueToFullscreen && notchNook.mode == .closed ? 0.5 : generalSettings.handleSize.height
        } else {
            return notchHeight > (TopBarView.maxHeight * 0.66) ? notchHeight : TopBarView.maxHeight
        }
    }
}

