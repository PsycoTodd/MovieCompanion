import Foundation

struct RemoteSubtitleLoader {
    private struct ManifestEntry: Decodable {
        let name: String
        let url: String
    }

    static func loadManifest(from manifestURL: URL) async throws -> [Movie] {
        let (data, _) = try await URLSession.shared.data(from: manifestURL)
        let entries = try JSONDecoder().decode([ManifestEntry].self, from: data)

        var languagesBySlug: [String: [Language]] = [:]
        var titleBySlug: [String: String] = [:]

        for entry in entries {
            let stem = (entry.name as NSString).deletingPathExtension
            guard let underscoreRange = stem.range(of: "_", options: .backwards) else { continue }

            let titleRaw = String(stem[stem.startIndex..<underscoreRange.lowerBound])
            let languageCode = String(stem[underscoreRange.upperBound...])
            guard !titleRaw.isEmpty, !languageCode.isEmpty else { continue }
            guard let downloadURL = URL(string: entry.url) else { continue }

            let slug = titleRaw.lowercased()
            titleBySlug[slug] = titleRaw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            let language = Language(
                code: languageCode.uppercased(),
                displayName: MovieLibrary.displayName(for: languageCode),
                fileName: stem,
                remoteURL: downloadURL
            )
            languagesBySlug[slug, default: []].append(language)
        }

        return languagesBySlug.map { slug, languages in
            Movie(
                id: "remote_\(slug)",
                title: titleBySlug[slug] ?? slug,
                languages: languages.sorted { $0.displayName < $1.displayName }
            )
        }
        .sorted { $0.title < $1.title }
    }

    static func loadSRT(from url: URL) async throws -> [SubtitleLine] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let rawContent = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return SRTParser.parseContent(rawContent)
    }
}
