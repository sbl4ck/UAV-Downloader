import Foundation

/// Everything needed to build a VLC playlist entry for one video page.
/// No video or segment data is ever downloaded to build this — only the
/// page HTML (and a couple of small redirect hops) are fetched.
struct ExtractedVideo {
    let title: String
    let thumbnailURL: URL?
    let streamURL: URL
    let isHLS: Bool
    let referer: String?
    let origin: String?
    let userAgent: String?
    let siteName: String
}
