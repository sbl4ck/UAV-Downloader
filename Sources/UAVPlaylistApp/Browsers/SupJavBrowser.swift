import Foundation
import SwiftSoup

/// Swift port of `SupJavBrowser`, including its `_parse_videos` card parsing.
enum SupJavBrowser: SiteBrowser {
    static let siteName = "SupJav"
    private static let root = "https://supjav.com"

    private static let fixedCategories: [(String, String)] = [
        ("Latest", "\(root)/"),
        ("Popular", "\(root)/popular"),
        ("Weekly Hot", "\(root)/popular?sort=week"),
        ("Monthly Hot", "\(root)/popular?sort=month"),
        ("Uncensored", "\(root)/category/uncensored-jav"),
        ("Censored", "\(root)/category/censored-jav"),
        ("Amateur", "\(root)/category/amateur"),
        ("Chinese Subtitles", "\(root)/category/chinese-subtitles"),
        ("English Subtitles", "\(root)/category/english-subtitles"),
        ("Mosaic Removed", "\(root)/category/reducing-mosaic"),
    ]

    static func categories() async -> [BrowseCategory] {
        fixedCategories.compactMap { name, urlString in
            URL(string: urlString).map { BrowseCategory(name: name, url: $0) }
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
                "SupJav blocked this request (Cloudflare or rate limiting). Try a VPN or a different network.")
        }
        guard let doc = try? SwiftSoup.parse(response.text) else {
            throw ExtractionError.parseFailed("Could not parse the listing page.")
        }

        var results: [VideoListing] = []
        var seen = Set<URL>()
        for post in (try? doc.select("div.post").array()) ?? [] {
            guard let anchor = try? post.select("a[href*=.html]").first(),
                  let href = try? anchor.attr("href"),
                  let videoURL = URL(string: href, relativeTo: target)?.absoluteURL,
                  !seen.contains(videoURL) else { continue }
            seen.insert(videoURL)

            var title = (try? anchor.attr("title")) ?? ""
            if title.isEmpty { title = (try? anchor.text()) ?? "" }

            var thumbnail = ""
            if let img = try? post.select("img").first() {
                thumbnail = (try? img.attr("data-original")) ?? ""
                if thumbnail.isEmpty { thumbnail = (try? img.attr("data-src")) ?? "" }
                if thumbnail.isEmpty {
                    let src = (try? img.attr("src")) ?? ""
                    if !src.hasPrefix("data:") { thumbnail = src }
                }
            }

            var date = ""
            if let meta = try? post.select("div.meta").first(), let text = try? meta.text() {
                date = firstMatchString(#"(?<!\d)20\d{2}/\d{1,2}/\d{1,2}(?!\d)"#, in: text) ?? ""
            }

            results.append(VideoListing(
                url: videoURL,
                title: decodeHTMLEntities(title),
                thumbnailURL: URL(string: thumbnail),
                date: date,
                siteName: siteName
            ))
        }
        return results
    }

    static func searchURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        return URL(string: "\(root)/?s=\(encoded)")
    }

    /// SupJav uses `/page/N` for plain listings and `&page=N` once a query string exists;
    /// search results keep the `?s=` query after the `/page/N` segment.
    private static func pageURL(base: URL, page: Int) -> URL {
        guard page > 1 else { return base }
        let absolute = base.absoluteString
        if absolute.contains("?s=") || absolute.contains("&s=") {
            let parts = absolute.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            let head = String(parts[0]).trimmingTrailingSlash()
            let query = parts.count > 1 ? String(parts[1]) : ""
            return URL(string: "\(head)/page/\(page)/?\(query)") ?? base
        }
        if absolute.contains("?") {
            return URL(string: "\(absolute)&page=\(page)") ?? base
        }
        return URL(string: "\(absolute.trimmingTrailingSlash())/page/\(page)") ?? base
    }
}

private extension String {
    func trimmingTrailingSlash() -> String {
        var value = self
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }
}
