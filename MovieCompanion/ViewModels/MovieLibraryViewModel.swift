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
            movies = try await RemoteSubtitleLoader.loadManifest(from: url)
        } catch {
            remoteError = error.localizedDescription
        }
        isLoadingRemote = false
    }
}
