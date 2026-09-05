import Foundation

/// Swift port of `SiteMissAV` from `uav_downloader/sites/missav.py`.
enum MissAVExtractor: SiteExtractor {
    static let siteName = "MissAV"

    private static let hostPattern =
        #"^https://(?:www\.)?(?:missav\.(?:ai|ws|live)|missav123\.com)/"#
    private static let dirnamePattern =
        #"^https://(?:www\.)?(?:missav\.(?:ai|ws|live)|missav123\.com)/(?:dm\d+/)?(?:(?:cn|en|ja|ko|ms|th)/)?([a-zA-Z0-9][a-zA-Z0-9\-_]*[-_]\d[a-zA-Z0-9\-_]*)"#

    static func canHandle(_ url: URL) -> Bool {
        let s = url.absoluteString
        guard firstMatchString(hostPattern, in: s, groupIndex: 0, caseInsensitive: true) != nil else { return false }
        return firstGroup(dirnamePattern, in: s, caseInsensitive: true) != nil
    }

    static func extract(url: URL) async throws -> ExtractedVideo {
        let host = url.host ?? "missav.ai"
        let pageHeaders = ["Referer": "https://\(host)/", "Origin": "https://\(host)"]

        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(url, headers: pageHeaders, timeout: 30)
        } catch {
            throw ExtractionError.pageFetchFailed(error.localizedDescription)
        }
        if blockedStatusCodes.contains(response.response.statusCode) {
            throw ExtractionError.blocked(
                "All mirrors were blocked by Cloudflare (possibly a network/IP reputation issue). Try a VPN or a different network.")
        }

        let text = response.text
        // Only reject outright when the page isn't a video page at all (a block or
        // challenge page). Anything else is worth attempting: the marker check used
        // to be stricter than the parser, so pages carrying a plain, unpacked m3u8
        // were rejected before extraction ever ran.
        guard text.contains("og:title") else {
            throw ExtractionError.parseFailed("The page did not contain the expected markers (layout change, missing video, or a block page).")
        }

        let title = firstGroup(#"og:title"\s+content="([^"]+)""#, in: text) ?? ""
        let image = firstGroup(#"og:image"\s+content="([^"]+)""#, in: text)

        var streamURLString: String?
        for script in scriptBlocks(in: text) {
            guard script.contains("eval(function"), script.contains("m3u8") else { continue }
            guard let unpacked = PackedJSDecoder.unpack(script) else { continue }
            // "source=" (not source842= etc.) followed by the URL.
            if let match = firstGroup(#"source\s*=\s*[\\']*(https?://[^'\\;\s]+\.m3u8)"#, in: unpacked) {
                streamURLString = match
                break
            }
            if let match = firstGroup(#"(https?://[^'\\;\s]+\.m3u8)"#, in: unpacked) {
                streamURLString = match
                break
            }
        }
        // Not every page hides the stream in a packed script — some carry it inline.
        if streamURLString == nil {
            streamURLString = firstGroup(#"(https?://[^'"\\;\s]+\.m3u8)"#, in: text)
        }

        guard let masterURLString = streamURLString, let masterURL = URL(string: masterURLString) else {
            throw ExtractionError.noStreamFound("Could not find an m3u8 stream in the page scripts for \(url.absoluteString).")
        }

        let finalHost = response.finalURL.host ?? host
        let streamHeaders = ["Referer": "https://\(finalHost)/", "Origin": "https://\(finalHost)"]
        let streamURL = await HLSVariantSelector.resolve(
            masterURL: masterURL, headers: streamHeaders, preference: ResolutionPreference.current)

        return ExtractedVideo(
            title: decodeHTMLEntities(title.isEmpty ? url.lastPathComponent : title),
            thumbnailURL: image.flatMap(URL.init(string:)),
            streamURL: streamURL,
            isHLS: true,
            referer: "https://\(finalHost)/",
            origin: "https://\(finalHost)",
            userAgent: HTTPClient.desktopUserAgent,
            siteName: siteName
        )
    }
}
