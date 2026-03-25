import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "film.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)

                Text("MovieCompanion")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onFinished()
            }
        }
    }
}
