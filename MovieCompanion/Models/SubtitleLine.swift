import Foundation

struct SubtitleLine: Identifiable {
    let id: UUID
    let timestamp: TimeInterval    // start time in seconds
    let endTimestamp: TimeInterval // end time in seconds
    let text: String
}
