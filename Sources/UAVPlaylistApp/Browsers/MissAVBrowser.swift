import Foundation
import SwiftSoup

/// Swift port of `MissAVBrowser`. The category list is fixed (same URLs as the
/// desktop app), with the English labels from the original localization table.
enum MissAVBrowser: SiteBrowser {
    static let siteName = "MissAV"
    private static let root = "https://missav.ai"

    private static let fixedCategories: [(String, String)] = [
        ("Today's Hot", "\(root)/dm298/today-hot"),
        ("Weekly Hot", "\(root)/dm170/weekly-hot"),
        ("Monthly Hot", "\(root)/dm270/monthly-hot"),
        ("Chinese Subtitles", "\(root)/dm278/chinese-subtitle"),
        ("Latest", "\(root)/dm539/new"),
        ("New Releases", "\(root)/dm634/release"),
        ("Uncensored Leaks", "\(root)/dm817/uncensored-leak"),
        ("SIRO", "\(root)/dm36/siro"),
        ("FC2", "\(root)/dm541/fc2"),
        ("Madou Media", "\(root)/dm63/madou"),
        ("Tokyo Hot", "\(root)/dm42/tokyohot"),
        ("1Pondo", "\(root)/dm4854130/1pondo"),
    ]

    static func categories() async -> [BrowseCategory] {
        fixedCategories.compactMap { name, urlString in
            URL(string: urlString).map { BrowseCategory(name: name, url: $0) }
        }
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
                  !seen.contains(videoURL) else { continue }

            let absolute = videoURL.absoluteString
            if absolute.contains("/search/") { continue }
            // Video pages always carry a digit in the last path segment; listing and
            // category links don't. Same guard the desktop browser applies.
            let lastSegment = videoURL.lastPathComponent
            guard lastSegment.rangeOfCharacter(from: .decimalDigits) != nil else { continue }
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
                title: decodeHTMLEntities(title),
                thumbnailURL: URL(string: thumbnail),
                duration: duration,
                siteName: siteName
            ))
        }
        return results
    }

    static func searchURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        return URL(string: "\(root)/search/\(encoded)")
    }

    private static func pageURL(base: URL, page: Int) -> URL {
        guard page > 1 else { return base }
        let separator = base.absoluteString.contains("?") ? "&" : "?"
        return URL(string: "\(base.absoluteString)\(separator)page=\(page)") ?? base
    }
}
