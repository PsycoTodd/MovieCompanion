import Foundation
import UIKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentLine: SubtitleLine? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var speechSyncState: SpeechSyncState = .idle
    @Published var showSyncFailureAlert: Bool = false
    @Published var isLoadingSubtitles: Bool = false
    @Published var subtitleLoadError: String? = nil

    var totalDuration: TimeInterval = 0
    var onFinished: (() -> Void)? = nil

    private var lines: [SubtitleLine] = []
    private var englishLines: [SubtitleLine] = []
    private var timer: Timer? = nil
    private let tickInterval: TimeInterval = 0.1
    private let gracePeriod: TimeInterval = 1.5

    private var speechSyncService: SpeechSyncService? = nil
    private var speechSyncTask: Task<Void, Never>? = nil

    // MARK: - Playback

    func load(language: Language) {
        stop()
        subtitleLoadError = nil
        isLoadingSubtitles = true

        Task {
            do {
                async let subtitlesFetch = RemoteSubtitleLoader.loadSRT(from: language.remoteURL!)
                async let englishFetch: [SubtitleLine] = {
                    if let enURL = language.englishRemoteURL {
                        return (try? await RemoteSubtitleLoader.loadSRT(from: enURL)) ?? []
                    }
                    return []
                }()
                let (loaded, english) = try await (subtitlesFetch, englishFetch)
                self.lines = loaded
                self.englishLines = english
                self.totalDuration = loaded.last?.endTimestamp ?? loaded.last?.timestamp ?? 0
                self.elapsedTime = 0
                self.currentLine = nil
            } catch {
                self.subtitleLoadError = error.localizedDescription
            }
            self.isLoadingSubtitles = false
        }
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
        englishLines = []
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

    var isSpeechSyncAvailable: Bool { !englishLines.isEmpty }

    func toggleSync() {
        if case .listening = speechSyncState {
            cancelSpeechSync()
            speechSyncState = .idle
            return
        }

        if speechSyncService == nil {
            speechSyncService = SpeechSyncService()
        }
        guard let service = speechSyncService else { return }

        speechSyncTask?.cancel()
        speechSyncTask = Task {
            let stream = await service.start(preloadedLines: englishLines)
            for await state in stream {
                self.speechSyncState = state
                switch state {
                case .matched(let timestamp, let offset):
                    self.seek(to: timestamp + offset)
                    self.play()
                case .failed:
                    self.showSyncFailureAlert = true
                default:
                    break
                }
            }
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
}
