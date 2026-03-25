import Foundation

struct SRTParser {
    static func parse(fileName: String) -> [SubtitleLine] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "srt"),
              let rawContent = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        // Normalize line endings and strip BOM
        let content = rawContent
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))

        var lines: [SubtitleLine] = []

        for block in content.components(separatedBy: "\n\n") {
            let blockLines = block
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }

            guard blockLines.count >= 2 else { continue }

            // Find the timestamp line (contains " --> ")
            guard let tsIndex = blockLines.firstIndex(where: { $0.contains(" --> ") }),
                  let (startTime, endTime) = parseTimestampLine(blockLines[tsIndex]) else { continue }

            let text = blockLines[(tsIndex + 1)...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            lines.append(SubtitleLine(
                id: UUID(),
                timestamp: startTime,
                endTimestamp: endTime,
                text: text
            ))
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseTimestampLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2,
              let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (start, end)
    }

    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        // Format: HH:MM:SS,mmm
        let normalized = str.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}
