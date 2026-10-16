import Darwin
import Foundation

/// What one log line says, reduced to what the widget needs. Only usage
/// counters, model names, times and folder names leave a line; prompts,
/// replies and tool output are never kept.
enum ClaudeLogEvent: Equatable {
    case turnBegan(Date)
    /// Work continues; nil when the line was not worth decoding for its time.
    case turnActive(Date?)
    case turnEnded(Date, completed: Bool)
    case usage(ClaudeUsageRecord)
    /// A subagent is working: any of its lines other than its final reply. Never a parent turn.
    case sidechainActive(Date?)
    /// A subagent gave its final reply.
    case sidechainEnded(Date)
}

/// Per-file context carried from line to line.
struct ClaudeLogState: Equatable {
    var session = ""
    var project = ""
    /// The app that wrote the session: `cli`, `claude-desktop`, `claude-vscode`.
    var entrypoint = ""
    var turnOpen = false
    /// Bash tool calls still waiting for a result. They run on the Mac, so a
    /// quiet log while one runs does not mean Claude stopped.
    var runningCommands: Set<String> = []
}

enum ClaudeLogParser {
    private static let interruptPrefix = "[Request interrupted by user"
    private static let localOutputPrefix = "<local-command-std"

    static func parse(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        if contains(line, #""type":"assistant""#) { return assistant(line, state: &state, now: now) }
        guard contains(line, #""type":"user""#) else { return [] }
        // A subagent's prompts and tool output never touch the parent turn, and its
        // tool output can be large: report that it is working without decoding the line.
        if contains(line, #""isSidechain":true"#) {
            if state.entrypoint.isEmpty, let entrypoint = quickString(line, key: "entrypoint") { state.entrypoint = entrypoint }
            return [.sidechainActive(quickTimestamp(line))]
        }
        if state.turnOpen { return userInsideTurn(line, state: &state, now: now) }
        guard let json = object(line), json["type"] as? String == "user",
              json["isMeta"] as? Bool != true, isPrompt(json) else { return [] }
        adopt(json, into: &state)
        state.turnOpen = true
        state.runningCommands = []
        return [.turnBegan(timestamp(json["timestamp"]) ?? now)]
    }

    // MARK: Lines

    /// Tool results arrive inside a turn and can be many megabytes. They are
    /// decoded only when they could change something: an interruption, a local
    /// command's output, or the result of a Bash call being waited on.
    private static func userInsideTurn(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        let mayEnd = contains(line, interruptPrefix) || contains(line, localOutputPrefix)
        guard mayEnd || !state.runningCommands.isEmpty,
              let json = object(line), json["type"] as? String == "user" else {
            return [.turnActive(quickTimestamp(line))]
        }
        let date = timestamp(json["timestamp"]) ?? now
        // Only the person's own text counts; a tool result can quote the same words.
        if userTexts(json).contains(where: { $0.hasPrefix(interruptPrefix) || $0.hasPrefix(localOutputPrefix) }) {
            state.turnOpen = false
            state.runningCommands = []
            return [.turnEnded(date, completed: false)]
        }
        for id in toolResultIDs(json) { state.runningCommands.remove(id) }
        return [.turnActive(date)]
    }

    private static func assistant(_ line: Data, state: inout ClaudeLogState, now: Date) -> [ClaudeLogEvent] {
        guard let json = object(line), json["type"] as? String == "assistant",
              let message = json["message"] as? [String: Any] else { return [] }
        adopt(json, into: &state)
        let date = timestamp(json["timestamp"]) ?? now
        let model = message["model"] as? String ?? ""
        var events: [ClaudeLogEvent] = []
        if let usage = message["usage"] as? [String: Any], !model.isEmpty, !model.hasPrefix("<") {
            events.append(.usage(record(usage, json: json, message: message, model: model, date: date, state: state)))
        }
        // A subagent ending is not the end of the turn it serves.
        if json["isSidechain"] as? Bool == true {
            switch message["stop_reason"] as? String {
            case "end_turn", "stop_sequence", "max_tokens", "refusal": events.append(.sidechainEnded(date))
            default: events.append(.sidechainActive(date))
            }
            return events
        }
        switch message["stop_reason"] as? String {
        case "end_turn", "stop_sequence", "max_tokens", "refusal":
            // An error written in place of a reply, like a spent limit, stops
            // the turn without finishing it.
            let failed = json["isApiErrorMessage"] as? Bool == true || model.hasPrefix("<")
            if state.turnOpen { events.append(.turnEnded(date, completed: !failed)) }
            state.turnOpen = false
            state.runningCommands = []
        default:
            for block in message["content"] as? [[String: Any]] ?? []
            where block["type"] as? String == "tool_use" && block["name"] as? String == "Bash" {
                if let id = block["id"] as? String { state.runningCommands.insert(id) }
            }
            // Ahead of the usage so a reply that reopens the turn counts toward it.
            events.insert(state.turnOpen ? .turnActive(date) : .turnBegan(date), at: 0)
            state.turnOpen = true
        }
        return events
    }

    private static func record(_ usage: [String: Any], json: [String: Any], message: [String: Any],
                               model: String, date: Date, state: ClaudeLogState) -> ClaudeUsageRecord {
        let tokens = ClaudeTokens(input: int(usage["input_tokens"]),
                                  cacheWrite: int(usage["cache_creation_input_tokens"]),
                                  cacheRead: int(usage["cache_read_input_tokens"]),
                                  output: int(usage["output_tokens"]))
        let long = int((usage["cache_creation"] as? [String: Any])?["ephemeral_1h_input_tokens"])
        let id = message["id"] as? String ?? ""
        let request = json["requestId"] as? String ?? ""
        let key = id.isEmpty && request.isEmpty
            ? "claude:\(state.session):\(date.timeIntervalSince1970)" : "claude:\(id):\(request)"
        return ClaudeUsageRecord(key: key, date: date, model: model, project: state.project, tokens: tokens,
                                 longCacheWrite: min(long, tokens.cacheWrite))
    }

    // MARK: Prompt and content helpers

    /// A person's own prompt: text or an image, not a bare tool result, not
    /// command output, not an interruption marker.
    private static func isPrompt(_ json: [String: Any]) -> Bool {
        let content = (json["message"] as? [String: Any])?["content"]
        if let text = content as? String {
            return !text.isEmpty && !text.hasPrefix(interruptPrefix) && !text.hasPrefix(localOutputPrefix)
        }
        guard let blocks = content as? [[String: Any]] else { return false }
        let texts = userTexts(json)
        if texts.contains(where: { $0.hasPrefix(interruptPrefix) || $0.hasPrefix(localOutputPrefix) }) { return false }
        return blocks.contains { ["text", "image"].contains($0["type"] as? String ?? "") }
    }

    private static func userTexts(_ json: [String: Any]) -> [String] {
        let content = (json["message"] as? [String: Any])?["content"]
        if let text = content as? String { return [text] }
        guard let blocks = content as? [[String: Any]] else { return [] }
        return blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
    }

    private static func toolResultIDs(_ json: [String: Any]) -> [String] {
        let blocks = (json["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
        return blocks.compactMap { $0["type"] as? String == "tool_result" ? $0["tool_use_id"] as? String : nil }
    }

    private static func adopt(_ json: [String: Any], into state: inout ClaudeLogState) {
        if let session = json["sessionId"] as? String, !session.isEmpty { state.session = session }
        if let cwd = json["cwd"] as? String, !cwd.isEmpty { state.project = projectName(cwd) }
        if let entrypoint = json["entrypoint"] as? String, !entrypoint.isEmpty { state.entrypoint = entrypoint }
    }

    static func projectName(_ cwd: String) -> String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    // MARK: Decoding helpers

    /// Structural keys are written without spaces and never appear unescaped
    /// inside a string value, so a byte match is a safe first filter.
    private static func contains(_ line: Data, _ needle: String) -> Bool {
        let bytes = Array(needle.utf8)
        return line.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, raw.count >= bytes.count else { return false }
            return memmem(base, raw.count, bytes, bytes.count) != nil
        }
    }

    private static func object(_ line: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
    }

    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func timestamp(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return fractional.date(from: text) ?? plain.date(from: text)
    }

    /// A short string value for `key` without decoding the line, for lines too big to parse.
    static func quickString(_ line: Data, key: String) -> String? {
        let needle = Array("\"\(key)\":\"".utf8)
        return line.withUnsafeBytes { bytes -> String? in
            guard let base = bytes.baseAddress,
                  let found = memmem(base, bytes.count, needle, needle.count) else { return nil }
            let start = base.distance(to: UnsafeRawPointer(found)) + needle.count
            let limit = min(bytes.count, start + 48)
            guard start < limit, let quote = memchr(base + start, 0x22, limit - start) else { return nil }
            let end = base.distance(to: UnsafeRawPointer(quote))
            return end > start ? String(decoding: UnsafeRawBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self) : nil
        }
    }

    /// The line's own time without decoding it, for lines too big to parse.
    static func quickTimestamp(_ line: Data) -> Date? {
        let key: StaticString = #""timestamp":""#
        return line.withUnsafeBytes { bytes -> Date? in
            guard let base = bytes.baseAddress,
                  let found = memmem(base, bytes.count, key.utf8Start, key.utf8CodeUnitCount) else { return nil }
            let start = base.distance(to: UnsafeRawPointer(found)) + key.utf8CodeUnitCount
            guard start + 24 <= bytes.count else { return nil }
            let text = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[start..<(start + 24)]), as: UTF8.self)
            return timestamp(text)
        }
    }
}
