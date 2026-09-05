import Foundation
import SwiftSoup

/// Swift port of `JableTVBrowser` / `JableTVList` browse logic.
/// Category and tag names use the English labels from the original localization table.
enum JableTVBrowser: SiteBrowser {
    static let siteName = "JableTV"
    private static let root = "https://jable.tv"

    private static let homepageSections: [(String, String)] = [
        ("Latest", "\(root)/latest-updates/"),
        ("Popular", "\(root)/hot/"),
        ("New", "\(root)/new-release/"),
    ]

    static func categories() async -> [BrowseCategory] {
        var result = homepageSections.compactMap { name, urlString in
            URL(string: urlString).map { BrowseCategory(name: name, url: $0) }
        }

        // The live category list, same source as the desktop app's /categories/ scrape.
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
                  let text = try? anchor.text(),
                  !text.isEmpty,
                  !seen.contains(href),
                  let url = URL(string: href, relativeTo: URL(string: root))?.absoluteURL else { continue }
            seen.insert(href)
            // Strip the trailing "N videos" count the site appends to the label.
            let name = text.replacingOccurrences(
                of: #"\d[\d,]*\s*(?:videos?|部影片)"#,
                with: "", options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            result.append(BrowseCategory(name: name, url: url))
        }
        return result
    }

    static func tags() -> [BrowseCategory] {
        SiteCatalog.jableTags.compactMap { group, name, slug in
            URL(string: "\(root)/tags/\(slug)/").map {
                BrowseCategory(name: name, url: $0, group: group)
            }
        }
    }

    static func videos(at url: URL, page: Int) async throws -> [VideoListing] {
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
