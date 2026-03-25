import SwiftUI

struct SubtitlePlayerView: View {
    let fileName: String
    let onFinished: () -> Void

    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var fontSize: Double = 28
    @State private var seekSliderValue: Double = 0
    @State private var isDraggingSeek: Bool = false

    private let accent = Color(red: 0.9, green: 0.79, blue: 0.48)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Subtitle display
                Text(playerViewModel.currentLine?.text ?? "")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut(duration: 0.25), value: playerViewModel.currentLine?.id)

                Spacer()

                controlsView
                    .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

            // Font size row
            HStack(spacing: 8) {
                Text("A")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                Slider(value: $fontSize, in: 16...48)
                    .tint(Color(white: 0.5))
                Text("A")
                    .font(.system(size: 20))
                    .foregroundColor(Color(white: 0.5))
            }
            .padding(.horizontal, 20)

            // Play / Pause button
            Button {
                playerViewModel.isPlaying ? playerViewModel.pause() : playerViewModel.play()
            } label: {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let t = max(0, time)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
