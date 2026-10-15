import SwiftUI
import Settings
import Defaults

struct ClaudeUsageWidgetSettingsView: View {
    @Default(.claudeUsageWidgetSettings) private var settings

    var body: some View {
        Settings.Container(contentWidth: 320) {
            Settings.Section(title: "", bottomDivider: true) {
                Text("Width:")
                SliderPlus(value: $settings.size.width.double, range: 3...8)
            }

            Settings.Section(title: "", bottomDivider: true) {
                Toggle(String(localized: "Notify when Claude finishes"), isOn: $settings.notifyOnFinish)
                    .padding(.vertical, 4)
            }

            Settings.Section(title: "", bottomDivider: true) {
                Toggle(String(localized: "Play sound when Claude finishes"), isOn: $settings.playSound)
                    .padding(.vertical, 4)
            }

            Settings.Section(title: "") {
                Text(verbatim: String(localized: "Only for turns longer than") + " \(Int(settings.minFinishSeconds))s")
                SliderPlus(value: $settings.minFinishSeconds, range: 0...120, step: 5)
            }
        }
        .padding(0)
    }
}
