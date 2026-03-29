struct Language: Identifiable, Hashable {
    let code: String         // e.g. "EN", "ZH", "FR"
    let displayName: String  // e.g. "English", "Chinese", "French"
    let fileName: String     // resource name without extension, e.g. "Inception_EN"
    let remoteURL: URL?      // set for remote languages; nil for bundle files

    var id: String { fileName }

    init(code: String, displayName: String, fileName: String, remoteURL: URL? = nil) {
        self.code = code
        self.displayName = displayName
        self.fileName = fileName
        self.remoteURL = remoteURL
    }
}
