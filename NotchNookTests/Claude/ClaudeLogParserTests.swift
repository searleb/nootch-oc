import XCTest
@testable import NotchNook

final class ClaudeLogParserTests: XCTestCase {
    private let t0 = ClaudeFixtures.date("2026-10-14T10:00:00.000Z")
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func run(_ lines: [Data], state: inout ClaudeLogState) -> [ClaudeLogEvent] {
        lines.flatMap { ClaudeLogParser.parse($0, state: &state, now: at(999)) }
    }

    func testPromptOpensTurnAndAdoptsSessionAndProject() {
        var state = ClaudeLogState()
        let events = run([ClaudeFixtures.prompt(at: t0, session: "abc", cwd: "/Users/x/Sites/anywhere")], state: &state)
        XCTAssertEqual(events, [.turnBegan(t0)])
        XCTAssertTrue(state.turnOpen)
        XCTAssertEqual(state.session, "abc")
        XCTAssertEqual(state.project, "anywhere")
    }

    func testToolUseKeepsTurnOpenAndEndTurnClosesIt() {
        var state = ClaudeLogState()
        var events = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        events += run([ClaudeFixtures.assistant(at: at(2), stop: "tool_use", messageID: "m1")], state: &state)
        XCTAssertTrue(state.turnOpen)
        events += run([ClaudeFixtures.assistant(at: at(9), stop: "end_turn", messageID: "m2", requestID: "r2")], state: &state)
        XCTAssertFalse(state.turnOpen)
        XCTAssertTrue(events.contains(.turnActive(at(2))))
        XCTAssertTrue(events.contains(.turnEnded(at(9), completed: true)))
    }

    func testAssistantLineReportsUsageWithStableKey() {
        var state = ClaudeLogState()
        let line = ClaudeFixtures.assistant(at: t0, stop: "end_turn", messageID: "m9", requestID: "r9",
                                            input: 3, output: 7, cacheRead: 100, cacheWrite: 5)
        let events = run([line, line], state: &state)
        let usages = events.compactMap { event -> ClaudeUsageRecord? in
            if case .usage(let record) = event { return record }
            return nil
        }
        XCTAssertEqual(usages.count, 2)
        XCTAssertEqual(usages[0].key, usages[1].key)
        XCTAssertEqual(usages[0].key, "claude:m9:r9")
        XCTAssertEqual(usages[0].tokens, ClaudeTokens(input: 3, cacheWrite: 5, cacheRead: 100, output: 7))
        XCTAssertEqual(usages[0].model, "claude-opus-5-5")
    }

    func testInterruptClosesTurnAsIncomplete() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        let events = run([ClaudeFixtures.interrupt(at: at(5))], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(5), completed: false)])
        XCTAssertFalse(state.turnOpen)
    }

    func testInterruptTextQuotedInsideToolResultDoesNotEndTurn() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use", bashIDs: ["b1"])], state: &state)
        let quoted = ClaudeFixtures.toolResult(at: at(3), toolUseID: "b1", payload: "grep found [Request interrupted by user]")
        let events = run([quoted], state: &state)
        XCTAssertTrue(state.turnOpen)
        XCTAssertEqual(events, [.turnActive(at(3))])
    }

    func testToolResultAloneDoesNotOpenTurn() {
        var state = ClaudeLogState()
        let events = run([ClaudeFixtures.toolResult(at: t0, toolUseID: "x")], state: &state)
        XCTAssertEqual(events, [])
        XCTAssertFalse(state.turnOpen)
    }

    func testMetaPromptDoesNotOpenTurn() {
        var state = ClaudeLogState()
        XCTAssertEqual(run([ClaudeFixtures.prompt(at: t0, meta: true)], state: &state), [])
    }

    func testSidechainNeverOpensOrClosesButStillCountsUsage() {
        var state = ClaudeLogState()
        var events = run([ClaudeFixtures.prompt(at: t0, sidechain: true)], state: &state)
        XCTAssertEqual(events, [.sidechainActive(t0)], "a subagent line is subagent activity, never a parent turn")
        events = run([ClaudeFixtures.assistant(at: at(1), stop: "end_turn", sidechain: true)], state: &state)
        XCTAssertEqual(events.count, 2)
        guard case .usage = events[0] else { return XCTFail("expected usage first") }
        XCTAssertEqual(events[1], .sidechainEnded(at(1)))
        XCTAssertFalse(state.turnOpen)
        // A sidechain end must not close a real open turn either.
        _ = run([ClaudeFixtures.prompt(at: at(2))], state: &state)
        _ = run([ClaudeFixtures.assistant(at: at(3), stop: "end_turn", messageID: "side", sidechain: true)], state: &state)
        XCTAssertTrue(state.turnOpen)
    }

    func testRunningBashIsTrackedUntilItsResult() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use", bashIDs: ["b1", "b2"])], state: &state)
        XCTAssertEqual(state.runningCommands, ["b1", "b2"])
        _ = run([ClaudeFixtures.toolResult(at: at(5), toolUseID: "b1")], state: &state)
        XCTAssertEqual(state.runningCommands, ["b2"])
    }

    func testLocalCommandOutputClosesTurnItOpened() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0, text: "<command-name>/cost</command-name>")], state: &state)
        let out = ClaudeFixtures.userBlocks(at: at(1), blocks: [["type": "text", "text": "<local-command-stdout>$1</local-command-stdout>"]])
        let events = run([out], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(1), completed: false)])
        XCTAssertFalse(state.turnOpen)
    }

    func testSyntheticErrorEndsTurnIncompleteWithoutUsage() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0)], state: &state)
        let events = run([ClaudeFixtures.assistant(at: at(2), stop: "stop_sequence", model: "<synthetic>")], state: &state)
        XCTAssertEqual(events, [.turnEnded(at(2), completed: false)])
    }

    func testHugeToolResultWhileTurnOpenIsNotDecoded() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0),
                 ClaudeFixtures.assistant(at: at(1), stop: "tool_use")], state: &state)
        let huge = ClaudeFixtures.toolResult(at: at(4), toolUseID: "z", payload: String(repeating: "x", count: 3_000_000))
        let started = Date()
        let events = run([huge], state: &state)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertEqual(events, [.turnActive(at(4))])
    }

    func testUnrelatedAndMalformedLinesAreIgnored() {
        var state = ClaudeLogState()
        XCTAssertEqual(run([Data(#"{"type":"system","x":1}"#.utf8), Data("not json".utf8),
                            Data(#"{"type":"assistant", broken"#.utf8)], state: &state), [])
    }

    func testEntrypointIsAdoptedFromThePromptAndFromAssistantLines() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0, entrypoint: "claude-desktop")], state: &state)
        XCTAssertEqual(state.entrypoint, "claude-desktop")
        var other = ClaudeLogState()
        _ = run([ClaudeFixtures.assistant(at: t0, stop: "end_turn", entrypoint: "claude-vscode")], state: &other)
        XCTAssertEqual(other.entrypoint, "claude-vscode")
    }

    func testSubagentLinesStillCarryTheEntrypointForTheirUsage() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.assistant(at: t0, stop: "end_turn", sidechain: true, entrypoint: "claude-desktop")], state: &state)
        XCTAssertEqual(state.entrypoint, "claude-desktop")
    }


    func testSubagentLinesReportItsActivityAndEndWithoutTouchingTheParentTurn() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0), ClaudeFixtures.assistant(at: at(1), stop: "tool_use", bashIDs: ["b1"])], state: &state)
        XCTAssertEqual(run([ClaudeFixtures.prompt(at: at(2), sidechain: true)], state: &state), [.sidechainActive(at(2))])
        let working = run([ClaudeFixtures.assistant(at: at(3), stop: "tool_use", messageID: "s1", sidechain: true)], state: &state)
        XCTAssertEqual(working.last, .sidechainActive(at(3)))
        let done = run([ClaudeFixtures.assistant(at: at(4), stop: "end_turn", messageID: "s2", sidechain: true)], state: &state)
        XCTAssertEqual(done.last, .sidechainEnded(at(4)))
        XCTAssertTrue(state.turnOpen, "the parent turn is still open")
        XCTAssertEqual(state.runningCommands, ["b1"], "and its running command is untouched")
    }

    func testSubagentPromptAdoptsTheEntrypointWithoutDecodingTheLine() {
        var state = ClaudeLogState()
        _ = run([ClaudeFixtures.prompt(at: t0, sidechain: true, entrypoint: "claude-desktop")], state: &state)
        XCTAssertEqual(state.entrypoint, "claude-desktop")
    }
}
