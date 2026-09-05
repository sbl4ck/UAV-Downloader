import Foundation

/// One video card from a browse/search listing. This is what a listing page gives
/// us cheaply (title, thumbnail, duration) — the actual stream URL is only resolved
/// later, when the queue is turned into a playlist.
struct VideoListing: Identifiable, Codable, Hashable {
    let url: URL
    let title: String
    let thumbnailURL: URL?
    let duration: String
    let date: String
    let siteName: String

    var id: URL { url }

    init(url: URL, title: String, thumbnailURL: URL? = nil,
         duration: String = "", date: String = "", siteName: String) {
        self.url = url
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.date = date
        self.siteName = siteName
    }
}

/// A browsable section of a site: a homepage section, a category, or a tag.
struct BrowseCategory: Identifiable, Hashable {
    let name: String
    let url: URL
    /// Grouping label for tag lists ("Clothing", "Body", …); nil for plain categories.
    let group: String?

    var id: URL { url }

    init(name: String, url: URL, group: String? = nil) {
        self.name = name
        self.url = url
        self.group = group
    }
}
