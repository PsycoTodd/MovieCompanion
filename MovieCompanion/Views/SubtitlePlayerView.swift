import SwiftUI

struct SubtitlePlayerView: View {
    let fileName: String
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerViewModel = PlayerViewModel()
    private let defaultFontSize: Double = 28
    @State private var fontSize: Double = 28
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var seekSliderValue: Double = 0
    @State private var isDraggingSeek: Bool = false

    private let accent = Color(red: 0.9, green: 0.79, blue: 0.48)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Subtitle region — fills all space above controls.
                // Color.clear + contentShape makes the whole area pinch-zoomable.
                Color.clear
                    .overlay(
                        Group {
                            if case .listening(let transcript) = playerViewModel.speechSyncState {
                                Text(transcript.isEmpty ? "Listening…" : transcript)
                                    .foregroundColor(.yellow)
                            } else {
                                Text(playerViewModel.currentLine?.text ?? "")
                                    .foregroundColor(.white)
                            }
                        }
                        .font(.system(size: fontSize * pinchScale, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .updating($pinchScale) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                fontSize = min(max(fontSize * value, defaultFontSize), 60)
                            }
                    )

                controlsView
                    .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
            }
            .padding(.leading, 8)
            .padding(.top, 4)
        }
        .onAppear {
            playerViewModel.onFinished = onFinished
            playerViewModel.load(fileName: fileName)
        }
        .onDisappear {
            playerViewModel.stop()
        }
        .onChange(of: playerViewModel.elapsedTime) { newValue in
            if !isDraggingSeek {
                seekSliderValue = newValue
            }
        }
        .onChange(of: playerViewModel.totalDuration) { newValue in
            seekSliderValue = 0
        }
        .onChange(of: playerViewModel.speechSyncState) { state in
            // Hold .matched state briefly so the green icon is visible, then go idle
            if case .matched = state {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    playerViewModel.speechSyncState = .idle
                }
            }
            // Reset failure alert flag when returning to idle
            if case .idle = state {
                playerViewModel.showSyncFailureAlert = false
            }
        }
        .alert("Sync Failed", isPresented: $playerViewModel.showSyncFailureAlert) {
            Button("Try Again") {
                playerViewModel.showSyncFailureAlert = false
                playerViewModel.speechSyncState = .idle
                playerViewModel.toggleSync()
            }
            Button("Cancel", role: .cancel) {
                playerViewModel.showSyncFailureAlert = false
                playerViewModel.speechSyncState = .idle
            }
        } message: {
            Text("No matching subtitle was found within 30 seconds. Make sure the movie audio is clearly audible.")
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            // Time labels
            HStack {
                Text(timeString(seekSliderValue))
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                Text(timeString(playerViewModel.totalDuration))
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
            }
            .padding(.horizontal, 20)

            // Seek slider
            Slider(
                value: $seekSliderValue,
                in: 0...max(playerViewModel.totalDuration, 1),
                onEditingChanged: { editing in
                    isDraggingSeek = editing
                    if !editing {
                        playerViewModel.seek(to: seekSliderValue)
                    }
                }
            )
            .tint(accent)
            .padding(.horizontal, 20)

            // Play/Pause + Sync row
            ZStack {
                // Play / Pause — centred
                Button {
                    playerViewModel.isPlaying ? playerViewModel.pause() : playerViewModel.play()
                } label: {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                }

                // Mic / Sync — trailing
                HStack {
                    Spacer()
                    SpeechSyncButton(
                        state: playerViewModel.speechSyncState,
                        onTap: { playerViewModel.toggleSync() }
                    )
                    .padding(.trailing, 28)
                }
            }
            .frame(height: 60)
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let t = max(0, time)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
