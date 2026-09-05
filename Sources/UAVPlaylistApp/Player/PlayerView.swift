import AVKit
import SwiftUI

/// Full-screen playback for a resolved playlist: the system player on top, the
/// queue below, tap any row to jump to it.
struct PlayerView: View {
    let videos: [ExtractedVideo]
    var startIndex: Int = 0

    @StateObject private var playlistPlayer = PlaylistPlayer()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PlayerSurface(player: playlistPlayer.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

            HStack(spacing: 28) {
                Button {
                    playlistPlayer.previous()
                } label: {
                    Image(systemName: "backward.end.fill").font(.title2)
                }
                .disabled(!playlistPlayer.hasPrevious)

                Button {
                    playlistPlayer.togglePlayPause()
                } label: {
                    Image(systemName: playlistPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }

                Button {
                    playlistPlayer.next()
                } label: {
                    Image(systemName: "forward.end.fill").font(.title2)
                }
                .disabled(!playlistPlayer.hasNext)
            }
            .padding(.vertical, 12)

            List {
                Section("Up next (\(playlistPlayer.videos.count))") {
                    ForEach(Array(playlistPlayer.videos.enumerated()), id: \.offset) { index, video in
                        Button {
                            playlistPlayer.play(at: index)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: index == playlistPlayer.currentIndex
                                      ? "play.circle.fill" : "\(min(index + 1, 50)).circle")
                                    .foregroundStyle(index == playlistPlayer.currentIndex
                                                     ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.title)
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                    Text(video.siteName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(playlistPlayer.current?.title ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard playlistPlayer.videos.isEmpty else { return }
            playlistPlayer.load(videos, startingAt: startIndex)
        }
        .onDisappear { playlistPlayer.stop() }
    }
}

/// `AVPlayerViewController` gives native transport controls, AirPlay, full screen
/// and Picture in Picture for free, which a hand-rolled surface would not.
struct PlayerSurface: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
