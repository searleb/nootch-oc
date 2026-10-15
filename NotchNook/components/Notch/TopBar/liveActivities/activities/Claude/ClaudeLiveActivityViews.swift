import SwiftUI

enum ClaudeStyle {
    /// Claude's brand orange.
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)
}

/// One frame of the mark at `time` seconds: rays chasing around a ring (see `ClaudeBurst`).
struct ClaudeBurstFrame: View {
    var time: TimeInterval

    var body: some View {
        Canvas { graphics, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let turn = ClaudeBurst.rotation(at: time)
            let inner = radius * 0.2
            for (index, length) in ClaudeBurst.rayLengths(at: time).enumerated() {
                let angle = turn + Double(index) * 2 * .pi / Double(ClaudeBurst.rayCount)
                let outer = inner + (radius - inner) * length
                var ray = Path()
                ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                graphics.stroke(ray, with: .color(ClaudeStyle.orange),
                                style: StrokeStyle(lineWidth: radius * 0.24, lineCap: .round))
            }
        }
    }
}

/// The animated mark, redrawn about 30 times a second.
struct ClaudeBurstView: View {
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { context in
            ClaudeBurstFrame(time: animated ? context.date.timeIntervalSinceReferenceDate : 0)
        }
    }
}

/// Right wing while Claude works: the animated mark, still under Reduce Motion.
struct ClaudeWorkingIconView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ClaudeBurstView(animated: !reduceMotion)
            .frame(width: 16, height: 16)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Claude is working")
    }
}

/// Left wing while Claude works: how long the longest turn has run.
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
