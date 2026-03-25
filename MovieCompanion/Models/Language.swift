struct Language: Identifiable, Hashable {
    let code: String         // e.g. "EN", "ZH", "FR"
    let displayName: String  // e.g. "English", "Chinese", "French"
    let fileName: String     // bundle resource name without extension, e.g. "Inception_EN"

    var id: String { fileName }
}
