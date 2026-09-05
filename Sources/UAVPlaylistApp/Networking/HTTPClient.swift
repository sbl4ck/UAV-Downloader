import Foundation

struct HTTPResponse {
    let data: Data
    let response: HTTPURLResponse
    let finalURL: URL

    var text: String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

enum HTTPError: LocalizedError {
    case invalidResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an unexpected response."
        case .transport(let error): return error.localizedDescription
        }
    }
}

/// Thin async/await wrapper around URLSession. Cookies are kept in the shared
/// storage for the process lifetime so a multi-hop flow (e.g. SupJav's server
/// redirect chain) behaves like the Python `requests.Session()` it replaces.
final class HTTPClient {
    static let shared = HTTPClient()

    /// A realistic desktop UA. Some sites gate on a browser-looking UA string.
    static let desktopUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
    }

    @discardableResult
    func get(_ url: URL, headers: [String: String] = [:], timeout: TimeInterval = 30) async throws -> HTTPResponse {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(Self.desktopUserAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            return HTTPResponse(data: data, response: http, finalURL: response.url ?? url)
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.transport(error)
        }
    }
}
