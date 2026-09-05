import Foundation

/// Swift port of `select_variant` / `_create_m3u8` from `uav_downloader/sites/base.py`.
/// VLC can play a master HLS playlist directly and auto-switch quality itself, but to
/// honor the user's resolution preference (the same "highest/lowest/1080/720/480/360"
/// choices the desktop app offers) we resolve to one concrete variant up front.
enum HLSVariantSelector {
    struct Variant {
        let uri: String
        let height: Int?
        let bandwidth: Int
    }

    /// Fetches `masterURL`; if it is a master playlist with `#EXT-X-STREAM-INF` variants,
    /// returns the absolute URL of the variant matching `preference`. Otherwise (plain
    /// media playlist, fetch failure, or parse failure) returns `masterURL` unchanged —
    /// VLC can still play the original URL fine.
    static func resolve(masterURL: URL, headers: [String: String], preference: String) async -> URL {
        guard let response = try? await HTTPClient.shared.get(masterURL, headers: headers, timeout: 20),
              response.response.statusCode == 200 else { return masterURL }
        let text = response.text
        guard text.contains("#EXTM3U") else { return masterURL }

        let variants = parseVariants(text)
        guard !variants.isEmpty, let chosen = select(variants, preference: preference) else { return masterURL }
        return URL(string: chosen.uri, relativeTo: response.finalURL)?.absoluteURL ?? masterURL
    }

    private static func parseVariants(_ text: String) -> [Variant] {
        var variants: [Variant] = []
        let lines = text.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                let bandwidth = Int(firstGroup(#"BANDWIDTH=(\d+)"#, in: line) ?? "") ?? 0
                let height = firstGroup(#"RESOLUTION=\d+x(\d+)"#, in: line).flatMap(Int.init)
                if index + 1 < lines.count {
                    let uri = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if !uri.isEmpty, !uri.hasPrefix("#") {
                        variants.append(Variant(uri: uri, height: height, bandwidth: bandwidth))
                    }
                }
            }
            index += 1
        }
        return variants
    }

    private static func select(_ variants: [Variant], preference: String) -> Variant? {
        let pref = preference.lowercased()
        let known = variants.filter { $0.height != nil }

        if pref == "lowest" {
            if !known.isEmpty { return known.min { ($0.height!, $0.bandwidth) < ($1.height!, $1.bandwidth) } }
            return variants.min { $0.bandwidth < $1.bandwidth }
        }
        if let target = Int(pref), [1080, 720, 480, 360].contains(target) {
            if known.isEmpty { return variants.max { $0.bandwidth < $1.bandwidth } }
            let atOrBelow = known.filter { $0.height! <= target }
            if !atOrBelow.isEmpty { return atOrBelow.max { ($0.height!, $0.bandwidth) < ($1.height!, $1.bandwidth) } }
            return known.min { ($0.height!, -$0.bandwidth) < ($1.height!, -$1.bandwidth) }
        }
        if !known.isEmpty { return known.max { ($0.height!, $0.bandwidth) < ($1.height!, $1.bandwidth) } }
        return variants.max { $0.bandwidth < $1.bandwidth }
    }
}
