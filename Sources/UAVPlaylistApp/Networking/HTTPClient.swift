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

    /// POST a JSON body. Used for MissAV's `/en/api/login` XHR endpoint.
    @discardableResult
    func postJSON(
        _ url: URL,
        body: [String: Any],
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> HTTPResponse {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await post(url, body: data, contentType: "application/json", headers: headers, timeout: timeout)
    }

    /// POST a form-encoded body, as a fallback when an endpoint rejects JSON.
    @discardableResult
    func postForm(
        _ url: URL,
        fields: [String: String],
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> HTTPResponse {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "%20", with: "+")
        return try await post(
            url,
            body: Data(encoded.utf8),
            contentType: "application/x-www-form-urlencoded",
            headers: headers,
            timeout: timeout
        )
    }

    private func post(
        _ url: URL,
        body: Data,
        contentType: String,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> HTTPResponse {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
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

    /// Current value of a cookie for a URL, from the shared cookie storage.
    /// Laravel stores the CSRF token URL-encoded in `XSRF-TOKEN`, so callers
    /// generally want this percent-decoded before sending it back as a header.
    func cookieValue(named name: String, for url: URL) -> String? {
        HTTPCookieStorage.shared.cookies(for: url)?
            .first { $0.name == name }?
            .value
    }

    /// Drops all cookies for a host — used when signing out of an account.
    func clearCookies(for url: URL) {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url) else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
