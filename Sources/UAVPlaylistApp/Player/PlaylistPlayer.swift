import AVKit
import Foundation

/// Plays a resolved playlist inside the app, one video at a time, advancing
/// automatically at the end of each item.
///
/// A plain `AVPlayer` with a hand-managed index is used rather than
/// `AVQueuePlayer`, because a queue player can only ever advance — this needs
/// arbitrary jumping so the user can tap any row in the playlist.
@MainActor
final class PlaylistPlayer: ObservableObject {
    @Published private(set) var videos: [ExtractedVideo] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false

    let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    var current: ExtractedVideo? {
        videos.indices.contains(currentIndex) ? videos[currentIndex] : nil
    }
    var hasNext: Bool { currentIndex + 1 < videos.count }
    var hasPrevious: Bool { currentIndex > 0 }

    // MARK: - Loading

    func load(_ videos: [ExtractedVideo], startingAt index: Int = 0) {
        self.videos = videos
        configureAudioSession()
        play(at: index)
    }

    func play(at index: Int) {
        guard videos.indices.contains(index) else { return }
        currentIndex = index
        player.replaceCurrentItem(with: makeItem(for: videos[index]))
        player.play()
        isPlaying = true
    }

    func next() {
        guard hasNext else {
            player.pause()
            isPlaying = false
            return
        }
        play(at: currentIndex + 1)
    }

    func previous() {
        guard hasPrevious else { return }
        play(at: currentIndex - 1)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    /// Releases the current item and end-of-item observer. Call when leaving playback.
    func stop() {
        removeEndObserver()
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
    }

    // MARK: - Item construction

    /// These CDNs reject stream requests that arrive without the originating page's
    /// Referer, so the headers the extractor captured are attached to the asset.
    ///
    /// `AVURLAssetHTTPHeaderFieldsKey` is the long-standing (though not formally
    /// documented) way to set request headers on an AVURLAsset. The alternative —
    /// an AVAssetResourceLoader delegate proxying every segment — is far more code
    /// for the same result.
    private func makeItem(for video: ExtractedVideo) -> AVPlayerItem {
        var headers: [String: String] = [:]
        if let referer = video.referer { headers["Referer"] = referer }
        if let origin = video.origin { headers["Origin"] = origin }
        if let userAgent = video.userAgent { headers["User-Agent"] = userAgent }

        let options: [String: Any]? = headers.isEmpty
            ? nil
            : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: video.streamURL, options: options)
        let item = AVPlayerItem(asset: asset)
        observeEnd(of: item)
        return item
    }

    private func observeEnd(of item: AVPlayerItem) {
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    /// Playback should keep going with the ringer switch silenced, and continue in
    /// the background / Picture in Picture.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal: playback still works, it just follows the silent switch.
        }
    }
}
