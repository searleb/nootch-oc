import Foundation

/// The Claude desktop app checks the plan's limits itself and keeps a history
/// of percentages on this Mac. Only that file is read: no sign-in, no network.
/// The format is the app's own, so an unknown version is left out, not guessed.
enum ClaudePlanLimits {
    static let sessionLength: TimeInterval = 5 * 3600
    static let weekLength: TimeInterval = 7 * 86_400
    private static let maximumSize = 4 << 20

    struct Sample: Equatable {
        let date: Date
        let organization: String?
        /// Percent of the 5-hour session spent (`fh`).
        let session: Double?
        /// Percent of the weekly allowance spent (`sd`).
        let weekly: Double?
    }

    static func historyURL(home: URL) -> URL {
        home.appending(path: "Library/Application Support/Claude/plan-usage-history.json", directoryHint: .notDirectory)
    }

    /// Readings oldest first; nil for a file this reader does not know.
    static func samples(from data: Data) -> [Sample]? {
        guard data.count <= maximumSize,
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = (json["version"] as? NSNumber)?.intValue, version == 1 || version == 2,
              let entries = json["samples"] as? [[String: Any]] else { return nil }
        var result: [Sample] = []
        for entry in entries {
            guard let milliseconds = (entry["t"] as? NSNumber)?.doubleValue, milliseconds.isFinite, milliseconds > 0 else { continue }
            // The first version kept its windows beside the time.
            let values = version == 1 ? entry : (entry["u"] as? [String: Any] ?? [:])
            result.append(Sample(date: Date(timeIntervalSince1970: milliseconds / 1_000),
                                 organization: entry["org"] as? String,
                                 session: percent(values["fh"]), weekly: percent(values["sd"])))
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func percent(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { return nil }
        return min(100, max(0, number.doubleValue))
    }

    /// The latest reading for `organization` as limit windows. Samples from any
    /// other account are ignored: the app may be signed in to another one.
    static func windows(from samples: [Sample], organization: String?, sessionStart: Date?, now: Date) -> [ClaudeLimitWindow] {
        guard let organization else { return [] }
        let history = samples.filter { $0.organization == organization }.sorted { $0.date < $1.date }
        guard let latest = history.last, latest.date <= now.addingTimeInterval(300),
              now.timeIntervalSince(latest.date) < weekLength else { return [] }
        let age = now.timeIntervalSince(latest.date)
        var result: [ClaudeLimitWindow] = []

        // An old reading says nothing about a session that renewed since.
        if let used = latest.session, age < sessionLength {
            let reset = sessionReset(history, used: used, sessionStart: sessionStart)
            if reset.date.map({ $0 > now }) ?? true {
                result.append(ClaudeLimitWindow(kind: .session, usedPercent: used, resetsAt: reset.date, isEstimate: reset.isEstimate))
            }
        }
        if let used = latest.weekly {
            let renewal = weeklyRenewal(history, now: now)
            // Without a renewal date, a day-old week may have renewed.
            if renewal != nil || age < 86_400 {
                result.append(ClaudeLimitWindow(kind: .weekly, usedPercent: used, resetsAt: renewal, isEstimate: renewal != nil))
            }
        }
        return result
    }

    private static func sessionReset(_ history: [Sample], used: Double, sessionStart: Date?) -> (date: Date?, isEstimate: Bool) {
        guard used > 0 else { return (nil, false) }
        if let sessionStart { return (sessionStart.addingTimeInterval(sessionLength), false) }
        // The run of readings above zero that ends with the latest one: the
        // first of them is the latest the session can have begun.
        var index = history.count - 1
        while index > 0, let before = history[index - 1].session, before > 0,
              before <= (history[index].session ?? 0) + 1,
              history[index].date.timeIntervalSince(history[index - 1].date) < sessionLength {
            index -= 1
        }
        return (history[index].date.addingTimeInterval(sessionLength), true)
    }

    /// The next renewal after the last drop the history saw, rolled forward by weeks.
    private static func weeklyRenewal(_ history: [Sample], now: Date) -> Date? {
        guard history.count > 1 else { return nil }
        for index in stride(from: history.count - 1, to: 0, by: -1) {
            guard let before = history[index - 1].weekly, let after = history[index].weekly, after + 1 < before else { continue }
            var next = history[index].date.addingTimeInterval(weekLength)
            while next <= now { next.addTimeInterval(weekLength) }
            return next
        }
        return nil
    }
}
