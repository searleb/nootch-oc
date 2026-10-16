import XCTest
@testable import NotchNook

final class ClaudeProfileTests: XCTestCase {
    private var home: URL!

    override func setUp() { home = ClaudeFixtures.makeTemporaryDirectory() }
    override func tearDown() { try? FileManager.default.removeItem(at: home) }

    private func makeProjects(_ dir: String) {
        try! FileManager.default.createDirectory(at: home.appending(path: "\(dir)/projects"), withIntermediateDirectories: true)
    }

    func testLabelsComeFromFolderSuffixNeverOrgNames() {
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude"), "Work")
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude-personal"), "Personal")
        XCTAssertEqual(ClaudeProfileDiscovery.label(forDirectoryNamed: ".claude-side-project"), "Side-project")
    }

    func testDiscoversDefaultAndPersonalWithTheirOwnOrganizations() {
        makeProjects(".claude")
        makeProjects(".claude-personal")
        ClaudeFixtures.writeAccountJSON(org: "org-work", to: home.appending(path: ".claude.json"))
        ClaudeFixtures.writeAccountJSON(org: "org-personal", to: home.appending(path: ".claude-personal/.claude.json"))

        let profiles = ClaudeProfileDiscovery.discover(home: home)

        XCTAssertEqual(profiles.map(\.label), ["Work", "Personal"])
        XCTAssertEqual(profiles.map(\.organization), ["org-work", "org-personal"])
        XCTAssertEqual(profiles[0].roots.count, 1)
        XCTAssertEqual(Set(profiles.map(\.id)).count, 2)
    }

    func testDefaultProfileAlsoWatchesXDGConfigRoot() {
        makeProjects(".claude")
        try! FileManager.default.createDirectory(at: home.appending(path: ".config/claude/projects"), withIntermediateDirectories: true)
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home)[0].roots.count, 2)
    }

    func testFoldersWithoutProjectsAreIgnored() {
        makeProjects(".claude")
        try! FileManager.default.createDirectory(at: home.appending(path: ".claude-empty"), withIntermediateDirectories: true)
        try! Data("{}".utf8).write(to: home.appending(path: ".claude.json.backup"))
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home).map(\.label), ["Work"])
    }

    func testNoClaudeAtAllMeansNoProfiles() {
        XCTAssertEqual(ClaudeProfileDiscovery.discover(home: home), [])
    }

    func testMissingOrGarbageAccountFileMeansNoOrganization() {
        makeProjects(".claude")
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
        try! Data("not json".utf8).write(to: home.appending(path: ".claude.json"))
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
        try! Data(#"{"oauthAccount":{}}"#.utf8).write(to: home.appending(path: ".claude.json"))
        XCTAssertNil(ClaudeProfileDiscovery.discover(home: home)[0].organization)
    }
}
