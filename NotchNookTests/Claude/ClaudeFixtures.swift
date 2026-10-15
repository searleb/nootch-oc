import Foundation
@testable import NotchNook

/// Builds log lines in the shape Claude Code writes them (compact JSON).
enum ClaudeFixtures {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func stamp(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ text: String) -> Date { formatter.date(from: text)! }

    private static func encode(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }

    static func prompt(at date: Date, session: String = "s1", cwd: String = "/Users/x/Sites/anywhere",
                       text: String = "do the thing", sidechain: Bool = false, meta: Bool = false) -> Data {
        var object: [String: Any] = ["type": "user", "timestamp": stamp(date), "sessionId": session, "cwd": cwd,
                                     "isSidechain": sidechain, "message": ["role": "user", "content": text]]
        if meta { object["isMeta"] = true }
        return encode(object)
    }

    static func userBlocks(at date: Date, blocks: [[String: Any]], session: String = "s1",
                           sidechain: Bool = false) -> Data {
        encode(["type": "user", "timestamp": stamp(date), "sessionId": session, "cwd": "/Users/x/Sites/anywhere",
                "isSidechain": sidechain, "message": ["role": "user", "content": blocks]])
    }

    static func toolResult(at date: Date, toolUseID: String, session: String = "s1", payload: String = "ok") -> Data {
        userBlocks(at: date, blocks: [["type": "tool_result", "tool_use_id": toolUseID, "content": payload]], session: session)
    }

    static func interrupt(at date: Date, session: String = "s1") -> Data {
        userBlocks(at: date, blocks: [["type": "text", "text": "[Request interrupted by user]"]], session: session)
    }

    static func assistant(at date: Date, stop: String?, session: String = "s1", messageID: String = "m1",
                          requestID: String = "r1", model: String = "claude-opus-5-5", input: Int = 10,
                          output: Int = 20, cacheRead: Int = 0, cacheWrite: Int = 0, bashIDs: [String] = [],
                          sidechain: Bool = false, cwd: String = "/Users/x/Sites/anywhere") -> Data {
        let content: [[String: Any]] = bashIDs.isEmpty
            ? [["type": "text", "text": "hi"]]
            : bashIDs.map { ["type": "tool_use", "id": $0, "name": "Bash", "input": ["command": "ls"]] }
        let usage: [String: Any] = ["input_tokens": input, "output_tokens": output,
                                    "cache_read_input_tokens": cacheRead, "cache_creation_input_tokens": cacheWrite]
        let message: [String: Any] = ["id": messageID, "role": "assistant", "model": model, "content": content,
                                      "stop_reason": stop as Any? ?? NSNull(), "usage": usage]
        return encode(["type": "assistant", "timestamp": stamp(date), "sessionId": session, "cwd": cwd,
                       "isSidechain": sidechain, "requestId": requestID, "message": message])
    }
}
