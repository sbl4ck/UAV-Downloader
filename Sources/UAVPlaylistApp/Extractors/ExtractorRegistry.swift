import Foundation

enum ExtractorRegistry {
    static let all: [any SiteExtractor.Type] = [
        JableTVExtractor.self,
        MissAVExtractor.self,
        SupJavExtractor.self,
    ]

    static func extractor(for url: URL) -> (any SiteExtractor.Type)? {
        all.first { $0.canHandle(url) }
    }
}
