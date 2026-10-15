import Foundation

/// Token counts reduced to the four buckets Claude bills for. `output` already
/// contains thinking tokens.
struct ClaudeTokens: Equatable {
    var input = 0
    var cacheWrite = 0
    var cacheRead = 0
    var output = 0

    var total: Int { input + cacheWrite + cacheRead + output }

    /// Share of everything the model read that came from the prompt cache; nil
    /// when nothing was read. Output is not part of it.
    var cacheHitRate: Double? {
        let read = input + cacheWrite + cacheRead
        return read > 0 ? Double(cacheRead) / Double(read) : nil
    }

    static func += (lhs: inout ClaudeTokens, rhs: ClaudeTokens) {
        lhs.input += rhs.input
        lhs.cacheWrite += rhs.cacheWrite
        lhs.cacheRead += rhs.cacheRead
        lhs.output += rhs.output
    }

    /// Streamed replies are logged once per content block and the earlier
    /// blocks carry counts so far, so the largest reading of each counter is final.
    func merged(with other: ClaudeTokens) -> ClaudeTokens {
        ClaudeTokens(input: max(input, other.input), cacheWrite: max(cacheWrite, other.cacheWrite),
                     cacheRead: max(cacheRead, other.cacheRead), output: max(output, other.output))
    }
}

/// One billed model response.
struct ClaudeUsageRecord: Equatable {
    /// Identifies the response across duplicate lines and files.
    let key: String
    let date: Date
    let model: String
    let project: String
    var tokens: ClaudeTokens
    /// Part of `tokens.cacheWrite` written to the 1-hour cache tier.
    var longCacheWrite: Int
}

struct ClaudeUsageSummary: Equatable {
    var tokens = ClaudeTokens()
    /// Estimated API value in US dollars at list prices.
    var cost = 0.0
    /// True when a model in the period has no known price, so `cost` undercounts.
    var hasUnpriced = false
    var requests = 0
}

/// A turn Claude is working on right now.
struct ClaudeLiveSession: Equatable, Identifiable {
    let id: String
    let profileID: String
    let profileLabel: String
    var project: String
    let started: Date
    var lastActivity: Date
}

struct ClaudeProfileSnapshot: Equatable, Identifiable {
    let id: String
    let label: String
    var live: [ClaudeLiveSession]
    var today: ClaudeUsageSummary
    var limits: [ClaudeLimitWindow]

    /// Whether the widget has anything to show for this profile.
    var hasActivity: Bool { !live.isEmpty || today.requests > 0 || !limits.isEmpty }
}

/// One plan allowance and how much of it is spent.
struct ClaudeLimitWindow: Equatable, Identifiable {
    enum Kind: String { case session, weekly }

    let kind: Kind
    let usedPercent: Double
    let resetsAt: Date?
    /// True when `resetsAt` is inferred from history rather than known.
    let isEstimate: Bool

    var id: String { kind.rawValue }
    var usedFraction: Double { min(1, max(0, usedPercent / 100)) }
}
