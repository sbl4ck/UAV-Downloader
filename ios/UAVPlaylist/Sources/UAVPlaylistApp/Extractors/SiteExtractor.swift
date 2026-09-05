import Foundation

/// One conforming type per supported site. Mirrors the shape of the Python
/// `M3U8Crawler` subclasses in `uav_downloader/sites/*.py`, but an extractor's
/// only job is to resolve the page URL to a playable stream URL — nothing here
/// downloads or decrypts video data.
protocol SiteExtractor {
    static var siteName: String { get }
    static func canHandle(_ url: URL) -> Bool
    static func extract(url: URL) async throws -> ExtractedVideo
}

let blockedStatusCodes: Set<Int> = [403, 429, 503]
