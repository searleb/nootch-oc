import XCTest
@testable import NotchNook

final class ClaudeLogTailerTests: XCTestCase {
    private var dir: URL!
    private var file: URL { dir.appending(path: "log.jsonl") }

    override func setUp() { dir = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func text(_ lines: [Data]) -> [String] { lines.map { String(decoding: $0, as: UTF8.self) } }

    func testReadsCompleteLinesOnceAndOnlyNewOnesAfter() {
        var cursor = ClaudeLogCursor()
        ClaudeFixtures.append([Data("one".utf8), Data("two".utf8)], to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["one", "two"])
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        ClaudeFixtures.append([Data("three".utf8)], to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["three"])
    }

    func testLineWrittenInPiecesIsHeldUntilItsNewline() {
        var cursor = ClaudeLogCursor()
        let handle: FileHandle = {
            FileManager.default.createFile(atPath: file.path, contents: nil)
            return try! FileHandle(forWritingTo: file)
        }()
        defer { try? handle.close() }
        try! handle.write(contentsOf: Data("{\"type\":\"assis".utf8))
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        try! handle.write(contentsOf: Data("tant\"}\n".utf8))
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["{\"type\":\"assistant\"}"])
    }

    func testTruncatedFileResetsCursorAndRereads() {
        var cursor = ClaudeLogCursor()
        ClaudeFixtures.append([Data("a-long-first-line".utf8), Data("second".utf8)], to: file)
        _ = ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)
        cursor.state.turnOpen = true
        try! Data("new\n".utf8).write(to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["new"])
        XCTAssertFalse(cursor.state.turnOpen, "a rotated file must not inherit the old turn")
    }

    func testBlankLinesAreSkippedAndMissingFileIsEmpty() {
        var cursor = ClaudeLogCursor()
        XCTAssertEqual(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor), [])
        try! Data("a\n\n\nb\n".utf8).write(to: file)
        XCTAssertEqual(text(ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)), ["a", "b"])
    }

    func testLineLargerThanOneChunkIsReadIntact() {
        var cursor = ClaudeLogCursor()
        let big = String(repeating: "x", count: ClaudeLogTailer.chunkSize + 123_456)
        ClaudeFixtures.append([Data(big.utf8), Data("tail".utf8)], to: file)
        let lines = ClaudeLogTailer.readNewLines(at: file, cursor: &cursor)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, big.utf8.count)
        XCTAssertEqual(String(decoding: lines[1], as: UTF8.self), "tail")
    }
}
