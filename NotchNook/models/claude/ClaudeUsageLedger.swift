import Foundation

/// De-duplicated usage records for one profile.
struct ClaudeUsageLedger {
    /// Enough for today's total plus the current 5-hour session block.
    static let retention: TimeInterval = 36 * 3600

    private var records: [String: ClaudeUsageRecord] = [:]

    mutating func add(_ record: ClaudeUsageRecord) {
        guard var existing = records[record.key] else {
            records[record.key] = record
            return
        }
        existing.tokens = existing.tokens.merged(with: record.tokens)
        existing.longCacheWrite = max(existing.longCacheWrite, record.longCacheWrite)
        records[record.key] = existing
    }

    mutating func prune(before cutoff: Date) {
        records = records.filter { $0.value.date >= cutoff }
    }

    func dates(since start: Date) -> [Date] {
        records.values.filter { $0.date >= start }.map(\.date)
    }

    func summary(since start: Date) -> ClaudeUsageSummary {
        var summary = ClaudeUsageSummary()
        for record in records.values where record.date >= start {
            summary.requests += 1
            summary.tokens += record.tokens
            if let cost = ClaudePricing.cost(record.tokens, longCacheWrite: record.longCacheWrite, model: record.model) {
                summary.cost += cost
            } else {
                summary.hasUnpriced = true
            }
        }
        return summary
    }
}

/// Claude's plan session is a five-hour window that begins with the first
/// request, on the hour. The logs place it; the desktop app's file only
/// reports percentages.
enum ClaudeSessionBlock {
    static let length: TimeInterval = 5 * 3600
    static let lookback: TimeInterval = 12 * 3600

    /// The start of the block holding `now`; nil when the last one has ended.
    static func currentStart(_ dates: [Date], now: Date) -> Date? {
        var start: Date?
        for date in dates.sorted() where date <= now {
            if let current = start, date < current.addingTimeInterval(length) { continue }
            start = hour(of: date)
        }
        guard let start, now < start.addingTimeInterval(length) else { return nil }
        return start
    }

    /// Allowances renew on the hour in UTC.
    static func hour(of date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
    }
}
