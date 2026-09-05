import Foundation

/// Swift port of `_unpack_js_eval` from `uav_downloader/sites/missav.py` — decodes the
/// Dean Edwards p,a,c,k,e,d JavaScript packer that MissAV/SupJav use to hide the m3u8
/// URL inside an inline `<script>` block.
enum PackedJSDecoder {
    private static let headerPattern =
        #"eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?\}\('(.*?)',\s*(\d+),\s*(\d+),\s*'([^']*)'\s*\.split\('\|'\)"#

    static func unpack(_ scriptText: String) -> String? {
        guard let groups = allGroups(headerPattern, in: scriptText), groups.count >= 5 else { return nil }
        let packed = groups[1]
        guard let a = Int(groups[2]), let c = Int(groups[3]) else { return nil }
        let keys = groups[4].components(separatedBy: "|")

        // Guard against malformed packer params, same as the Python original:
        // base<=1 would loop forever, and an absurd `c` would allocate an unbounded lookup.
        guard a > 1, c >= 0, c <= 200_000 else { return nil }

        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        func toBase(_ value: Int, _ base: Int) -> String {
            if value == 0 { return "0" }
            var n = value
            var s = ""
            while n > 0 {
                s = String(digits[n % base]) + s
                n /= base
            }
            return s
        }

        var lookup: [String: String] = [:]
        lookup.reserveCapacity(c)
        for i in 0..<c {
            let key = toBase(i, a)
            lookup[key] = (i < keys.count && !keys[i].isEmpty) ? keys[i] : key
        }

        guard let wordRegex = try? NSRegularExpression(pattern: #"\b(\w+)\b"#) else { return packed }
        let nsPacked = packed as NSString
        let matches = wordRegex.matches(in: packed, range: NSRange(location: 0, length: nsPacked.length))

        var result = ""
        var lastEnd = 0
        for match in matches {
            let range = match.range
            result += nsPacked.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
            let token = nsPacked.substring(with: range)
            result += lookup[token] ?? token
            lastEnd = range.location + range.length
        }
        result += nsPacked.substring(from: lastEnd)
        return result
    }
}
