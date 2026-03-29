import Foundation

@MainActor
class MovieLibraryViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoadingRemote = false
    @Published var remoteError: String? = nil

    private let manifestURLKey = "manifestURL"

    var manifestURL: String {
        get { UserDefaults.standard.string(forKey: manifestURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: manifestURLKey) }
    }

    init() {
        movies = MovieLibrary.loadAll()
        Task { await loadRemoteMovies() }
    }

    func setManifestURL(_ urlString: String) {
        manifestURL = urlString
        Task { await loadRemoteMovies() }
    }

    func loadRemoteMovies() async {
        guard !manifestURL.isEmpty, let url = URL(string: manifestURL) else { return }
        isLoadingRemote = true
        remoteError = nil
        do {
            let remoteMovies = try await RemoteSubtitleLoader.loadManifest(from: url)
            mergeRemoteMovies(remoteMovies)
        } catch {
            remoteError = error.localizedDescription
        }
        isLoadingRemote = false
    }

    private func mergeRemoteMovies(_ remoteMovies: [Movie]) {
        var merged = MovieLibrary.loadAll()
        let bundleTitles = Set(merged.map { $0.title.lowercased() })
        for movie in remoteMovies where !bundleTitles.contains(movie.title.lowercased()) {
            merged.append(movie)
        }
        movies = merged.sorted { $0.title < $1.title }
    }
}
