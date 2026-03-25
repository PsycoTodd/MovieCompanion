import SwiftUI

struct LanguageSelectionView: View {
    let movie: Movie

    var body: some View {
        List(movie.languages) { language in
            NavigationLink(value: language) {
                Text(language.displayName)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        .scrollContentBackground(.hidden)
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
