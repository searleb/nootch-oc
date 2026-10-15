import Foundation

/// Reads Claude Code's session logs where they are, incrementally, and turns
/// them into per-profile snapshots and finished turns. Synchronous and free
/// of timers and UI so it can be tested against a temporary home folder; the
/// caller owns the thread and calls `poll` every couple of seconds.
final class ClaudeUsageEngine {
    struct Output {
        var profiles: [ClaudeProfileSnapshot]
        var finished: [ClaudeFinishedTurn]
    }

    static let discoveryInterval: TimeInterval = 60
    /// Sessions from the Claude desktop app's Code tab sign in with the desktop app's
    /// account, whichever folder they log to; the CLI and editors use the folder's login.
    private static let desktopEntrypoint = "claude-desktop"
    private static let desktopAccountID = "claude-desktop"

    private let home: URL
    private var profiles: [ClaudeProfile] = []
    private var lastDiscovery = Date.distantPast
    private var cursors: [String: ClaudeLogCursor] = [:]
    private var tracker = ClaudeTurnTracker()
    private var ledgers: [String: ClaudeUsageLedger] = [:]
    private var planSamples: [ClaudePlanLimits.Sample] = []
    private var planModified: Date?
    private var primed = false

    init(home: URL) {
        self.home = home
    }

    /// The first call reads today's history and reports nothing as finished, so
    /// replayed turns never alert; a turn still running then shows as working.
    func poll(now: Date = Date()) -> Output {
        refreshProfiles(now: now)
        refreshPlanHistory()
        let dayStart = Calendar.current.startOfDay(for: now)
        let desktop = desktopAccount()
        var finished: [ClaudeFinishedTurn] = []

        for profile in profiles {
            // Session logs first: a subagent's lines refresh the parent turn, which has to exist by then.
            for file in logFiles(in: profile, modifiedSince: dayStart).sorted(by: Self.sessionLogsFirst) {
                var cursor = cursors[file.url.path] ?? ClaudeLogCursor()
                guard file.size != cursor.offset else { continue }
                // `<session>/subagents/agent-<id>.jsonl`: the session comes from the path, as the
                // subagent's first lines do not name it.
                let isSubagentLog = file.url.path.contains("/subagents/")
                let pathSession = isSubagentLog ? file.url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent : nil
                let agentName = file.url.deletingPathExtension().lastPathComponent
                for line in ClaudeLogTailer.readNewLines(at: file.url, cursor: &cursor) {
                    for event in ClaudeLogParser.parse(line, state: &cursor.state, now: now) {
                        let account = cursor.state.entrypoint == Self.desktopEntrypoint ? desktop : profile
                        let parentKey = account.id + "|" + (pathSession ?? cursor.state.session)
                        let project = cursor.state.project
                        switch event {
                        case .usage(let record):
                            ledgers[account.id, default: ClaudeUsageLedger()].add(record)
                        case .sidechainActive(let date):
                            let at = date ?? now
                            // A subagent working is its parent turn working, however quiet the parent's own log.
                            _ = tracker.apply(.turnActive(at), key: parentKey, profileID: account.id, project: project, busy: false)
                            _ = tracker.apply(.turnBegan(at), key: parentKey + "|" + agentName, profileID: account.id, project: project, busy: false)
                        case .sidechainEnded(let date):
                            _ = tracker.apply(.turnActive(date), key: parentKey, profileID: account.id, project: project, busy: false)
                            // A subagent finishing is never announced; its parent's turn is.
                            _ = tracker.apply(.turnEnded(date, completed: true), key: parentKey + "|" + agentName,
                                              profileID: account.id, project: project, busy: false)
                        default:
                            if let done = tracker.apply(event, key: parentKey, profileID: account.id, project: project,
                                                        busy: !cursor.state.runningCommands.isEmpty) {
                                finished.append(done)
                            }
                        }
                    }
                }
                cursors[file.url.path] = cursor
            }
        }
        finished += tracker.closeIdle(now: now)

        let cutoff = now.addingTimeInterval(-ClaudeUsageLedger.retention)
        for id in ledgers.keys { ledgers[id]?.prune(before: cutoff) }

        if !primed {
            primed = true
            finished = []
        }
        return Output(profiles: snapshots(now: now, dayStart: dayStart, desktop: desktop), finished: finished)
    }

    private static func sessionLogsFirst(_ a: (url: URL, size: UInt64), _ b: (url: URL, size: UInt64)) -> Bool {
        !a.url.path.contains("/subagents/") && b.url.path.contains("/subagents/")
    }

    // MARK: Discovery

    private func refreshProfiles(now: Date) {
        guard now.timeIntervalSince(lastDiscovery) >= Self.discoveryInterval else { return }
        lastDiscovery = now
        profiles = ClaudeProfileDiscovery.discover(home: home)
    }

    private func refreshPlanHistory() {
        let url = ClaudePlanLimits.historyURL(home: home)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != planModified else { return }
        planModified = modified
        planSamples = (try? Data(contentsOf: url)).flatMap(ClaudePlanLimits.samples(from:)) ?? []
    }

    /// Every `.jsonl` under the profile's roots written today, with its size
    /// from the directory walk so unchanged files cost no open.
    private func logFiles(in profile: ClaudeProfile, modifiedSince cutoff: Date) -> [(url: URL, size: UInt64)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        var files: [(url: URL, size: UInt64)] = []
        for root in profile.roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in walker where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                      let modified = values.contentModificationDate, modified >= cutoff else { continue }
                files.append((url, UInt64(values.fileSize ?? 0)))
            }
        }
        return files
    }

    /// The account the desktop app is signed in to: the organization its own plan
    /// history records. It is the folder profile with that organization when there
    /// is one (the personal account, say), otherwise a profile of its own.
    private func desktopAccount() -> ClaudeProfile {
        let organization = planSamples.last?.organization
        if let organization, let match = profiles.first(where: { $0.organization == organization }) { return match }
        return ClaudeProfile(id: Self.desktopAccountID, label: "Claude app", roots: [], organization: organization)
    }

    // MARK: Snapshots

    private func snapshots(now: Date, dayStart: Date, desktop: ClaudeProfile) -> [ClaudeProfileSnapshot] {
        let open = tracker.openTurns
        var accounts = profiles
        // A profile of its own only once the desktop app has actually been used.
        if !accounts.contains(where: { $0.id == desktop.id }),
           ledgers[desktop.id] != nil || open.contains(where: { $0.profileID == desktop.id }) {
            accounts.append(desktop)
        }
        return accounts.map { profile in
            let ledger = ledgers[profile.id] ?? ClaudeUsageLedger()
            let live = open.filter { $0.profileID == profile.id }.map {
                ClaudeLiveSession(id: $0.key, profileID: profile.id, profileLabel: profile.label, project: $0.project,
                                  started: $0.started, lastActivity: $0.lastActivity)
            }
            let sessionStart = ClaudeSessionBlock.currentStart(
                ledger.dates(since: now.addingTimeInterval(-ClaudeSessionBlock.lookback)), now: now)
            let limits = ClaudePlanLimits.windows(from: planSamples, organization: profile.organization,
                                                  sessionStart: sessionStart, now: now)
            return ClaudeProfileSnapshot(id: profile.id, label: profile.label, live: live,
                                         today: ledger.summary(since: dayStart), limits: limits)
        }
    }
}
