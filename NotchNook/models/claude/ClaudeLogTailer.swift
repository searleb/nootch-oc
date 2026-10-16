import Foundation

/// Where reading a log stopped, and what the parser knew there.
struct ClaudeLogCursor {
    var offset: UInt64 = 0
    /// The unfinished last line, held until its newline is written.
    var partial = Data()
    var state = ClaudeLogState()
}

enum ClaudeLogTailer {
    static let chunkSize = 4 << 20

    /// The complete lines written since the cursor, in order. A file smaller
    /// than the cursor was rotated or truncated: the cursor starts over.
    static func readNewLines(at url: URL, cursor: inout ClaudeLogCursor) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [] }
        if size < cursor.offset { cursor = ClaudeLogCursor() }
        guard size > cursor.offset else { return [] }
        do { try handle.seek(toOffset: cursor.offset) } catch { return [] }

        var lines: [Data] = []
        var buffer = cursor.partial
        var position = cursor.offset
        while position < size {
            let wanted = Int(min(UInt64(chunkSize), size - position))
            guard let chunk = try? handle.read(upToCount: wanted), !chunk.isEmpty else { break }
            position += UInt64(chunk.count)
            buffer.append(chunk)
            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                if newline > lineStart { lines.append(Data(buffer[lineStart..<newline])) }
                lineStart = buffer.index(after: newline)
            }
            buffer = Data(buffer[lineStart...])
        }
        cursor.offset = position
        cursor.partial = buffer
        return lines
    }
}
