import Foundation
import SwiftSoup

/// Swift port of `JableTVBrowser` / `JableTVList` browse logic.
///
/// JableTV serves its category and video labels in Traditional Chinese by default and
/// switches language via a `kt_rt_lang` cookie — the same mechanism the desktop app's
/// `_apply_jable_lang` used. We always request English, and every label still goes
/// through `SiteCatalog.englishName` so nothing localized can reach the menu.
enum JableTVBrowser: SiteBrowser {
    static let siteName = "JableTV"
    private static let root = "https://jable.tv"

    /// Section heading for MissAV playlists mirrored onto JableTV by video code.
    static let missAVMirrorGroup = "From MissAV Playlists"

    private static let homepageSections: [(String, String)] = [
        ("Latest", "\(root)/latest-updates/"),
        ("Popular", "\(root)/hot/"),
        ("New", "\(root)/new-release/"),
    ]

    /// Ask JableTV (and its fs1.app mirror) for English labels.
    static func applyLanguageCookie() {
        for domain in [".jable.tv", ".fs1.app"] {
            guard let cookie = HTTPCookie(properties: [
                .domain: domain,
                .path: "/",
                .name: "kt_rt_lang",
                .value: "en",
            ]) else { continue }
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    static func categories() async -> [BrowseCategory] {
        applyLanguageCookie()

        var result = homepageSections.compactMap { name, urlString in
            URL(string: urlString).map { BrowseCategory(name: name, url: $0) }
        }

        guard let categoriesURL = URL(string: "\(root)/categories/"),
              let response = try? await HTTPClient.shared.get(categoriesURL, timeout: 30),
              response.response.statusCode == 200,
              let doc = try? SwiftSoup.parse(response.text),
              let anchors = try? doc.select("a[href*=/categories/]").array() else {
            return result
        }

        var seen = Set<String>()
        for anchor in anchors {
            guard let href = try? anchor.attr("href"),
                  href.contains("/categories/"),
                  href != "\(root)/categories/",
                  !seen.contains(href),
                  let url = URL(string: href, relativeTo: URL(string: root))?.absoluteURL else { continue }
            seen.insert(href)

            // Strip the trailing "N videos" count the site appends to the label.
            let rawLabel = ((try? anchor.text()) ?? "").replacingOccurrences(
                of: #"\d[\d,]*\s*(?:videos?|部影片)"#,
                with: "", options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let slug = url.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/").last.map(String.init) ?? ""
            let name = SiteCatalog.englishName(slug: slug, siteLabel: rawLabel)
            guard !name.isEmpty else { continue }
            result.append(BrowseCategory(name: name, url: url))
        }

        result.append(contentsOf: await missAVMirrorCategories())
        return result
    }

    /// One entry per saved MissAV playlist. The category keeps the *MissAV* URL —
    /// `videos(at:page:)` recognizes it and runs the code-matching pipeline rather
    /// than treating it as a JableTV listing.
    static func missAVMirrorCategories() async -> [BrowseCategory] {
        await MissAVAccount.shared.playlists.map { playlist in
            BrowseCategory(name: playlist.name, url: playlist.url, group: missAVMirrorGroup)
        }
    }

    static func tags() -> [BrowseCategory] {
        SiteCatalog.jableTags.compactMap { group, name, slug in
            URL(string: "\(root)/tags/\(slug)/").map {
                BrowseCategory(name: name, url: $0, group: group)
            }
        }
    }

    static func videos(at url: URL, page: Int) async throws -> [VideoListing] {
        // A mirrored MissAV playlist: resolve each entry's code on JableTV instead.
        if (url.host?.contains("missav") ?? false), url.absoluteString.contains("/playlists/") {
            return try await mirroredVideos(fromMissAVPlaylist: url, page: page)
        }

        applyLanguageCookie()

        let target = pageURL(base: url, page: page)
        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(target, timeout: 30)
        } catch {
            throw ExtractionError.pageFetchFailed(error.localizedDescription)
        }
        if blockedStatusCodes.contains(response.response.statusCode) {
            throw ExtractionError.blocked(
                "JableTV blocked this request (Cloudflare or rate limiting). Try a VPN or a different network.")
        }
        guard let doc = try? SwiftSoup.parse(response.text) else {
            throw ExtractionError.parseFailed("Could not parse the listing page.")
        }

        var results: [VideoListing] = []
        var seen = Set<URL>()
        let cards = (try? doc.select("div.video-img-box").array()) ?? []
        for card in cards {
            // Member-only videos are marked with a ribbon; they aren't playable.
            let ribbons = (try? card.select("div.ribbon-top-left").array()) ?? []
            if !ribbons.isEmpty { continue }

            guard let anchor = try? card.select("div.detail h6 a").first(),
                  let href = try? anchor.attr("href"),
                  let videoURL = URL(string: href, relativeTo: URL(string: root))?.absoluteURL,
                  !seen.contains(videoURL) else { continue }
            seen.insert(videoURL)

            let title = decodeHTMLEntities((try? anchor.text()) ?? "")
            var thumbnail = ""
            if let img = try? card.select("img").first() {
                thumbnail = (try? img.attr("data-src")) ?? ""
                if thumbnail.isEmpty { thumbnail = (try? img.attr("src")) ?? "" }
            }
            var duration = ""
            if let label = try? card.select("span.label").first(), let text = try? label.text() {
                duration = text
            }

            results.append(VideoListing(
                url: videoURL,
                title: title,
                thumbnailURL: URL(string: thumbnail),
                duration: duration,
                siteName: siteName
            ))
        }
        return results
    }

    // MARK: - MissAV playlist mirroring

    /// Reads one page of a MissAV playlist, pulls the JAV code off each entry, and
    /// resolves each code to a JableTV video — preferring the uncensored cut.
    ///
    /// Searches run one at a time on purpose: these sites rate-limit aggressively,
    /// and a burst of parallel searches is what trips their blocking. A page of
    /// entries therefore takes a while to resolve.
    private static func mirroredVideos(
        fromMissAVPlaylist playlistURL: URL,
        page: Int
    ) async throws -> [VideoListing] {
        let sourceEntries = try await MissAVBrowser.videos(at: playlistURL, page: page)

        var results: [VideoListing] = []
        var seenCodes = Set<String>()
        var seenURLs = Set<URL>()

        for entry in sourceEntries {
            guard let code = JAVCode.extract(fromSlug: entry.url.lastPathComponent),
                  !seenCodes.contains(code) else { continue }
            seenCodes.insert(code)

            guard let match = await bestMatch(for: code),
                  !seenURLs.contains(match.url) else { continue }
            seenURLs.insert(match.url)
            results.append(match)
        }
        return results
    }

    /// The best JableTV result for a code: it must actually be that code, and among
    /// those, the one with the strongest uncensored markers wins.
    private static func bestMatch(for code: String) async -> VideoListing? {
        guard let searchURL = searchURL(query: code),
              let candidates = try? await videos(at: searchURL, page: 1) else { return nil }

        let matching = candidates.filter { JAVCode.matches(code: code, listing: $0) }
        guard !matching.isEmpty else { return nil }
        return matching.max { JAVCode.uncensoredScore($0) < JAVCode.uncensoredScore($1) }
    }

    static func searchURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return URL(string: "\(root)/search/\(encoded)/")
    }

    /// JableTV paginates listings with `?from=N`.
    private static func pageURL(base: URL, page: Int) -> URL {
        guard page > 1 else { return base }
        let separator = base.absoluteString.contains("?") ? "&" : "?"
        return URL(string: "\(base.absoluteString)\(separator)from=\(page)") ?? base
    }
}
