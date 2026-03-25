import SwiftUI

struct SpeechSyncButton: View {
    let state: SpeechSyncState
    let onTap: () -> Void

    @State private var pulsing = false

    private let accent = Color(red: 0.9, green: 0.79, blue: 0.48)

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Pulse ring — visible only while listening
                Circle()
                    .stroke(accent.opacity(0.4), lineWidth: 2)
                    .scaleEffect(pulsing ? 1.8 : 1.0)
                    .opacity(pulsing ? 0 : 0.6)
                    .animation(
                        isListening
                            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: pulsing
                    )
                    .frame(width: 44, height: 44)

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
            }
        }
        .onChange(of: isListening) { listening in
            pulsing = listening
        }
        .onAppear {
            pulsing = isListening
        }
    }

    private var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    private var iconName: String {
        switch state {
        case .listening:         return "mic.fill"
        case .matched:          return "checkmark.circle.fill"
        case .failed:           return "mic.slash.fill"
        case .idle:             return "mic.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .listening:        return accent
        case .matched:          return .green
        case .failed:           return .red
        case .idle:             return Color(white: 0.55)
        }
    }
}
