//
//  Notch.swift
//  Notchway
//
//  Created by Igor Marcossi on 12/05/24.
//

import SwiftUI
import Defaults
import Cocoa
import UniformTypeIdentifiers

struct NotchView: View {
    
    @State internal var viewModel = NotchViewModel()
    @State private var isFullScreen = false
    
    @Environment(\.notchSize) internal var rawNotchSize
    @Environment(\.screenSize) internal var screenSize
    var screen: NSScreen
    @Environment(\.notchNook) internal var notchNook
    @Environment(\.generalSettings) internal var generalSettings
    @Default(.intro) internal var intro
    @Environment(\.showIndicator) var showIndicator
    
    private var isNonNotch: Bool {
        rawNotchSize.height == 0
    }
    
    private var notchSize: CGSize {
        if isNonNotch {
            return rawNotchSize
        } else {
            var newNotchSize = rawNotchSize
            newNotchSize.width += generalSettings.notchWidthFineTune * 0.5
            newNotchSize.height += generalSettings.notchHeightFineTune * 0.5
            return newNotchSize
        }
    }
    
    private var isDisabled: Bool {
        isNonNotchAndDisabled && (!shouldShowIndicator)
    }
    
    private var shouldShowIndicator: Bool {
        notchNook.indicator != nil && NSScreen.main == screen
    }
    
    private var isNonNotchAndDisabled: Bool {
        isNonNotch && !generalSettings.enableOnNonNotchScreens
    }
    
    private var isDisabledDueToFullScreen: Bool {
        switch generalSettings.showInFullscreen {
            case .allMonitors:
                return false
            case .notchedScreens:
                return isNonNotch && isFullScreen
            case .never:
                return isFullScreen
        }
    }
    
    private var isHeightFineTuning: Bool {
        viewModel.notchState == .fineTuningHeight
    }
    
    private var nonNotchHeight: CGFloat {
        generalSettings.transparentHandle || isDisabledDueToFullScreen ? 0.5 : generalSettings.handleSize.height
    }
    
    var body: some View {
        let nonNotchWidth = generalSettings.handleSize.width
        let nnMinWidth = isNonNotch ? nonNotchWidth : notchSize.width
        let nnMinHeight = isDisabled || isHeightFineTuning ? 0 : isNonNotch ? nonNotchHeight : notchSize.height
        
        Group {
            if let indicator = notchNook.indicator {
                IndicatorView(indicator: indicator)
                    .transition(NotchView.defaultTransition)
            } else {
                switch viewModel.notchState {
                    case .disabled:
                        EmptyView()
                    case .showingIntro:
                        IntroView()
                    case .fineTuningWidth:
                        VStack(alignment: .center, spacing: NotchView.mainVSpacing) {
                            TopBarSpacerView(height: notchSize.height)
                            
                            if !isNonNotch {
                                WidthFineTuningView(fineTuningValue: generalSettings.notchWidthFineTune)
                            }
                        }
                    case .standardContent:
                        TopBarView(
                            panGestureCounter: viewModel.panGestureCounter,
                            scaleX: actualScaleX,
                            scaleY: actualScaleY,
                            panPadding: viewModel.panPadding,
                            isHidden: notchNook.hidden,
                            isDisabledDueToFullscreen: isDisabledDueToFullScreen
                        )
                        .opacity(notchNook.indicator == nil ? 1 : 0)

                        Group {
                            switch notchNook.mode {
                                case .closed:
                                    EmptyView()
                                case .dragging:
                                    DropArea(targetsCoords: $viewModel.targetsCoords, availableActions: viewModel.availableActions, hoveredDropTargetID: viewModel.hoveredDropTargetID)
                                case .nook:
                                    NookView()
                                case .tray:
                                    TrayView(hovered: false, full: true)
                            }
                        }
                        .transition(NotchView.defaultTransition)
                        .scaleEffect(x: actualScaleX, y: actualScaleY, anchor: .init(x: 0.5, y: -0.25))
                        
                    case .fineTuningHeight:
                        if !isNonNotch {
                            HeightFineTuningView(fineTuningValue: generalSettings.notchHeightFineTune)
                                .frame(width: 40, alignment: .leading)
                                .offset(x: -100)
                        }
                }
            }
        }
        .blur(radius: viewModel.scaleDown * 150)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: isHeightFineTuning ? nnMinWidth + 40 : nnMinWidth, minHeight: nnMinHeight)
        .padding((notchNook.mode == .closed ? viewModel.panPadding : .zero) + standardPadding)
        .coordinateSpace(name: "drop-zone")
        .modifier(ShapeModifier(state: viewModel))
        .modifier(LockedIndicatorModifier(state: viewModel))
        .offset(x: (-viewModel.panPadding.leading + viewModel.panPadding.trailing) / 3)
        .modifier(AnimationsModifier(disableNotchNook: isDisabled))
        .modifier(GesturesModifier(state: viewModel, disableNotchNook: isDisabled))
        .frame(width: screenSize.width, height: NotchView.windowHeight, alignment: .top)
        .modifier(EnvironmentsModifier(state: viewModel))
        .modifier(SideEffectsModifier(viewModel: viewModel, showIndicator: showIndicator, screen: screen))
        .onChange(of: FullscreenMonitor.shared.fullScreenStateDict) { _, updatedFullscreenDict in
            withAnimation(.easeInOut(duration: 0.1)) {
                isFullScreen = updatedFullscreenDict[screen] ?? false
                viewModel.update(settings: generalSettings, isNonNotch: isNonNotch, isFullScreen: isFullScreen)
            }
        }
        .onChange(of: generalSettings.enableOnNonNotchScreens) {
            withAnimation(.easeInOut(duration: 0.5)) {
                viewModel.update(settings: generalSettings, isNonNotch: isNonNotch, isFullScreen: isFullScreen)
            }
        }
        .onAppear {
            isFullScreen = FullscreenMonitor.shared.fullScreenStateDict[screen] ?? false
            viewModel.update(settings: generalSettings, isNonNotch: isNonNotch, isFullScreen: isFullScreen)
        }
        .animation(.smooth(extraBounce: 0.25), value: nonNotchHeight)
        .task {
            _ = try? await CalendarManager.shared.fetchEvents()
        }
    }
}
