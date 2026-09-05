import Foundation

enum ExtractorRegistry {
    static let all: [SiteExtractor.Type] = [
        JableTVExtractor.self,
        MissAVExtractor.self,
        SupJavExtractor.self,
    ]

    static func extractor(for url: URL) -> SiteExtractor.Type? {
        all.first { $0.canHandle(url) }
    }
}
