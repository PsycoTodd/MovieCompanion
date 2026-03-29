import Foundation
import Speech
import AVFoundation

// MARK: - Public state types

enum SpeechSyncState: Equatable {
    case idle
    case listening(String)     // carries the live partial transcript
    case matched(TimeInterval)
    case failed(SpeechSyncError)
}

enum SpeechSyncError: Error, Equatable {
    case permissionDenied
    case speechUnavailable
    case noEnglishSubtitles
    case noMatchFound
    case audioEngineError
}

// MARK: - Service

actor SpeechSyncService {

    // MARK: Internal state

    private var index: [String: SubtitleLine]? = nil   // nil = not yet built
    private var engine: AVAudioEngine? = nil
    private var recognitionTask: SFSpeechRecognitionTask? = nil
    private var timeoutTask: Task<Void, Never>? = nil
    private var continuation: AsyncStream<SpeechSyncState>.Continuation? = nil
    private var lastStopTime: Date = .distantPast
    private let cooldown: TimeInterval = 2

    // MARK: Public interface

    /// Starts a sync session. Returns an AsyncStream that emits state updates
    /// until .matched or .failed is emitted, then finishes.
    func start(preloadedLines: [SubtitleLine]) -> AsyncStream<SpeechSyncState> {
        AsyncStream { continuation in
            self.continuation = continuation
            Task {
                await self.run(preloadedLines: preloadedLines)
            }
        }
    }

    func stop() {
        tearDown()
    }

    // MARK: - Core pipeline

    private func run(preloadedLines: [SubtitleLine]) async {
        // Cooldown guard
        if Date().timeIntervalSince(lastStopTime) < cooldown {
            try? await Task.sleep(nanoseconds: UInt64(cooldown * 1_000_000_000))
        }

        // 1. Check / request Speech permission
        let speechAuth = await requestSpeechAuthorization()
        guard speechAuth == .authorized else {
            emit(.failed(.permissionDenied))
            return
        }

        // 2. Check / request Microphone permission
        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            emit(.failed(.permissionDenied))
            return
        }

        // 3. Build index if needed
        if index == nil {
            guard !preloadedLines.isEmpty else {
                emit(.failed(.noEnglishSubtitles))
                return
            }
            index = buildIndex(from: preloadedLines)
        }

        // 4. Set up recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            emit(.failed(.speechUnavailable))
            return
        }

        // 5. Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            emit(.failed(.audioEngineError))
            return
        }

        // 6. Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // 7. Set up audio engine
        let newEngine = AVAudioEngine()
        engine = newEngine
        let inputNode = newEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            newEngine.prepare()
            try newEngine.start()
        } catch {
            emit(.failed(.audioEngineError))
            tearDown()
            return
        }

        emit(.listening(""))

        // 8. Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task {
                await self.handleResult(result: result, error: error)
            }
        }

        // 9. Start 30s timeout
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await self.emit(.failed(.noMatchFound))
            await self.tearDown()
        }
    }

    private func handleResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // If already finished (matched or timed out), ignore
        guard continuation != nil else { return }

        if let result {
            let transcript = result.bestTranscription.formattedString
            if let match = findMatch(in: transcript) {
                emit(.matched(match.timestamp))
                tearDown()
                return
            }
            // No match yet — emit the partial transcript so the UI can show it
            emit(.listening(transcript))
        }

        // On a final result with no match yet, let the timeout handle failure
        if let error = error {
            let nsError = error as NSError
            // Code 1110 = no speech detected; not fatal, let timeout handle it
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 { return }
            emit(.failed(.audioEngineError))
            tearDown()
        }
    }

    // MARK: - Cleanup

    private func tearDown() {
        timeoutTask?.cancel()
        timeoutTask = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        if let eng = engine {
            eng.inputNode.removeTap(onBus: 0)
            eng.stop()
            engine = nil
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        continuation?.finish()
        continuation = nil
        lastStopTime = Date()
    }

    private func emit(_ state: SpeechSyncState) {
        continuation?.yield(state)
        if case .matched = state { } else if case .failed = state { } else { return }
        // For terminal states (.matched / .failed) finish is handled by tearDown
    }

    // MARK: - N-gram index

    private func buildIndex(from lines: [SubtitleLine]) -> [String: SubtitleLine] {
        var map: [String: SubtitleLine] = [:]
        for line in lines {
            let words = normalizedWords(from: line.text)
            guard words.count >= 5 else { continue }
            for i in 0...(words.count - 5) {
                let key = words[i..<(i + 5)].joined(separator: " ")
                if map[key] == nil {        // first occurrence wins (earlier in film)
                    map[key] = line
                }
            }
        }
        return map
    }

    private func findMatch(in transcript: String) -> SubtitleLine? {
        let words = normalizedWords(from: transcript)
        guard words.count >= 6 else { return nil }  // >5 words gate
        for i in 0...(words.count - 5) {
            let key = words[i..<(i + 5)].joined(separator: " ")
            if let match = index?[key] {
                return match
            }
        }
        return nil
    }

    private func normalizedWords(from text: String) -> [String] {
        // 1. Strip HTML tags
        var s = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // 2. Flatten newlines
        s = s.replacingOccurrences(of: "\n", with: " ")
        // 3. Lowercase
        s = s.lowercased()
        // 4. Keep only a-z, 0-9, spaces
        s = s.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
             .map { String($0) }.joined()
        // 5. Split and filter empties
        return s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    // MARK: - Permission helpers

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
