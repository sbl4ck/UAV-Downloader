import Foundation

/// Browse/search side of a site: the listing pages that let you find videos,
/// as opposed to `SiteExtractor`, which resolves one video page to a stream URL.
protocol SiteBrowser {
    static var siteName: String { get }

    /// Sections/categories to browse. May hit the network (JableTV reads its live
    /// category list); implementations should fall back to a static list on failure.
    static func categories() async -> [BrowseCategory]

    /// Optional filter tags, grouped for display. Empty when a site has none.
    static func tags() -> [BrowseCategory]

    /// One page of video cards for a listing URL. Page numbers are 1-based.
    static func videos(at url: URL, page: Int) async throws -> [VideoListing]

    /// Listing URL for a text search, or nil when a site has no search.
    static func searchURL(query: String) -> URL?
}

extension SiteBrowser {
    static func tags() -> [BrowseCategory] { [] }
}

enum BrowserRegistry {
    static let all: [any SiteBrowser.Type] = [
        JableTVBrowser.self,
        MissAVBrowser.self,
        SupJavBrowser.self,
    ]

    static func browser(named name: String) -> (any SiteBrowser.Type)? {
        all.first { $0.siteName == name }
    }
}
