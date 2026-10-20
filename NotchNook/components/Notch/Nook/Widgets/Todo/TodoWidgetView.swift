//
//  TodoWidgetView.swift
//  NotchNook
//

import SwiftUI

struct TodoWidgetView: View {
    var arrayPosition: ArrayPosition
    var internalPadding: Double

    @Environment(\.todoListWidgetSettings) private var prefs
    @State private var store = RemindersTodoStore.shared
    @State private var newTaskText: String = ""

    private var visibleItems: [TodoTask] {
        TodoVisibility.visible(store.tasks, showCompleted: prefs.showCompleted,
                               archiveAfterDays: prefs.autoArchiveCompletedAfterDays, now: Date())
    }

    var body: some View {
        Group {
            switch store.access {
            case .unknown:
                Color.clear
            case .needsPermission:
                message(icon: "checklist", text: String(localized: "Keep your to-dos in Reminders"),
                        button: String(localized: "Connect Reminders")) { store.requestAccess() }
            case .denied:
                message(icon: "lock", text: String(localized: "NotchNook can't access Reminders"),
                        button: String(localized: "Open Privacy Settings")) { store.openPrivacySettings() }
            case .granted:
                if store.isLoaded { list } else { ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
        }
        .onAppear { store.start() }
        .paddingDependingOnArrPos(arrayPosition: arrayPosition, padding: internalPadding)
        // Width from the grid; height fills the Nook band (grid-height + 25pt).
        .frame(width: prefs.size.width.screenPoints, alignment: .leading)
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 4) {
            TodoCreatorView(text: $newTaskText) {
                addItem()
            }

            if let problem = store.problem {
                Text(verbatim: problem)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange.opacity(0.85))
                    .lineLimit(2)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(visibleItems) { item in
                        TodoRowView(item: item,
                                    onToggleCompleted: { store.setCompleted(item, !item.isCompleted) },
                                    onTogglePriority: { store.setPriority(item, !item.isPriority) },
                                    onDelete: { store.delete(item) })
                    }
                }
            }
        }
    }

    private func message(icon: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.white.opacity(0.3))
            Text(verbatim: text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(verbatim: button)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addItem() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.add(title: trimmed)
        newTaskText = ""
    }
}
