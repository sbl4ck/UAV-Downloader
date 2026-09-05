import Foundation

/// Helpers for matching the same title across sites by its JAV code (e.g. `ABCD-123`).
///
/// MissAV slugs carry the code plus a variant suffix — `ftk-037-uncensored-leak`,
/// `sone-543-chinese-subtitle` — so the code is read off the front of the slug and
/// used as a search term on another site.
enum JAVCode {
    /// Markers that suggest a result is the uncensored cut. Scored rather than
    /// required, so a censored match is still returned when nothing better exists.
    static let uncensoredMarkers = [
        "uncensored", "uncensored-leak", "leaked", "leak",
        "無碼", "无码", "無修正", "无修正", "破解",
    ]

    /// The code at the start of a slug, normalized to `ABCD-123`.
    /// Returns nil for slugs with no standard code (amateur/FC2-style ids such as
    /// `092014_887`), which can't be looked up by code on another site.
    static func extract(fromSlug slug: String) -> String? {
        let lower = slug.lowercased()
        guard let groups = allGroups(#"^([a-z]{2,6})-(\d{2,5})(?![0-9])"#, in: lower),
              groups.count >= 3 else { return nil }
        return "\(groups[1].uppercased())-\(groups[2])"
    }

    /// True when a listing plausibly *is* the given code, rather than merely
    /// mentioning something similar. The lookarounds stop `SONE-54` matching
    /// `SONE-543`.
    static func matches(code: String, listing: VideoListing) -> Bool {
        let haystack = (listing.title + " " + listing.url.absoluteString).lowercased()
        let needle = code.lowercased()
        if firstMatchString(#"(?<![a-z0-9])\#(needle)(?![0-9])"#, in: haystack) != nil {
            return true
        }
        // Some sites drop the hyphen in slugs (abcd123 rather than abcd-123).
        let compactNeedle = needle.replacingOccurrences(of: "-", with: "")
        let compactHaystack = haystack.replacingOccurrences(of: "-", with: "")
        return firstMatchString(
            #"(?<![a-z0-9])\#(compactNeedle)(?![0-9])"#, in: compactHaystack) != nil
    }

    /// How strongly a listing looks like an uncensored cut. Higher wins.
    static func uncensoredScore(_ listing: VideoListing) -> Int {
        let haystack = (listing.title + " " + listing.url.absoluteString).lowercased()
        return uncensoredMarkers.reduce(into: 0) { score, marker in
            if haystack.contains(marker) { score += 1 }
        }
    }
}
