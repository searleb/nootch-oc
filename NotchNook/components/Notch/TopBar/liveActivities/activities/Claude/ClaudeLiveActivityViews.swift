import SwiftUI

enum ClaudeStyle {
    /// Claude's brand orange.
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)
}

/// Left wing while Claude works: a pulsing mark.
struct ClaudeWorkingIconView: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ClaudeStyle.orange)
            .symbolEffect(.pulse, options: .repeating)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Claude is working")
    }
}

/// Right wing while Claude works: how long the longest turn has run.
struct ClaudeElapsedView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let session = store.workingSession {
                Text(verbatim: ClaudeFormat.clock(context.date.timeIntervalSince(session.started)))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(ClaudeStyle.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Left wing when a turn finishes.
struct ClaudeFinishedIconView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(ClaudeStyle.orange)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(store.currentFinished?.accessibilityText ?? "Claude finished")
    }
}

/// Right wing when a turn finishes: how long it took. The wing is only 35pt
/// wide, so the profile and project live in the accessibility label and the widget.
struct ClaudeFinishedDurationView: View {
    @State private var store = ClaudeUsageStore.shared

    var body: some View {
        if let alert = store.currentFinished {
            Text(verbatim: ClaudeFormat.duration(alert.duration))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
        }
    }
}
