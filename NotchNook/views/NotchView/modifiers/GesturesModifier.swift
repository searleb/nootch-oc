//
//  GesturesModifier.swift
//  NotchNook
//
//  Created by Igor Marcossi on 29/06/24.
//

import SwiftUI
import Defaults
#if SETAPP_BUILD
import Setapp
#endif

extension NotchView {
    struct GesturesModifier: ViewModifier {
        var state: NotchViewModel
        var disableNotchNook: Bool
        
        @Environment(\.notchNook) internal var notchNook
        @Environment(\.isEditingText) internal var isEditingText
        @Environment(\.resignFirstResponder) internal var resignFirstResponder
        @Environment(\.makeKeyWindow) private var makeKeyWindow
        @Environment(\.openSettings) internal var openSettings
        @Environment(\.openNotch) internal var openNotch
        @Environment(\.closeNotch) internal var closeNotch
        @Environment(\.tray) internal var tray
        @Environment(\.nookSettings) private var nookSettings
        @Environment(\.generalSettings) private var generalSettings

        func body(content: Content) -> some View {
            content
                .allowsHitTesting(!disableNotchNook)
                .onTapGesture {
                    resignFirstResponder()
                    if nookSettings.enabled && notchNook.mode == .closed && !state.showIntro { openNotch(.nook) }
                }
                .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 30, perform: {}, onPressingChanged: onLongPress)
                .onHover(perform: onHover)
                .contextMenu {
                    Button("Open Settings") { openSettings(nil) }
                    Button("Quit NotchNook") { NSApp.terminate(nil) }
                }
        }
        
        func onLongPress(_ pressing: Bool) {
            if state.hovering {
                withAnimation(NotchView.intenseAnimation) {
                    state.pressing = pressing
                }
            }
        }
        
        func onHover(_ hovering: Bool) {
            if hovering {
                // Claim key status unconditionally on hover-enter so the panel is already
                // key by the time a click arrives — prevents first-click being absorbed.
                makeKeyWindow()
                if notchNook.mode == .closed {
#if SETAPP_BUILD
                    SetappManager.shared.reportUsageEvent(.userInteraction)
#endif
                    
                    if !tray.files.isEmpty || generalSettings.alwaysOpenNotchOnHover {
                        openNotch(tray.files.isEmpty ? .nook : .tray)
                    } else {
                        withAnimation(.bouncy(duration: 0.4, extraBounce: 0.25)) {
                            state.hovering = true
                        }
                    }
                }
                // (key claim happens unconditionally on hover-enter above)
            } else {
                if (generalSettings.preventUnhoverCloseWhenTyping && isEditingText) || notchNook.locked { return }
                closeNotch(false, true)
            }
        }
    }
}
