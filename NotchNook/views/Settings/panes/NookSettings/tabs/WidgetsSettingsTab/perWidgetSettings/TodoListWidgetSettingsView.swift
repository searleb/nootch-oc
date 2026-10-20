//
//  TodoListWidgetSettingsView.swift
//  NotchNook
//

import SwiftUI
import Settings
import Defaults

struct TodoListWidgetSettingsView: View {

    @Default(.todoListWidgetSettings) private var todoListWidgetSettings

    var body: some View {
        Settings.Container(contentWidth: 520.0) {
            Settings.Section {
                Text("Width:").frame(minWidth: 160, alignment: .trailing)
            } content: {
                SliderPlus(value: $todoListWidgetSettings.size.width.double, range: 3...16)

                Text("Tasks are kept in the \"NotchNook\" list in Reminders, so they sync to your other devices.")
                    .optionDescription(280)

                Toggle("Show completed tasks", isOn: $todoListWidgetSettings.showCompleted)
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(
                        "Auto-archive after \(todoListWidgetSettings.autoArchiveCompletedAfterDays == 0 ? "never" : "\(todoListWidgetSettings.autoArchiveCompletedAfterDays) day\(todoListWidgetSettings.autoArchiveCompletedAfterDays == 1 ? "" : "s")")",
                        value: $todoListWidgetSettings.autoArchiveCompletedAfterDays,
                        in: 0...365
                    )
                    Text("Completed tasks older than this are hidden. Set to 0 to keep them forever.")
                        .optionDescription(280)
                }
            }
        }
    }
}
