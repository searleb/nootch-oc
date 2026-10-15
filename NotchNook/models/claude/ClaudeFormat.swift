import Foundation

enum ClaudeFormat {
    /// `2:14` or `1:02:05`, for a running clock.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// The clock for the 35pt notch wing: `m:ss` under an hour, then `1h02m`, never wider than five characters.
    static func compactClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%dh%02dm", h, m) : String(format: "%d:%02d", m, s)
    }

    /// `45s`, `2m 14s`, `1h 05m`, for a finished span.
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    static func tokens(_ count: Int) -> String {
        switch count {
        case ..<1_000: return "\(count)"
        case ..<100_000: return String(format: "%.1fK", Double(count) / 1_000)
        case ..<1_000_000: return String(format: "%.0fK", Double(count) / 1_000)
        default: return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }

    /// `approximate` appends `+` when some usage had no known price.
    static func cost(_ value: Double, approximate: Bool = false) -> String {
        let body = value >= 100 ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
        return approximate ? body + "+" : body
    }

    static func resetIn(_ date: Date, now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }
}
