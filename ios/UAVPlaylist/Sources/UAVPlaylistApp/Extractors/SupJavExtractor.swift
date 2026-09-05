import Foundation
import SwiftSoup

/// Swift port of `SiteSupJav` from `uav_downloader/sites/supjav.py`.
///
/// SupJav video pages list several backing "servers" (FST, ST, TV, VOE). We try them
/// in the same priority order as the original: FST (HLS with real quality variants),
/// then Streamtape (progressive MP4 fallback), then TV (last-resort HLS).
enum SupJavExtractor: SiteExtractor {
    static let siteName = "SupJav"

    private static let dirnamePattern = #"^https://supjav\.com/(?:(?:zh|ja)/)?(\d+)\.html$"#
    private static let defaultReferer = "https://supjav.com/"

    static func canHandle(_ url: URL) -> Bool {
        firstGroup(dirnamePattern, in: url.absoluteString, caseInsensitive: true) != nil
    }

    static func extract(url: URL) async throws -> ExtractedVideo {
        let response = try await fetchPage(url)
        guard response.text.contains("data-link") else {
            throw ExtractionError.parseFailed("The page did not list any server links (layout may have changed).")
        }

        let doc: Document
        do {
            doc = try SwiftSoup.parse(response.text)
        } catch {
            throw ExtractionError.parseFailed("HTML parsing failed.")
        }

        let servers = (try? serverLinks(doc)) ?? [:]
        guard !servers.isEmpty else {
            throw ExtractionError.noStreamFound("No servers are listed for this video (layout may have changed).")
        }

        var masterURLString: String?
        var streamHeaders: [String: String] = [:]
        var directURLString: String?
        var directReferer: String?

        // 1) FST: downloadable HLS with real 480p/720p/1080p variants.
        if let fst = servers["FST"] {
            if let fstResponse = try? await HTTPClient.shared.get(
                supremeJavURL(for: fst), headers: ["Referer": defaultReferer], timeout: 25),
               let extracted = extractPackedM3U8(from: fstResponse.text) {
                masterURLString = extracted
                streamHeaders["Referer"] = fstResponse.finalURL.absoluteString
                if let scheme = fstResponse.finalURL.scheme, let host = fstResponse.finalURL.host {
                    streamHeaders["Origin"] = "\(scheme)://\(host)"
                }
            }
        }

        // 2) Streamtape (ST): progressive MP4 fallback, resolved even when FST worked
        //    so an HLS failure can downgrade without re-fetching the page.
        if let st = servers["ST"] {
            if let stResponse = try? await HTTPClient.shared.get(
                supremeJavURL(for: st), headers: ["Referer": defaultReferer], timeout: 25),
               let direct = streamtapeDirectURL(from: stResponse.text) {
                directURLString = direct
                directReferer = stResponse.finalURL.absoluteString
            }
        }

        // 3) TV: last HLS fallback (its Google-backed segments often return 429).
        if masterURLString == nil, directURLString == nil, let tv = servers["TV"] {
            let tvResponse = try await HTTPClient.shared.get(
                supremeJavURL(for: tv), headers: ["Referer": defaultReferer], timeout: 20)
            if blockedStatusCodes.contains(tvResponse.response.statusCode) {
                throw ExtractionError.blocked(
                    "All mirrors were blocked by Cloudflare (possibly a network/IP reputation issue). Try a VPN or a different network.")
            }
            if let extracted = extractM3U8(from: tvResponse.text) {
                masterURLString = extracted
                streamHeaders = ["Referer": defaultReferer]
            }
        }

        guard masterURLString != nil || directURLString != nil else {
            throw ExtractionError.noStreamFound(
                "This video has no available source right now (the TV server is Google-rate-limited and this video has no FST/Streamtape fallback).")
        }

        let title = (try? extractTitle(doc)) ?? "SupJav video"

        if let masterURLString, let masterURL = URL(string: masterURLString) {
            let streamURL = await HLSVariantSelector.resolve(
                masterURL: masterURL, headers: streamHeaders, preference: ResolutionPreference.current)
            return ExtractedVideo(
                title: title,
                thumbnailURL: nil,
                streamURL: streamURL,
                isHLS: true,
                referer: streamHeaders["Referer"] ?? defaultReferer,
                origin: streamHeaders["Origin"],
                userAgent: HTTPClient.desktopUserAgent,
                siteName: siteName
            )
        }
        if let directURLString, let directURL = URL(string: directURLString) {
            return ExtractedVideo(
                title: title,
                thumbnailURL: nil,
                streamURL: directURL,
                isHLS: false,
                referer: directReferer,
                origin: nil,
                userAgent: HTTPClient.desktopUserAgent,
                siteName: siteName
            )
        }
        throw ExtractionError.noStreamFound("Could not build a valid stream URL.")
    }

    private static func fetchPage(_ url: URL) async throws -> HTTPResponse {
        let response: HTTPResponse
        do {
            response = try await HTTPClient.shared.get(url, timeout: 30)
        } catch {
            throw ExtractionError.pageFetchFailed(error.localizedDescription)
        }
        if blockedStatusCodes.contains(response.response.statusCode) {
            throw ExtractionError.blocked(
                "All mirrors were blocked by Cloudflare (possibly a network/IP reputation issue). Try a VPN or a different network.")
        }
        return response
    }
}

/// SupJav stores each server's routing token reversed in `data-link`; the desktop
/// app reverses it back (`servers['FST'][::-1]`) before building the SupremeJAV URL.
private func supremeJavURL(for dataLink: String) -> URL {
    let reversed = String(dataLink.reversed())
    return URL(string: "https://lk1.supremejav.com/supjav.php?c=\(reversed)")!
}

private func serverLinks(_ doc: Document) throws -> [String: String] {
    var out: [String: String] = [:]
    for element in try doc.select("a.btn-server[data-link]").array() {
        let name = try element.text().trimmingCharacters(in: .whitespaces).uppercased()
        let link = try element.attr("data-link")
        if !name.isEmpty, !link.isEmpty, out[name] == nil {
            out[name] = link
        }
    }
    return out
}

private func extractTitle(_ doc: Document) throws -> String {
    if let heading = try doc.select("h1").first() {
        let text = try heading.text()
        if !text.isEmpty { return text }
    }
    return try doc.title()
}

private func extractM3U8(from body: String) -> String? {
    let cleaned = body.replacingOccurrences(of: "\\/", with: "/")
    if let match = firstGroup(#"urlPlay[\s=:'"]+(https?://[^\s'"\\]+\.m3u8[^\s'"\\]*)"#, in: cleaned) {
        return match
    }
    return firstMatchString(#"https?://[^\s'"\\]+\.m3u8[^\s'"\\]*"#, in: cleaned)
}

private func extractPackedM3U8(from html: String) -> String? {
    for script in scriptBlocks(in: html) {
        guard script.contains("eval(function"), script.contains("m3u8") else { continue }
        guard let unpacked = PackedJSDecoder.unpack(script) else { continue }
        if let match = firstMatchString(#"https?://[^'"\\;\s]+\.m3u8[^'"\\;\s]*"#, in: unpacked) {
            return match
        }
    }
    return nil
}

/// Streamtape overwrites `#robotlink` via JS: `'PREFIX' + ('SUFFIX').substring(a)[.substring(b)]`
/// — the static div text is a decoy; only the JS-computed value carries the live token.
private func streamtapeDirectURL(from html: String) -> String? {
    guard let groups = allGroups(
        #"getElementById\(\s*['"]robotlink['"]\s*\)\.innerHTML\s*=\s*['"]([^'"]*)['"]\s*\+\s*(?:['"]{2}\s*\+\s*)?\(\s*['"]([^'"]*)['"]\s*\)((?:\.substring\(\s*\d+\s*\))+)"#,
        in: html), groups.count >= 4 else { return nil }

    let prefix = groups[1]
    var suffix = groups[2]
    let subsChain = groups[3]
    for offsetText in allMatches(#"substring\(\s*(\d+)\s*\)"#, in: subsChain, groupIndex: 1) {
        guard let offset = Int(offsetText), offset <= suffix.count else { continue }
        suffix = String(suffix.dropFirst(offset))
    }

    var link = prefix + suffix
    while link.hasPrefix("/") { link.removeFirst() }
    guard link.contains("get_video") else { return nil }
    return "https://" + link
}
