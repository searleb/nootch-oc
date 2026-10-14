//
//  GeneralSettingsView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 25/05/24.
//

import SwiftUI
import Settings
import Defaults
import LaunchAtLogin

struct GeneralSettingsView: View {
    
    @Default(.generalSettings) private var generalSettings
    @Default(.gestureControlSettings) private var gestureControlSettings
    
    var body: some View {
        let contentMaxWidth: Double = 340
        let defaultGeneral = GeneralSettings()
        
        Settings.Container(contentWidth: 550.0, minimumLabelWidth: 200) {
            Settings.Section(title: "", bottomDivider: true) {
                LaunchAtLogin.Toggle {
                    Text("Launch at login")
                }
            }
            
            Settings.Section(title: String(localized: "Show in fullscreen:")) {
                Picker("", selection: $generalSettings.showInFullscreen) {
                    Text("On all monitors").tag(FullscreenOption.allMonitors)
                    Text("On notched screens").tag(FullscreenOption.notchedScreens)
                    Text("Never").tag(FullscreenOption.never)
                }
                .frame(width: 170)
                .padding(.leading, -8)
            }
            
            Settings.Section(title: String(localized: "Media source:")) {
                Picker("", selection: $generalSettings.preferredMediaSource) {
                    Text("System").tag(MediaSource.systemWide)
                    Text("Spotify").tag(MediaSource.spotify)
                    Text("Apple Music").tag(MediaSource.appleMusic)
                }
                .frame(width: 170)
                .padding(.leading, -8)
            }
            
            Settings.Section(title: String(localized: "Notch:")) {
                Toggle("Prefer round buttons", isOn: $generalSettings.preferRoundButtons)
                Text("Use capsules instead of rounded rectangles for buttons.")
                    .optionDescription(contentMaxWidth)
                
                Toggle("Transluscent notch background (experimental)", isOn: $generalSettings.transluscent)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 340, alignment: .leading)
                
                Toggle("Always open on hover", isOn: $generalSettings.alwaysOpenNotchOnHover)
                Text("This will disable some of NotchNook's gestures.")
                    .optionDescription(contentMaxWidth)
                
                Toggle("Disable haptics", isOn: $generalSettings.disableHaptics)
            }
            
            Settings.Section(title: String(localized: "Typing effects:")) {
                Toggle("Prevent from closing on mouse leave", isOn: $generalSettings.preventUnhoverCloseWhenTyping)
                Toggle("Lock while typing", isOn: $generalSettings.lockNNWhenTyping)
                    .disabled(!generalSettings.preventUnhoverCloseWhenTyping)
            }
            
            Settings.Section(title: String(localized: "Content padding:")) {
                SliderPlus(value: $generalSettings.contentPadding, range: 0...32)
            }
            
            Settings.Section(title: String(localized: "Notch fine tune:"), bottomDivider: true) {
                Text(String(localized: "NotchNook tries its best to guess your notch size, but sometimes it can be a bit off. Here you can fine tune it. It has to be exactly the same of your notch."))
                    .optionDescription(contentMaxWidth)

                HStack(spacing: 8) {
                        Text("Width:").frame(width: 45, alignment: .leading)
                        SliderPlusNegative(value: $generalSettings.notchWidthFineTune, range: -24...24, step: 1)
                        let num = generalSettings.notchWidthFineTune
                        Text("\(num > 0 ? "+" : "")\(Int(num))")
                        .frame(width: 24, alignment: .leading)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Height:").frame(width: 45, alignment: .leading)
                        SliderPlusNegative(value: $generalSettings.notchHeightFineTune, range: -24...24, step: 1)
                        let num = generalSettings.notchHeightFineTune
                        Text("\(num > 0 ? "+" : "")\(Int(num))")
                            .frame(width: 24, alignment: .leading)
                    }
            }
            
            Settings.Section(title: String(localized: "Handler (no-notch screens):"), bottomDivider: true) {
                Toggle("Enable", isOn: $generalSettings.enableOnNonNotchScreens)
                
                CustomLabeled(title: String(localized: "Width")) {
                    SliderPlus(value: $generalSettings.handleSize.width, range: 30...250, step: 16)
                        .disabled(!generalSettings.enableOnNonNotchScreens)
                }
                .resetToDefault($generalSettings.handleSize.width, defaultGeneral.handleSize.width)
                
                CustomLabeled(title: String(localized: "Height")) {
                    SliderPlus(value: $generalSettings.handleSize.height, range: 1...TopBarView.maxHeight)
                        .disabled(!generalSettings.enableOnNonNotchScreens)
                }
                .resetToDefault($generalSettings.handleSize.height, defaultGeneral.handleSize.height)
                
                Toggle("Transparent handler", isOn: $generalSettings.transparentHandle)
                    .disabled(!generalSettings.enableOnNonNotchScreens)
                
                Text("Will only show up on mouse hover.")
                    .optionDescription(contentMaxWidth)
                    .resetToDefault($generalSettings.handleSize.height, defaultGeneral.handleSize.height)
            }
            
            Settings.Section(title: String(localized: "Others:")) {
                Toggle("Demo mode", isOn: $generalSettings.demoMode)
                Text("Prevents NotchNook from hiding when idle. Useful for screen recordings (this has no effect on non-notched screens).")
                    .optionDescription(contentMaxWidth)
                
                Button("Reset all settings") { resetDefaults() }
                Text("This will reset all settings to their defaults.")
                    .optionDescription(contentMaxWidth)
                
                
                Button("Quit NotchNook") { NSApp.terminate(nil) }
                Text("You can also right click it.")
                    .optionDescription(contentMaxWidth)
            }
        }
        .frame(width: 610)
    }
}

let GeneralSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .general,
        title: String(localized: "General"),
        toolbarIcon: NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "General settings")!
    ) {
        GeneralSettingsView()
    }
    
    return Settings.PaneHostingController(pane: paneView)
}
