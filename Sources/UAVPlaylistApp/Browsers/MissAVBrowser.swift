import Foundation
import SwiftSoup

/// Swift port of `MissAVBrowser`, plus the signed-in account's saved playlists.
/// The fixed category list uses the site's `/en/` routes so labels come back in English.
enum MissAVBrowser: SiteBrowser {
    static let siteName = "MissAV"
    private static let root = "https://missav.ai"

    /// Section heading used for categories that came from the signed-in account.
    static let accountPlaylistGroup = "My Playlists"

    private static let fixedCategories: [(String, String)] = [
        ("Today's Hot", "\(root)/dm298/en/today-hot"),
        ("Weekly Hot", "\(root)/dm170/en/weekly-hot"),
        ("Monthly Hot", "\(root)/dm270/en/monthly-hot"),
        ("Chinese Subtitles", "\(root)/dm278/en/chinese-subtitle"),
        ("Latest", "\(root)/dm539/en/new"),
        ("New Releases", "\(root)/dm634/en/release"),
        ("Uncensored Leaks", "\(root)/dm817/en/uncensored-leak"),
        ("SIRO", "\(root)/dm36/en/siro"),
        ("FC2", "\(root)/dm541/en/fc2"),
        ("Madou Media", "\(root)/dm63/en/madou"),
        ("Tokyo Hot", "\(root)/dm42/en/tokyohot"),
        ("1Pondo", "\(root)/dm4854130/en/1pondo"),
    ]

    static func categories() async -> [BrowseCategory] {
        var result = fixedCategories.compactMap { name, urlString in
            URL(string: urlString).map { BrowseCategory(name: name, url: $0) }
        }
        // Saved playlists from the signed-in account, if there is one.
        result.append(contentsOf: await MissAVAccount.shared.playlists)
        return result
    }

    static func videos(at url: URL, page: Int) async throws -> [VideoListing] {
        let target = pageURL(base: url, page: page)
        let host = target.host ?? "missav.ai"
        let headers = ["Referer": "https://\(host)/", "Origin": "https://\(host)"]

        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(target, headers: headers, timeout: 30)
        } catch {
            throw ExtractionError.pageFetchFailed(error.localizedDescription)
        }
        if blockedStatusCodes.contains(response.response.statusCode) {
            throw ExtractionError.blocked(
                "MissAV blocked this request (Cloudflare or rate limiting). Try a VPN or a different network.")
        }
        guard let doc = try? SwiftSoup.parse(response.text) else {
            throw ExtractionError.parseFailed("Could not parse the listing page.")
        }

        // A playlist page lays its videos out differently from a category grid, so it
        // is parsed from the video links themselves rather than from card containers.
        if target.absoluteString.contains("/playlists/") {
            return parseByVideoLinks(doc, relativeTo: target)
        }
        return parseCards(doc, relativeTo: target)
    }

    static func searchURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        return URL(string: "\(root)/en/search/\(encoded)")
    }

    private static func pageURL(base: URL, page: Int) -> URL {
        guard page > 1 else { return base }
        let separator = base.absoluteString.contains("?") ? "&" : "?"
        return URL(string: "\(base.absoluteString)\(separator)page=\(page)") ?? base
    }

    // MARK: - Parsing

    private static func parseCards(_ doc: Document, relativeTo target: URL) -> [VideoListing] {
        var cards = (try? doc.select("div.thumbnail").array()) ?? []
        if cards.isEmpty {
            cards = (try? doc.select("div.group, article.video-item").array()) ?? []
        }

        var results: [VideoListing] = []
        var seen = Set<URL>()
        for card in cards {
            guard let anchor = try? card.select("a[href]").first(),
                  let href = try? anchor.attr("href"),
                  let videoURL = URL(string: href, relativeTo: target)?.absoluteURL,
                  isVideoPage(videoURL),
                  !seen.contains(videoURL) else { continue }
            seen.insert(videoURL)

            var thumbnail = ""
            var title = ""
            if let img = try? card.select("img").first() {
                thumbnail = (try? img.attr("data-src")) ?? ""
                if thumbnail.isEmpty { thumbnail = (try? img.attr("src")) ?? "" }
                title = (try? img.attr("alt")) ?? ""
            }
            if let titleAnchor = try? card.select("div.my-2 a, div.truncate a").first(),
               let text = try? titleAnchor.text(), !text.isEmpty {
                title = text
            }
            var duration = ""
            if let span = try? card.select("span.absolute.bottom-1.right-1").first(),
               let text = try? span.text() {
                duration = text
            }

            results.append(VideoListing(
                url: videoURL,
                title: decodeHTMLEntities(title.isEmpty ? videoURL.lastPathComponent : title),
                thumbnailURL: URL(string: thumbnail),
                duration: duration,
                siteName: siteName
            ))
        }
        return results
    }

    /// Link-driven parsing, used for playlist pages: every anchor that points at a
    /// video page becomes an entry, with the title/thumbnail/duration pulled from
    /// the anchor itself or its surrounding card.
    private static func parseByVideoLinks(_ doc: Document, relativeTo target: URL) -> [VideoListing] {
        var results: [VideoListing] = []
        var seen = Set<URL>()

        for anchor in (try? doc.select("a[href]").array()) ?? [] {
            guard let href = try? anchor.attr("href"),
                  let videoURL = URL(string: href, relativeTo: target)?.absoluteURL,
                  isVideoPage(videoURL),
                  !seen.contains(videoURL) else { continue }
            seen.insert(videoURL)

            // The playlist markup puts the code in the anchor's `alt`.
            var title = (try? anchor.attr("alt")) ?? ""
            if title.isEmpty, let img = try? anchor.select("img").first() {
                title = (try? img.attr("alt")) ?? ""
            }

            var thumbnail = ""
            let imageScope = anchor.parent() ?? anchor
            if let img = try? imageScope.select("img").first() {
                thumbnail = (try? img.attr("data-src")) ?? ""
                if thumbnail.isEmpty { thumbnail = (try? img.attr("src")) ?? "" }
                if title.isEmpty { title = (try? img.attr("alt")) ?? "" }
            }

            var duration = ""
            if let span = try? anchor.select("span.absolute.bottom-1.right-1").first(),
               let text = try? span.text() {
                duration = text
            }
            if duration.isEmpty,
               let span = try? imageScope.select("span.absolute.bottom-1.right-1").first(),
               let text = try? span.text() {
                duration = text
            }

            results.append(VideoListing(
                url: videoURL,
                title: decodeHTMLEntities(title.isEmpty ? videoURL.lastPathComponent : title),
                thumbnailURL: URL(string: thumbnail),
                duration: duration,
                siteName: siteName
            ))
        }
        return results
    }

    /// A MissAV video page, as opposed to a listing/category/playlist link.
    private static func isVideoPage(_ url: URL) -> Bool {
        let absolute = url.absoluteString
        if absolute.contains("/search/") || absolute.contains("/playlists/") { return false }
        // Video slugs always carry a digit in the last path segment.
        let lastSegment = url.lastPathComponent
        guard lastSegment.rangeOfCharacter(from: .decimalDigits) != nil else { return false }
        return MissAVExtractor.canHandle(url)
    }
}
