import Foundation

/// Builds a VLC-compatible `.m3u8` playlist that references the extracted stream URLs
/// directly. VLC fetches and plays them itself — this app never downloads video data,
/// which is the whole point of the playlist approach versus a segment downloader.
enum PlaylistBuilder {
    /// Multi-entry playlist: one `#EXTINF` block per video, in queue order.
    /// VLC applies each `#EXTVLCOPT` to the entry that follows it, so per-video
    /// Referer/User-Agent headers survive into playback.
    static func write(_ videos: [ExtractedVideo], name: String) throws -> URL {
        var lines = ["#EXTM3U"]
        for video in videos {
            lines.append("#EXTINF:-1,\(sanitizedTitle(video.title))")
            if let referer = video.referer {
                lines.append("#EXTVLCOPT:http-referrer=\(referer)")
            }
            if let userAgent = video.userAgent {
                lines.append("#EXTVLCOPT:http-user-agent=\(userAgent)")
            }
            lines.append(video.streamURL.absoluteString)
        }
        let content = lines.joined(separator: "\n") + "\n"

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UAVPlaylists", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent(sanitizedFilename(name) + ".m3u8")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Single-video convenience, used by the "add by URL" path.
    static func write(_ video: ExtractedVideo) throws -> URL {
        try write([video], name: video.title)
    }

    /// A newline in a title would break the playlist's line-oriented format.
    private static func sanitizedTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizedFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var name = title.components(separatedBy: invalid).joined(separator: "_")
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "playlist" }
        if name.count > 120 { name = String(name.prefix(120)) }
        return name
    }
}
