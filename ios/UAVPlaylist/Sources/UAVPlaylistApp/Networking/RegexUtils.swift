import Foundation

/// Small regex helpers used to port the original Python `re.search`/`re.findall`
/// calls in the site extractors as directly as possible.

func firstGroup(_ pattern: String, in text: String, groupIndex: Int = 1, caseInsensitive: Bool = false) -> String? {
    firstMatchString(pattern, in: text, groupIndex: groupIndex, caseInsensitive: caseInsensitive)
}

func firstMatchString(
    _ pattern: String,
    in text: String,
    groupIndex: Int = 0,
    caseInsensitive: Bool = false,
    dotMatchesNewlines: Bool = false
) -> String? {
    var options: NSRegularExpression.Options = []
    if caseInsensitive { options.insert(.caseInsensitive) }
    if dotMatchesNewlines { options.insert(.dotMatchesLineSeparators) }
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > groupIndex,
          let matchRange = Range(match.range(at: groupIndex), in: text) else { return nil }
    return String(text[matchRange])
}

/// All capture groups (index 0 = full match) of the first match, or nil if there is none.
func allGroups(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> [String]? {
    var options: NSRegularExpression.Options = [.dotMatchesLineSeparators]
    if caseInsensitive { options.insert(.caseInsensitive) }
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    var groups: [String] = []
    for index in 0..<match.numberOfRanges {
        if let r = Range(match.range(at: index), in: text) {
            groups.append(String(text[r]))
        } else {
            groups.append("")
        }
    }
    return groups
}

func allMatches(_ pattern: String, in text: String, groupIndex: Int = 0, caseInsensitive: Bool = false) -> [String] {
    var options: NSRegularExpression.Options = []
    if caseInsensitive { options.insert(.caseInsensitive) }
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard match.numberOfRanges > groupIndex,
              let r = Range(match.range(at: groupIndex), in: text) else { return nil }
        return String(text[r])
    }
}

func scriptBlocks(in html: String) -> [String] {
    allMatches(#"<script[^>]*>([\s\S]*?)</script>"#, in: html, groupIndex: 1)
}

private let namedHTMLEntities: [String: String] = [
    "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
    "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
]

/// Minimal HTML-entity unescape, covering the entities that actually show up
/// in video titles/thumbnail URLs (mirrors Python's `html.unescape` for our needs).
func decodeHTMLEntities(_ text: String) -> String {
    var result = text
    for (entity, value) in namedHTMLEntities {
        result = result.replacingOccurrences(of: entity, with: value)
    }
    result = replaceNumericEntities(in: result, pattern: "&#x([0-9a-fA-F]+);", radix: 16)
    result = replaceNumericEntities(in: result, pattern: "&#(\\d+);", radix: 10)
    return result
}

private func replaceNumericEntities(in text: String, pattern: String, radix: Int) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
    var result = text
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    // Replace back-to-front so earlier match ranges stay valid against `result`.
    for match in matches.reversed() {
        guard let fullRange = Range(match.range, in: result),
              let numberRange = Range(match.range(at: 1), in: result),
              let code = UInt32(result[numberRange], radix: radix),
              let scalar = Unicode.Scalar(code) else { continue }
        result.replaceSubrange(fullRange, with: String(Character(scalar)))
    }
    return result
}
