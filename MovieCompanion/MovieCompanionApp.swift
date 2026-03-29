import SwiftUI

@main
struct MovieCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct AppRootView: View {
    @State private var splashDone = false
    @State private var navigationPath = NavigationPath()
    @StateObject private var libraryViewModel = MovieLibraryViewModel()

    var body: some View {
        Group {
            if splashDone {
                NavigationStack(path: $navigationPath) {
                    MovieListView()
                        .navigationDestination(for: Movie.self) { movie in
                            LanguageSelectionView(movie: movie)
                        }
                        .navigationDestination(for: Language.self) { language in
                            SubtitlePlayerView(
                                language: language,
                                onFinished: {
                                    navigationPath.removeLast(navigationPath.count)
                                }
                            )
                        }
                }
                .environmentObject(libraryViewModel)
            } else {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        splashDone = true
                    }
                }
            }
        }
    }
}
