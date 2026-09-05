import Foundation

/// Turns a queue of browsed videos into one playlist file: resolves each video page
/// to its stream URL, then writes a single multi-entry `.m3u8`. Videos that fail to
/// resolve are reported rather than silently dropped.
@MainActor
final class PlaylistJob: ObservableObject {
    struct Failure: Identifiable {
        let video: VideoListing
        let reason: String
        var id: URL { video.url }
    }

    @Published private(set) var isRunning = false
    @Published private(set) var resolvedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var currentTitle = ""
    @Published private(set) var failures: [Failure] = []
    @Published private(set) var playlistURL: URL?
    /// The successfully resolved videos, kept so they can be played in-app without
    /// re-resolving. Cleared by `reset()` alongside everything else.
    @Published private(set) var resolved: [ExtractedVideo] = []
    @Published var errorMessage: String?

    var progress: Double {
        totalCount > 0 ? Double(resolvedCount) / Double(totalCount) : 0
    }

    func reset() {
        isRunning = false
        resolvedCount = 0
        totalCount = 0
        currentTitle = ""
        failures = []
        playlistURL = nil
        resolved = []
        errorMessage = nil
    }

    /// Resolves every queued video in order and writes the combined playlist.
    /// Sequential on purpose: these sites rate-limit aggressively, and a burst of
    /// parallel page fetches is what triggers their blocking.
    func build(from videos: [VideoListing], playlistName: String = "UAV Playlist") async {
        guard !isRunning else { return }
        reset()
        guard !videos.isEmpty else {
            errorMessage = "The queue is empty. Add some videos first."
            return
        }

        isRunning = true
        totalCount = videos.count

        var collected: [ExtractedVideo] = []
        for video in videos {
            currentTitle = video.title
            do {
                guard let extractor = ExtractorRegistry.extractor(for: video.url) else {
                    throw ExtractionError.unsupportedURL
                }
                let extracted = try await extractor.extract(url: video.url)
                collected.append(extracted)
            } catch let error as ExtractionError {
                failures.append(Failure(video: video, reason: error.errorDescription ?? "Unknown error"))
            } catch {
                failures.append(Failure(video: video, reason: error.localizedDescription))
            }
            resolvedCount += 1
        }

        currentTitle = ""

        resolved = collected

        guard !collected.isEmpty else {
            isRunning = false
            errorMessage = "None of the \(videos.count) queued video(s) could be resolved to a stream."
            return
        }

        do {
            playlistURL = try PlaylistBuilder.write(collected, name: playlistName)
        } catch {
            errorMessage = "Could not write the playlist file: \(error.localizedDescription)"
        }
        isRunning = false
    }
}
