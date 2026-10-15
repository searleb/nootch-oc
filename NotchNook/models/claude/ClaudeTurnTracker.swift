import Foundation

struct ClaudeOpenTurn: Equatable {
    let key: String
    let profileID: String
    var project: String
    let started: Date
    var lastActivity: Date
    /// A Bash command is running, so a quiet log is expected.
    var busy: Bool
}

struct ClaudeFinishedTurn: Equatable {
    let profileID: String
    let project: String
    let started: Date
    let duration: TimeInterval
    /// False for interruptions, errors and turns closed for going quiet.
    let completed: Bool
}

/// Open turns across all profiles and sessions, keyed by `profileID|session`.
struct ClaudeTurnTracker {
    /// A turn with no new lines for this long is taken to be dead (crashed session).
    static let idleLimit: TimeInterval = 10 * 60
    /// Same, while a Bash command is still waiting for its result.
    static let busyLimit: TimeInterval = 3 * 3600

    private var open: [String: ClaudeOpenTurn] = [:]

    var openTurns: [ClaudeOpenTurn] { open.values.sorted { $0.started < $1.started } }

    mutating func apply(_ event: ClaudeLogEvent, key: String, profileID: String, project: String,
                        busy: Bool) -> ClaudeFinishedTurn? {
        switch event {
        case .turnBegan(let date):
            if var turn = open[key] {
                turn.lastActivity = max(turn.lastActivity, date)
                turn.busy = busy
                open[key] = turn
            } else {
                open[key] = ClaudeOpenTurn(key: key, profileID: profileID, project: project,
                                           started: date, lastActivity: date, busy: busy)
            }
        case .turnActive(let date):
            guard var turn = open[key] else { return nil }
            if let date { turn.lastActivity = max(turn.lastActivity, date) }
            if !project.isEmpty { turn.project = project }
            turn.busy = busy
            open[key] = turn
        case .turnEnded(let date, let completed):
            guard let turn = open.removeValue(forKey: key) else { return nil }
            return ClaudeFinishedTurn(profileID: turn.profileID, project: turn.project, started: turn.started,
                                      duration: max(0, date.timeIntervalSince(turn.started)), completed: completed)
        case .usage:
            break
        }
        return nil
    }

    mutating func closeIdle(now: Date) -> [ClaudeFinishedTurn] {
        var closed: [ClaudeFinishedTurn] = []
        for (key, turn) in open {
            let limit = turn.busy ? Self.busyLimit : Self.idleLimit
            guard now.timeIntervalSince(turn.lastActivity) > limit else { continue }
            open.removeValue(forKey: key)
            closed.append(ClaudeFinishedTurn(profileID: turn.profileID, project: turn.project, started: turn.started,
                                             duration: max(0, turn.lastActivity.timeIntervalSince(turn.started)),
                                             completed: false))
        }
        return closed
    }
}
