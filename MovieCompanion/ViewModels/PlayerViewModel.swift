import Foundation
import UIKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentLine: SubtitleLine? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var speechSyncState: SpeechSyncState = .idle
    @Published var showSyncFailureAlert: Bool = false

    var totalDuration: TimeInterval = 0
    var onFinished: (() -> Void)? = nil

    private var lines: [SubtitleLine] = []
    private var timer: Timer? = nil
    private let tickInterval: TimeInterval = 0.1
    private let gracePeriod: TimeInterval = 1.5

    // Seconds added to the matched timestamp to compensate for speech recognition latency.
    // Increase if subtitles appear behind the dialogue; decrease if they run ahead.
    var syncOffset: TimeInterval = 1.5

    private var loadedFileName: String = ""
    private var speechSyncService: SpeechSyncService? = nil
    private var speechSyncTask: Task<Void, Never>? = nil

    // MARK: - Playback

    func load(fileName: String) {
        stop()
        loadedFileName = fileName
        lines = SRTParser.parse(fileName: fileName)
        totalDuration = lines.last?.endTimestamp ?? lines.last?.timestamp ?? 0
        elapsedTime = 0
        currentLine = nil
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        UIApplication.shared.isIdleTimerDisabled = true

        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
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
        cancelSpeechSync()
    }

    private func tick() {
        guard isPlaying else { return }
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

    // MARK: - Speech sync

    func toggleSync() {
        if case .listening = speechSyncState {
            cancelSpeechSync()
            speechSyncState = .idle
            return
        }


        // Derive English file name: strip last _XX component, append _EN
        let englishFileName = englishFileNameFrom(loadedFileName)

        if speechSyncService == nil {
            speechSyncService = SpeechSyncService()
        }
        guard let service = speechSyncService else { return }

        speechSyncTask?.cancel()
        speechSyncTask = Task {
            let stream = await service.start(englishFileName: englishFileName)
            for await state in stream {
                self.speechSyncState = state
                switch state {
                case .matched(let timestamp):
                    self.seek(to: timestamp + self.syncOffset)
                    self.play()
                case .failed:
                    self.showSyncFailureAlert = true
                default:
                    break
                }
            }
            // Stream finished — only reset if still listening.
            // .matched and .failed transitions are owned by the view.
            if case .listening = self.speechSyncState {
                self.speechSyncState = .idle
            }
        }
    }

    private func cancelSpeechSync() {
        speechSyncTask?.cancel()
        speechSyncTask = nil
        Task { await speechSyncService?.stop() }
    }

    /// Strips the last `_XX` language code and appends `_EN`.
    /// e.g. "Inception_ZH" → "Inception_EN", "Inception_EN" → "Inception_EN"
    private func englishFileNameFrom(_ fileName: String) -> String {
        guard let range = fileName.range(of: "_", options: .backwards) else {
            return fileName + "_EN"
        }
        return String(fileName[fileName.startIndex..<range.lowerBound]) + "_EN"
    }
}
