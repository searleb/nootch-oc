//
//  AboutSettingsView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 01/06/24.
//

import SwiftUI
import Settings
#if !SETAPP_BUILD
import Sparkle
#endif
import Defaults

struct AboutSettingsView: View {
#if !SETAPP_BUILD
    @State private var sparkleManager: SparkleManager
#endif
    @Environment(\.showChangelog) private var showChangelog
#if !SETAPP_BUILD
    init(sparkleManager: SparkleManager) {
        self._sparkleManager = .init(initialValue: sparkleManager)
    }
#endif
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(.internalAppIcon).resizable()
                    .frame(96)
                
                VStack(spacing: 3) {
                    HStack(alignment: .bottom) {
                        Text("NotchNook").font(.title).fontWeight(.bold)
                        Spacer()
#if !SETAPP_BUILD
                        Button("Check for Updates…", action: sparkleManager.checkForUpdates)
                            .disabled(!sparkleManager.canCheckForUpdates)
                            .padding(.bottom, 3)
#endif
                    }
                    
                    HStack(alignment: .top) {
                        (Text("v\(getAppVersion()) ").font(.callout) + Text("(see changelog)").font(.caption).underline().foregroundStyle(.primary.opacity(0.5)))
                            .opacity(0.75)
                            .onTapGesture(perform: showChangelog)
                        Spacer()
#if !SETAPP_BUILD
                        HStack {
                            if sparkleManager.automaticallyChecksForUpdates {
                                Toggle("Auto download updates", isOn: $sparkleManager.automaticallyDownloadsUpdates)
                            }
                            Toggle("Auto check for updates", isOn: $sparkleManager.automaticallyChecksForUpdates)
                                .onChange(of: sparkleManager.automaticallyChecksForUpdates) { oldValue, newValue in
                                    if !newValue {
                                        sparkleManager.automaticallyDownloadsUpdates = false
                                        Defaults[.liveActivitiesSettings].enabledLiveActivities.remove(.updateAvailable)
                                    } else {
                                        Defaults[.liveActivitiesSettings].enabledLiveActivities.insert(.updateAvailable)
                                    }
                                }
                        }
#endif
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .defaultSettingsProps(height: nil)
    }
}

#if !SETAPP_BUILD
let AboutSettingsViewController: (
    _ sparkleManager: SparkleManager,
    _ showChangelog: (() -> ())?
) -> SettingsPane = { sparkleManager, showChangelog in
    let paneView = Settings.Pane(
        identifier: .about,
        title: String(localized: "About"),
        toolbarIcon: NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "About settings")!
    ) {
        AboutSettingsView(sparkleManager: sparkleManager)
            .environment(\.sparkleManager, sparkleManager)
            .environment(\.showChangelog, showChangelog ?? {})
    }
    
    return Settings.PaneHostingController(pane: paneView)
}
#else 
let AboutSettingsViewController: (
    _ showChangelog: (() -> ())?
) -> SettingsPane = { showChangelog in
    let paneView = Settings.Pane(
        identifier: .about,
        title: String(localized: "About"),
        toolbarIcon: NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "About settings")!
    ) {
        AboutSettingsView()
            .environment(\.showChangelog, showChangelog ?? {})
    }
    
    return Settings.PaneHostingController(pane: paneView)
}
#endif
