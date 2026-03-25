import Foundation
import UIKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentLine: SubtitleLine? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    var onFinished: (() -> Void)? = nil

    private var lines: [SubtitleLine] = []
    private var timer: Timer? = nil
    private let tickInterval: TimeInterval = 0.1
    private let gracePeriod: TimeInterval = 1.5

    func load(fileName: String) {
        stop()
        lines = SRTParser.parse(fileName: fileName)
        totalDuration = lines.last?.endTimestamp ?? lines.last?.timestamp ?? 0
        elapsedTime = 0
        currentLine = nil
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        UIApplication.shared.isIdleTimerDisabled = true

        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func seek(to time: TimeInterval) {
        elapsedTime = max(0, min(time, totalDuration))
        updateCurrentLine()
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
        currentLine = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        elapsedTime += tickInterval
        updateCurrentLine()

        if totalDuration > 0 && elapsedTime > totalDuration + gracePeriod {
            timer?.invalidate()
            timer = nil
            isPlaying = false
            UIApplication.shared.isIdleTimerDisabled = false
            onFinished?()
        }
    }

    private func updateCurrentLine() {
        currentLine = lines.last { $0.timestamp <= elapsedTime }
    }
}
