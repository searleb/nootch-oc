import SwiftUI

enum ClaudeUsageLevel: Equatable {
    case normal, warning, critical

    static func level(forUsedFraction fraction: Double) -> ClaudeUsageLevel {
        fraction >= 0.9 ? .critical : fraction >= 0.7 ? .warning : .normal
    }

    var color: Color {
        switch self {
        case .normal: ClaudeStyle.orange
        case .warning: .yellow
        case .critical: .red
        }
    }
}

/// Plan limits, today's usage and what Claude is doing now, per profile.
/// Honours the same width, padding and corner-inset contract as the Timer widget.
struct ClaudeUsageWidgetView: View {
    var arrayPosition: ArrayPosition
    var internalPadding: Double

    @Environment(\.claudeUsageWidgetSettings) private var prefs
    @Environment(\.generalSettings) private var generalSettings
    @State private var store = ClaudeUsageStore.shared

    private var insets: TimerInsets {
        TimerInsets(arrayPosition: arrayPosition, contentPadding: generalSettings.contentPadding,
                    widgetPadding: internalPadding)
    }

    private var visibleProfiles: [ClaudeProfileSnapshot] { store.profiles.filter(\.hasActivity) }

    var body: some View {
        Group {
            if !store.isLoaded {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleProfiles.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(visibleProfiles) { ClaudeProfileBlock(profile: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, insets.top)
        .padding(.bottom, insets.bottom)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paddingDependingOnArrPos(arrayPosition: arrayPosition, padding: internalPadding)
        // Width from the grid; height fills the band the Nook gives us.
        .frame(width: prefs.size.width.screenPoints, alignment: .leading)
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 24))
                .foregroundStyle(Color.white.opacity(0.28))
            Text("No Claude activity yet")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClaudeProfileBlock: View {
    let profile: ClaudeProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ClaudeStyle.orange)
                Text(verbatim: profile.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 4)
                status
            }
            limits
            usage
        }
    }

    @ViewBuilder private var status: some View {
        if let session = profile.live.min(by: { $0.started < $1.started }) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(verbatim: "\(session.project) · \(ClaudeFormat.clock(context.date.timeIntervalSince(session.started)))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(ClaudeStyle.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Text("Idle")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder private var limits: some View {
        if profile.limits.isEmpty {
            Text("Limits unavailable")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        } else {
            HStack(alignment: .top, spacing: 10) {
                ForEach(profile.limits) { ClaudeLimitMeter(window: $0) }
            }
        }
    }

    @ViewBuilder private var usage: some View {
        if profile.today.requests == 0 {
            Text("No usage today")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        } else {
            let today = profile.today
            Text(verbatim: "\(ClaudeFormat.tokens(today.tokens.total)) tok · \(ClaudeFormat.cost(today.cost, approximate: today.hasUnpriced)) today")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ClaudeLimitMeter: View {
    let window: ClaudeLimitWindow

    private var level: ClaudeUsageLevel { .level(forUsedFraction: window.usedFraction) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(window.kind == .session ? "5h" : "Week")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                Text(verbatim: "\(Int(window.usedPercent.rounded()))%")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(level.color)
                            .frame(width: max(4, proxy.size.width * window.usedFraction))
                    }
                }
            if let resets = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(verbatim: "resets \(window.isEstimate ? "~" : "")\(ClaudeFormat.resetIn(resets, now: context.date))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Claude widget content") {
    let now = Date()
    let personal = ClaudeProfileSnapshot(
        id: "p", label: "Personal",
        live: [ClaudeLiveSession(id: "p|s", profileID: "p", profileLabel: "Personal", project: "nootch-oc",
                                 started: now.addingTimeInterval(-134), lastActivity: now)],
        today: ClaudeUsageSummary(tokens: ClaudeTokens(input: 120_000, cacheWrite: 400_000, cacheRead: 12_000_000, output: 90_000),
                                  cost: 6.53, hasUnpriced: false, requests: 52),
        limits: [ClaudeLimitWindow(kind: .session, usedPercent: 72, resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60), isEstimate: true),
                 ClaudeLimitWindow(kind: .weekly, usedPercent: 13, resetsAt: now.addingTimeInterval(5 * 86_400), isEstimate: true)])
    let work = ClaudeProfileSnapshot(
        id: "w", label: "Work", live: [],
        today: ClaudeUsageSummary(tokens: ClaudeTokens(input: 5_000, cacheWrite: 20_000, cacheRead: 300_000, output: 8_000),
                                  cost: 0.42, hasUnpriced: true, requests: 7),
        limits: [])
    VStack(alignment: .leading, spacing: 9) {
        ClaudeProfileBlock(profile: personal)
        ClaudeProfileBlock(profile: work)
    }
    .padding(12)
    .frame(width: 200, alignment: .leading)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
