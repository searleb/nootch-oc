import Foundation

/// A turn worth telling the person about.
struct ClaudeFinishedAlert: Equatable {
    let profileLabel: String
    let project: String
    let duration: TimeInterval

    var accessibilityText: String {
        "\(profileLabel) finished in \(project) after \(ClaudeFormat.duration(duration))"
    }

    /// Only completed turns at least `minimumSeconds` long, and only when notifying.
    static func alerts(from finished: [ClaudeFinishedTurn], profiles: [ClaudeProfileSnapshot],
                       notify: Bool, minimumSeconds: TimeInterval) -> [ClaudeFinishedAlert] {
        guard notify else { return [] }
        return finished
            .filter { $0.completed && $0.duration >= minimumSeconds }
            .map { turn in
                ClaudeFinishedAlert(profileLabel: profiles.first { $0.id == turn.profileID }?.label ?? "Claude",
                                    project: turn.project, duration: turn.duration)
            }
    }
}
