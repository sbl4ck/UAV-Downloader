import Foundation

/// All user-facing text is English — this mirrors (and replaces) the Chinese
/// status/error strings from the original Python site modules.
enum ExtractionError: LocalizedError {
    case unsupportedURL
    case pageFetchFailed(String)
    case blocked(String)
    case parseFailed(String)
    case noStreamFound(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "This URL is not from a supported site (JableTV, MissAV, or SupJav)."
        case .pageFetchFailed(let detail):
            return "Could not load the page: \(detail)"
        case .blocked(let detail):
            return "The site blocked this request. \(detail)"
        case .parseFailed(let detail):
            return "Could not read the page layout (the site may have changed). \(detail)"
        case .noStreamFound(let detail):
            return "No playable video stream was found. \(detail)"
        }
    }
}
