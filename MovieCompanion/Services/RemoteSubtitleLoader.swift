import Foundation

struct RemoteSubtitleLoader {
    private struct ManifestEntry: Decodable {
        let name: String
        let url: String
    }

    static func loadManifest(from manifestURL: URL) async throws -> [Movie] {
        let (data, _) = try await URLSession.shared.data(from: resolveDownloadURL(manifestURL))
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
            let englishURL = languages.first { $0.code == "EN" }?.remoteURL
            let annotated = languages.map { lang in
                Language(
                    code: lang.code,
                    displayName: lang.displayName,
                    fileName: lang.fileName,
                    remoteURL: lang.remoteURL,
                    englishRemoteURL: lang.code == "EN" ? nil : englishURL
                )
            }
            return Movie(
                id: "remote_\(slug)",
                title: titleBySlug[slug] ?? slug,
                languages: annotated.sorted { $0.displayName < $1.displayName }
            )
        }
        .sorted { $0.title < $1.title }
    }

    static func resolveDownloadURL(_ url: URL) -> URL {
        // Convert Google Drive share link to direct download URL
        // e.g. https://drive.google.com/file/d/FILE_ID/view?... → https://drive.google.com/uc?export=download&id=FILE_ID
        let urlString = url.absoluteString
        if urlString.contains("drive.google.com/file/d/") {
            let components = urlString.components(separatedBy: "/")
            if let dIndex = components.firstIndex(of: "d"), dIndex + 1 < components.count {
                let fileID = components[dIndex + 1].components(separatedBy: "?").first ?? components[dIndex + 1]
                if let downloadURL = URL(string: "https://drive.google.com/uc?export=download&id=\(fileID)") {
                    return downloadURL
                }
            }
        }
        return url
    }

    static func loadSRT(from url: URL) async throws -> [SubtitleLine] {
        let (data, _) = try await URLSession.shared.data(from: resolveDownloadURL(url))
        guard let rawContent = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return SRTParser.parseContent(rawContent)
    }
}
