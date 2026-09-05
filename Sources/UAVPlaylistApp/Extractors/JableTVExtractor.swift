import Foundation

/// Swift port of `SiteJableTV` from `uav_downloader/sites/jabletv.py`.
enum JableTVExtractor: SiteExtractor {
    static let siteName = "JableTV"

    private static let urlPattern = #"^https://(?:jable\.tv|fs1\.app)/videos/.+/$"#

    static func canHandle(_ url: URL) -> Bool {
        firstMatchString(urlPattern, in: url.absoluteString, groupIndex: 0, caseInsensitive: true) != nil
    }

    static func extract(url: URL) async throws -> ExtractedVideo {
        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(url, timeout: 30)
        } catch {
            throw ExtractionError.pageFetchFailed(error.localizedDescription)
        }
        if blockedStatusCodes.contains(response.response.statusCode) {
            throw ExtractionError.blocked(
                "All mirrors were blocked by Cloudflare (possibly a network/IP reputation issue). Try a VPN or a different network.")
        }

        let text = response.text
        guard text.contains("og:title"), text.contains("m3u8") else {
            throw ExtractionError.parseFailed("The page did not contain the expected markers (layout change or missing video).")
        }
        guard let title = firstGroup(#"og:title"\s+content="([^"]+)""#, in: text),
              let image = firstGroup(#"og:image"\s+content="([^"]+)""#, in: text),
              let m3u8 = firstMatchString(#"https://[^\s"']+\.m3u8"#, in: text) else {
            throw ExtractionError.parseFailed("Could not find the title, thumbnail, or m3u8 URL on the page.")
        }
        guard let masterURL = URL(string: m3u8) else {
            throw ExtractionError.parseFailed("The m3u8 URL found on the page is invalid.")
        }

        let headers = ["Referer": url.absoluteString]
        let streamURL = await HLSVariantSelector.resolve(
            masterURL: masterURL, headers: headers, preference: ResolutionPreference.current)

        return ExtractedVideo(
            title: decodeHTMLEntities(title),
            thumbnailURL: URL(string: image),
            streamURL: streamURL,
            isHLS: true,
            referer: url.absoluteString,
            origin: nil,
            userAgent: HTTPClient.desktopUserAgent,
            siteName: siteName
        )
    }
}
