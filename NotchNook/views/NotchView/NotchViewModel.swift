//
//  NotchViewModel.swift
//  NotchNook
//
//  Created by Igor Marcossi on 28/06/24.
//

import SwiftUI

enum NotchState {
    case fineTuningWidth
    case fineTuningHeight
    case disabled
    case showingIntro
    case standardContent
}

@Observable
class NotchViewModel {
    // MARK: - File dropping info
    var droppingCoords: CGPoint?
    var availableActions = [Pipeline]()
    var targetsCoords = [String: CGRect]()
    
    // MARK: - Gestures info
    var pressing = false
    var hovering = false {
        willSet {
            if !hovering && newValue {
                vibrate()
            }
        }
    }
    var cancelPan = false
    var panRawPadding: EdgeInsets = .zero
    var panGestureCounter = 0
    
    // MARK: - General info
    var notchState: NotchState = .standardContent
    var scaleDown: Double = 0
    var animatingBack = false
    var showIntro = false
    
    // MARK: - Computed properties
    var hoveredDropTargetID: String? {
        guard let droppingCoords = droppingCoords else { return nil }
        return targetsCoords.first { $1.contains(droppingCoords) }?.key
    }
    
    var panPadding: EdgeInsets {
        let topInterpolator = interpolatorBuilder([0, 150], value: abs(panRawPadding.top))
        let leadingInterpolator = interpolatorBuilder([0, 150], value: panRawPadding.leading)
        let trailingInterpolator = interpolatorBuilder([0, 150], value: panRawPadding.trailing)
        let bottomInterpolator = interpolatorBuilder([0, 200], value: panRawPadding.bottom)
        
        let leading = leadingInterpolator([0, NotchView.maxHPanDrag + 8], true, .linear)
        let trailing = trailingInterpolator([0, NotchView.maxHPanDrag + 8], true, .linear)
        let bottom = bottomInterpolator([0, NotchView.maxVPanDrag + 8], true, .linear)
        
        let decrease = topInterpolator([0, 32], true, .linear)
        
        return EdgeInsets(
            top: 0,
            leading: ((bottom * 0.5) + leading) - decrease,
            bottom: ((((leading + trailing) / 2) * 0.25) + bottom) - decrease,
            trailing: ((bottom * 0.5) + trailing) - decrease
        )
    }
    
    func update(settings: GeneralSettings, isNonNotch: Bool, isFullScreen: Bool) {
        if isNonNotch && !settings.enableOnNonNotchScreens {
            notchState = .disabled
        } else {
            notchState = .standardContent
        }
    }
}
