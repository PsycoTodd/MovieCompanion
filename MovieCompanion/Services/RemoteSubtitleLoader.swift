import Foundation

struct RemoteSubtitleLoader {

    // MARK: - Disk Cache

    private static var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("SRTCache")
    }

    private static func cacheURL(for remoteURL: URL) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        let key = remoteURL.absoluteString
            .data(using: .utf8)
            .map { Data($0).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
            } ?? String(remoteURL.absoluteString.hashValue)
        return dir.appendingPathComponent("\(key).srt")
    }

    private static func cachedContent(for remoteURL: URL) -> String? {
        guard let file = cacheURL(for: remoteURL) else { return nil }
        return try? String(contentsOf: file, encoding: .utf8)
    }

    private static func writeCache(content: String, for remoteURL: URL) {
        guard let dir = cacheDirectory, let file = cacheURL(for: remoteURL) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: - URL Helpers

    static func resolveDownloadURL(_ url: URL) -> URL {
        // Convert Google Drive share link to direct download URL
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

    // MARK: - Manifest

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

    // MARK: - SRT Loading with Cache

    static func loadSRT(from url: URL) async throws -> [SubtitleLine] {
        let resolvedURL = resolveDownloadURL(url)

        if let cached = cachedContent(for: resolvedURL) {
            return SRTParser.parseContent(cached)
        }

        let (data, _) = try await URLSession.shared.data(from: resolvedURL)
        guard let rawContent = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        writeCache(content: rawContent, for: resolvedURL)
        return SRTParser.parseContent(rawContent)
    }
}
