struct Movie: Identifiable, Hashable {
    let id: String           // slug derived from title, e.g. "inception"
    let title: String
    let languages: [Language]
}
