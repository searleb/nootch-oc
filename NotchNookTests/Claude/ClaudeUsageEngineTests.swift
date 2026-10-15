import XCTest
@testable import NotchNook

final class ClaudeUsageEngineTests: XCTestCase {
    private var home: URL!
    private let now = Date()

    override func setUp() { home = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: home) }

    private func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }
    private func log(_ relative: String) -> URL { home.appending(path: relative) }
    private let work = ".claude/projects/-Users-x-Sites-anywhere/s1.jsonl"

    private func makeProjects(_ dir: String) {
        try! FileManager.default.createDirectory(at: home.appending(path: "\(dir)/projects"), withIntermediateDirectories: true)
    }

    private func snapshot(_ output: ClaudeUsageEngine.Output, _ label: String) -> ClaudeProfileSnapshot? {
        output.profiles.first { $0.label == label }
    }

    func testPrimingReplaysHistoryWithoutAnnouncingAndStillTotalsIt() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(300)),
                               ClaudeFixtures.assistant(at: ago(200), stop: "end_turn", input: 1_000, output: 500)], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(output.finished, [], "history replayed at launch must never alert")
        XCTAssertEqual(snapshot(output, "Work")?.today.requests, 1)
        XCTAssertEqual(snapshot(output, "Work")?.today.tokens.output, 500)
        XCTAssertEqual(snapshot(output, "Work")?.live, [])
    }

    func testTurnAlreadyRunningAtLaunchShowsAsWorking() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(40)),
                               ClaudeFixtures.assistant(at: ago(20), stop: "tool_use")], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(output.finished, [])
        let live = snapshot(output, "Work")?.live
        XCTAssertEqual(live?.count, 1)
        XCTAssertEqual(live?.first?.project, "anywhere")
        XCTAssertEqual(live?.first?.profileLabel, "Work")
    }

    func testStaleOpenTurnFromHistoryIsDroppedSilently() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(3_600))], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(snapshot(output, "Work")?.live, [])
        XCTAssertEqual(output.finished, [])
    }

    func testTurnFinishingAfterLaunchAnnouncesOnce() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        XCTAssertEqual(engine.poll(now: ago(30)).finished, [])

        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20))], to: log(work))
        let working = engine.poll(now: ago(19))
        XCTAssertEqual(snapshot(working, "Work")?.live.count, 1)
        XCTAssertEqual(working.finished, [])

        ClaudeFixtures.append([ClaudeFixtures.assistant(at: ago(5), stop: "end_turn")], to: log(work))
        let done = engine.poll(now: ago(4))
        XCTAssertEqual(done.finished.count, 1)
        XCTAssertTrue(done.finished[0].completed)
        XCTAssertEqual(done.finished[0].project, "anywhere")
        XCTAssertEqual(done.finished[0].duration, 15, accuracy: 0.01)
        XCTAssertEqual(snapshot(done, "Work")?.live, [])
        XCTAssertEqual(engine.poll(now: now).finished, [], "an announced turn is not announced again")
    }

    func testInterruptedTurnIsReportedIncomplete() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        _ = engine.poll(now: ago(30))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20)), ClaudeFixtures.interrupt(at: ago(10))], to: log(work))
        let output = engine.poll(now: ago(9))
        XCTAssertEqual(output.finished.count, 1)
        XCTAssertFalse(output.finished[0].completed)
    }

    func testSubagentFilesCountTokensButNeverOpenOrCloseTheParentTurn() {
        makeProjects(".claude")
        let engine = ClaudeUsageEngine(home: home)
        _ = engine.poll(now: ago(30))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20))], to: log(work))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(15), sidechain: true),
                               ClaudeFixtures.assistant(at: ago(10), stop: "end_turn", messageID: "side", input: 77, sidechain: true)],
                              to: log(".claude/projects/-Users-x-Sites-anywhere/s1/subagents/agent-1.jsonl"))
        let output = engine.poll(now: ago(9))
        XCTAssertEqual(output.finished, [])
        XCTAssertEqual(snapshot(output, "Work")?.live.count, 1, "the parent turn is still running")
        XCTAssertEqual(snapshot(output, "Work")?.today.tokens.input, 77)
    }

    func testPersonalLimitsAttachOnlyToThePersonalProfile() {
        makeProjects(".claude")
        makeProjects(".claude-personal")
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: log(".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: log(".claude-personal/.claude.json"))
        let sampleMs = Int(ago(60).timeIntervalSince1970 * 1_000)
        let history = #"{"version":2,"samples":[{"t":\#(sampleMs),"org":"org-personal","u":{"fh":21,"sd":13}}]}"#
        let planURL = ClaudePlanLimits.historyURL(home: home)
        try! FileManager.default.createDirectory(at: planURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(history.utf8).write(to: planURL)

        let output = ClaudeUsageEngine(home: home).poll(now: now)

        XCTAssertEqual(output.profiles.map(\.label), ["Work", "Personal"])
        XCTAssertEqual(snapshot(output, "Work")?.limits, [])
        XCTAssertEqual(snapshot(output, "Personal")?.limits.map(\.kind), [.session, .weekly])
        XCTAssertEqual(snapshot(output, "Personal")?.limits.first?.usedPercent, 21)
    }

    func testUnknownOrMissingAccountOrHistoryMeansNoLimitsNotACrash() {
        makeProjects(".claude")
        try! Data("garbage".utf8).write(to: log(".claude.json"))
        let planURL = ClaudePlanLimits.historyURL(home: home)
        try! FileManager.default.createDirectory(at: planURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(#"{"version":99}"#.utf8).write(to: planURL)
        XCTAssertEqual(snapshot(ClaudeUsageEngine(home: home).poll(now: now), "Work")?.limits, [])
    }

    func testTwoProfilesKeepSeparateTurns() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(10), session: "w")], to: log(".claude/projects/-a/w.jsonl"))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(8), session: "p")], to: log(".claude-personal/projects/-b/p.jsonl"))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(snapshot(output, "Work")?.live.count, 1)
        XCTAssertEqual(snapshot(output, "Personal")?.live.count, 1)
    }

    func testFilesNotTouchedTodayAreNotRead() throws {
        let old = log(work)
        ClaudeFixtures.append([ClaudeFixtures.assistant(at: ago(5 * 86_400), stop: "end_turn", input: 999)], to: old)
        try FileManager.default.setAttributes([.modificationDate: ago(5 * 86_400)], ofItemAtPath: old.path)
        XCTAssertEqual(snapshot(ClaudeUsageEngine(home: home).poll(now: now), "Work")?.today.requests, 0)
    }

    // MARK: Which account wrote a session

    /// The desktop app's Code tab signs in with the desktop app's account but logs to
    /// `~/.claude`, the same folder the work CLI uses.
    private func writePlanHistory(org: String) {
        let sampleMs = Int(ago(60).timeIntervalSince1970 * 1_000)
        let history = #"{"version":2,"samples":[{"t":\#(sampleMs),"org":"\#(org)","u":{"fh":21,"sd":13}}]}"#
        let planURL = ClaudePlanLimits.historyURL(home: home)
        try! FileManager.default.createDirectory(at: planURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(history.utf8).write(to: planURL)
    }

    func testDesktopAppSessionsBelongToTheDesktopAppsAccountNotTheFoldersProfile() {
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: log(".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: log(".claude-personal/.claude.json"))
        makeProjects(".claude-personal")
        writePlanHistory(org: "org-personal")   // the desktop app's account
        // Both sessions are in ~/.claude; only the entrypoint tells them apart.
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(30), session: "desk", cwd: "/Users/x/Sites/nootch-oc", entrypoint: "claude-desktop"),
                               ClaudeFixtures.assistant(at: ago(20), stop: "tool_use", session: "desk", messageID: "d1", input: 111,
                                                        cwd: "/Users/x/Sites/nootch-oc", entrypoint: "claude-desktop")],
                              to: log(".claude/projects/-Users-x-Sites-nootch-oc/desk.jsonl"))
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(25), session: "term", cwd: "/Users/x/Sites/anywhere", entrypoint: "cli"),
                               ClaudeFixtures.assistant(at: ago(15), stop: "end_turn", session: "term", messageID: "t1", input: 222, entrypoint: "cli")],
                              to: log(".claude/projects/-Users-x-Sites-anywhere/term.jsonl"))

        let output = ClaudeUsageEngine(home: home).poll(now: now)

        XCTAssertEqual(output.profiles.map(\.label), ["Work", "Personal"], "the desktop account maps onto the profile with the same organization")
        XCTAssertEqual(snapshot(output, "Personal")?.live.map(\.project), ["nootch-oc"])
        XCTAssertEqual(snapshot(output, "Personal")?.today.tokens.input, 111)
        XCTAssertEqual(snapshot(output, "Work")?.live, [])
        XCTAssertEqual(snapshot(output, "Work")?.today.tokens.input, 222)
        XCTAssertEqual(snapshot(output, "Personal")?.limits.count, 2)
    }

    func testFinishedDesktopTurnIsReportedForTheDesktopAccount() {
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: log(".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: log(".claude-personal/.claude.json"))
        makeProjects(".claude")
        makeProjects(".claude-personal")
        writePlanHistory(org: "org-personal")
        let engine = ClaudeUsageEngine(home: home)
        _ = engine.poll(now: ago(30))
        let desk = log(".claude/projects/-Users-x-Sites-nootch-oc/desk.jsonl")
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(20), session: "desk", entrypoint: "claude-desktop")], to: desk)
        ClaudeFixtures.append([ClaudeFixtures.assistant(at: ago(5), stop: "end_turn", session: "desk", entrypoint: "claude-desktop")], to: desk)
        let output = engine.poll(now: ago(4))
        XCTAssertEqual(output.finished.count, 1)
        let personal = snapshot(output, "Personal")
        XCTAssertEqual(output.finished.first?.profileID, personal?.id)
    }

    func testDesktopSessionsWithNoMatchingProfileGetTheirOwnClaudeAppProfile() {
        makeProjects(".claude")
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: log(".claude.json"))
        writePlanHistory(org: "org-elsewhere")
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(30), session: "desk", entrypoint: "claude-desktop"),
                               ClaudeFixtures.assistant(at: ago(20), stop: "end_turn", session: "desk", messageID: "d1", input: 5, entrypoint: "claude-desktop")], to: log(work))
        let output = ClaudeUsageEngine(home: home).poll(now: now)
        XCTAssertEqual(output.profiles.map(\.label), ["Work", "Claude app"])
        XCTAssertEqual(snapshot(output, "Claude app")?.today.tokens.input, 5)
        XCTAssertEqual(snapshot(output, "Claude app")?.limits.count, 2, "the desktop app's own account owns its limits")
        XCTAssertEqual(snapshot(output, "Work")?.today.requests, 0)
    }

    func testNoDesktopSessionsMeansNoExtraProfile() {
        ClaudeFixtures.append([ClaudeFixtures.prompt(at: ago(30)), ClaudeFixtures.assistant(at: ago(20), stop: "end_turn")], to: log(work))
        XCTAssertEqual(ClaudeUsageEngine(home: home).poll(now: now).profiles.map(\.label), ["Work"])
    }
}
