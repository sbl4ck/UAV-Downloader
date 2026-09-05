import Foundation

/// Builds a VLC-compatible `.m3u8` playlist file that references the extracted
/// stream URL directly. VLC fetches and plays the stream itself — this app never
/// downloads video/segment data, which is the whole point of the playlist approach
/// versus the desktop app's segment-by-segment downloader.
enum PlaylistBuilder {
    static func write(_ video: ExtractedVideo) throws -> URL {
        var lines = ["#EXTM3U"]
        lines.append("#EXTINF:-1,\(video.title)")
        // VLC-specific options: carried into the HTTP request VLC makes for the
        // stream, mirroring the Referer/User-Agent headers the desktop app sends.
        if let referer = video.referer {
            lines.append("#EXTVLCOPT:http-referrer=\(referer)")
        }
        if let userAgent = video.userAgent {
            lines.append("#EXTVLCOPT:http-user-agent=\(userAgent)")
        }
        lines.append(video.streamURL.absoluteString)
        let content = lines.joined(separator: "\n") + "\n"

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UAVPlaylists", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent(sanitizedFilename(video.title) + ".m3u8")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static func sanitizedFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var name = title.components(separatedBy: invalid).joined(separator: "_")
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "video" }
        if name.count > 120 { name = String(name.prefix(120)) }
        return name
    }
}
