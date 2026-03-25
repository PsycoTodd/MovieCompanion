import Foundation

@MainActor
class MovieLibraryViewModel: ObservableObject {
    @Published var movies: [Movie] = []

    init() {
        movies = MovieLibrary.loadAll()
    }
}
