import Foundation

struct MovieLibrary {
    static func loadAll() -> [Movie] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "srt", subdirectory: nil) else {
            return []
        }

        var languagesBySlug: [String: [Language]] = [:]
        var titleBySlug: [String: String] = [:]

        for url in urls {
            let stem = url.deletingPathExtension().lastPathComponent

            // Split on the last underscore to separate title and language code
            guard let underscoreRange = stem.range(of: "_", options: .backwards) else { continue }

            let titleRaw = String(stem[stem.startIndex..<underscoreRange.lowerBound])
            let languageCode = String(stem[underscoreRange.upperBound...])

            guard !titleRaw.isEmpty, !languageCode.isEmpty else { continue }

            let slug = titleRaw.lowercased()
            let displayTitle = titleRaw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            titleBySlug[slug] = displayTitle

            let language = Language(
                code: languageCode.uppercased(),
                displayName: displayName(for: languageCode),
                fileName: stem
            )
            languagesBySlug[slug, default: []].append(language)
        }

        return languagesBySlug.map { slug, languages in
            Movie(
                id: slug,
                title: titleBySlug[slug] ?? slug,
                languages: languages.sorted { $0.displayName < $1.displayName }
            )
        }
        .sorted { $0.title < $1.title }
    }

    private static func displayName(for code: String) -> String {
        switch code.uppercased() {
        case "EN": return "English"
        case "ZH": return "Chinese"
        case "FR": return "French"
        case "ES": return "Spanish"
        case "JA": return "Japanese"
        case "KO": return "Korean"
        case "DE": return "German"
        default: return code.uppercased()
        }
    }
}
