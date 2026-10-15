import Foundation

/// One Claude config directory: where its session logs live and which
/// account it is signed in to.
struct ClaudeProfile: Equatable, Identifiable {
    /// The config directory path.
    let id: String
    let label: String
    /// Existing `projects` folders to watch.
    let roots: [URL]
    /// The account's organization, when its profile file says.
    let organization: String?
}

enum ClaudeProfileDiscovery {
    private static let maximumProfileFileSize = 16 << 20

    /// `.claude` is the work profile on this setup; `.claude-foo` is "Foo".
    /// Never the org name: a personal account's can be a private-relay address.
    static func label(forDirectoryNamed name: String) -> String {
        guard name.hasPrefix(".claude-") else { return "Work" }
        let suffix = String(name.dropFirst(".claude-".count))
        guard let first = suffix.first else { return "Claude" }
        return first.uppercased() + suffix.dropFirst()
    }

    /// The default profile first, then every `~/.claude-*` folder that has
    /// session logs (the usual home of a `CLAUDE_CONFIG_DIR` alias).
    static func discover(home: URL, fileManager: FileManager = .default) -> [ClaudeProfile] {
        var profiles: [ClaudeProfile] = []

        let defaultRoots = [".claude/projects", ".config/claude/projects"]
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { isDirectory($0, fileManager) }
            .map { $0.resolvingSymlinksInPath() }
        if !defaultRoots.isEmpty {
            profiles.append(ClaudeProfile(id: home.appending(path: ".claude").path,
                                          label: label(forDirectoryNamed: ".claude"), roots: defaultRoots,
                                          organization: organization(inJSONAt: home.appending(path: ".claude.json"))))
        }

        let names = (try? fileManager.contentsOfDirectory(atPath: home.path)) ?? []
        for name in names.sorted() where name.hasPrefix(".claude-") {
            let directory = home.appending(path: name, directoryHint: .isDirectory)
            let projects = directory.appending(path: "projects", directoryHint: .isDirectory)
            guard isDirectory(projects, fileManager) else { continue }
            profiles.append(ClaudeProfile(id: directory.path, label: label(forDirectoryNamed: name),
                                          roots: [projects.resolvingSymlinksInPath()],
                                          organization: organization(inJSONAt: directory.appending(path: ".claude.json"))))
        }
        return profiles
    }

    /// `oauthAccount.organizationUuid`, and nothing else from the file.
    static func organization(inJSONAt url: URL) -> String? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= maximumProfileFileSize,
              let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let account = json["oauthAccount"] as? [String: Any],
              let organization = account["organizationUuid"] as? String, !organization.isEmpty else { return nil }
        return organization
    }

    private static func isDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
        var directory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }
}
