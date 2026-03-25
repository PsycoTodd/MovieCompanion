import SwiftUI

struct MovieListView: View {
    @EnvironmentObject var libraryViewModel: MovieLibraryViewModel

    var body: some View {
        List(libraryViewModel.movies) { movie in
            NavigationLink(value: movie) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .foregroundColor(.white)
                            .font(.body)
                        Text(movie.languages.map(\.displayName).joined(separator: ", "))
                            .foregroundColor(Color(white: 0.5))
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        .scrollContentBackground(.hidden)
        .navigationTitle("MovieCompanion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
