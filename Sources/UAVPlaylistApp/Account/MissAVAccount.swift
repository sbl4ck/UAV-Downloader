import Foundation
import SwiftSoup

/// Signs in to a MissAV account and exposes that account's saved playlists as
/// browsable categories.
///
/// The login endpoint is `POST /en/api/login` with an `email`/`password`/`remember`
/// body. It is an XHR API route (it answers 200 rather than redirecting), and it
/// carries no `_token` form field — so CSRF is supplied the Laravel XHR way, as an
/// `X-XSRF-TOKEN` header read from the `XSRF-TOKEN` cookie the site sets on first load.
///
/// Credentials never leave the device except in that request to MissAV itself, and
/// they are only persisted (to the Keychain) when "Remember me" is on.
@MainActor
final class MissAVAccount: ObservableObject {
    static let shared = MissAVAccount()

    static let root = "https://missav.ai"
    private static let keychainService = "com.uavdownloader.playlist.missav"
    private static let rememberKey = "missavRememberMe"

    enum AccountError: LocalizedError {
        case invalidCredentials
        case rateLimited
        case csrfFailed
        case network(String)
        case unexpected(Int)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "MissAV rejected that email and password."
            case .rateLimited:
                return "Too many sign-in attempts. Wait a few minutes and try again."
            case .csrfFailed:
                return "Could not establish a session with MissAV (CSRF token rejected). Try again."
            case .network(let detail):
                return "Could not reach MissAV: \(detail)"
            case .unexpected(let code):
                return "MissAV returned an unexpected response (HTTP \(code))."
            }
        }
    }

    @Published private(set) var isSignedIn = false
    @Published private(set) var email = ""
    @Published private(set) var playlists: [BrowseCategory] = []
    @Published private(set) var isWorking = false

    var rememberMe: Bool {
        get { UserDefaults.standard.bool(forKey: Self.rememberKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rememberKey) }
    }

    private init() {}

    // MARK: - Session

    /// Signs in with stored credentials, if "Remember me" saved any. Safe to call on launch.
    func restoreSession() async {
        guard !isSignedIn, rememberMe,
              let stored = KeychainStore.load(service: Self.keychainService) else { return }
        try? await signIn(email: stored.email, password: stored.password, remember: true)
    }

    func signIn(email: String, password: String, remember: Bool) async throws {
        isWorking = true
        defer { isWorking = false }

        do {
            try await performLogin(email: email, password: password, remember: remember)
        } catch AccountError.csrfFailed {
            // A stale CSRF token is the one failure worth a single silent retry:
            // re-prime the session for a fresh cookie, then try once more.
            try await performLogin(email: email, password: password, remember: remember)
        }

        self.email = email
        isSignedIn = true
        rememberMe = remember
        if remember {
            _ = KeychainStore.save(
                KeychainStore.Credentials(email: email, password: password),
                service: Self.keychainService
            )
        } else {
            KeychainStore.delete(service: Self.keychainService)
        }

        playlists = (try? await fetchPlaylists()) ?? []
    }

    func signOut() {
        KeychainStore.delete(service: Self.keychainService)
        rememberMe = false
        isSignedIn = false
        email = ""
        playlists = []
        if let url = URL(string: Self.root) {
            HTTPClient.shared.clearCookies(for: url)
        }
    }

    private func performLogin(email: String, password: String, remember: Bool) async throws {
        guard let homeURL = URL(string: "\(Self.root)/en"),
              let loginURL = URL(string: "\(Self.root)/en/api/login") else {
            throw AccountError.network("Invalid MissAV URL.")
        }

        // Establish the session and pick up the XSRF-TOKEN cookie.
        do {
            _ = try await HTTPClient.shared.get(homeURL, timeout: 30)
        } catch {
            throw AccountError.network(error.localizedDescription)
        }

        var headers = [
            "Accept": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "\(Self.root)/en/login",
            "Origin": Self.root,
        ]
        if let rawToken = HTTPClient.shared.cookieValue(named: "XSRF-TOKEN", for: homeURL) {
            headers["X-XSRF-TOKEN"] = rawToken.removingPercentEncoding ?? rawToken
        }

        let body: [String: Any] = ["email": email, "password": password, "remember": remember]
        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.postJSON(loginURL, body: body, headers: headers)
        } catch {
            throw AccountError.network(error.localizedDescription)
        }

        switch response.response.statusCode {
        case 200, 201, 204:
            return
        case 419:
            throw AccountError.csrfFailed
        case 401, 403, 422:
            throw AccountError.invalidCredentials
        case 429:
            throw AccountError.rateLimited
        case let code:
            throw AccountError.unexpected(code)
        }
    }

    // MARK: - Playlists

    /// Fetches the account's playlists and publishes them, so the Browse tab picks
    /// them up. Returns the fetched list for callers that want to report a count.
    @discardableResult
    func refreshPlaylists() async throws -> [BrowseCategory] {
        let fetched = try await fetchPlaylists()
        playlists = fetched
        return fetched
    }

    /// Reads `/en/playlists` and turns each saved playlist into a browsable category.
    func fetchPlaylists() async throws -> [BrowseCategory] {
        guard let url = URL(string: "\(Self.root)/en/playlists") else { return [] }
        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(
                url, headers: ["Referer": "\(Self.root)/en"], timeout: 30)
        } catch {
            throw AccountError.network(error.localizedDescription)
        }
        guard response.response.statusCode == 200 else {
            throw AccountError.unexpected(response.response.statusCode)
        }
        guard let doc = try? SwiftSoup.parse(response.text) else { return [] }

        var results: [BrowseCategory] = []
        var seen = Set<URL>()
        for anchor in (try? doc.select("a[href*=/playlists/]").array()) ?? [] {
            guard let href = try? anchor.attr("href"),
                  let playlistURL = URL(string: href, relativeTo: url)?.absoluteURL else { continue }

            // Only entries with an id after /playlists/ — not the index link itself.
            let id = playlistURL.lastPathComponent
            guard !id.isEmpty, id != "playlists", !seen.contains(playlistURL) else { continue }
            seen.insert(playlistURL)

            results.append(BrowseCategory(
                name: playlistName(from: anchor, fallbackID: id),
                url: playlistURL,
                group: MissAVBrowser.accountPlaylistGroup
            ))
        }
        return results
    }

    /// Best-effort name for one playlist entry. The card carries metadata such as
    /// "Last updated on YYYY-MM-DD" alongside the title, so that is stripped out.
    private func playlistName(from anchor: Element, fallbackID: String) -> String {
        var candidates: [String] = []
        if let title = try? anchor.attr("title"), !title.isEmpty { candidates.append(title) }
        for selector in ["h1", "h2", "h3", "h4", ".truncate"] {
            if let element = try? anchor.select(selector).first(),
               let text = try? element.text() {
                candidates.append(text)
            }
        }
        if let text = try? anchor.text() { candidates.append(text) }

        for candidate in candidates {
            let cleaned = candidate
                .replacingOccurrences(
                    of: #"Last updated on \d{4}-\d{2}-\d{2}"#,
                    with: "", options: .regularExpression)
                .replacingOccurrences(
                    of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return decodeHTMLEntities(cleaned)
            }
        }
        return SiteCatalog.titleCased(slug: fallbackID)
    }
}
