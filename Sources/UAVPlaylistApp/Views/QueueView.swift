import SwiftUI

/// The queue of picked videos: resolve them once, then play in-app or export to VLC.
struct QueueView: View {
    @EnvironmentObject private var queue: QueueStore
    @StateObject private var job = PlaylistJob()
    @State private var isShowingShareSheet = false
    @State private var playlistName = "UAV Playlist"

    var body: some View {
        List {
            if queue.isEmpty {
                ContentUnavailableView(
                    "Playlist is empty",
                    systemImage: "list.and.film",
                    description: Text("Browse a site and tap videos to add them here, or add one directly from the Add URL tab.")
                )
            } else {
                Section("Playlist name") {
                    TextField("Playlist name", text: $playlistName)
                }

                Section("\(queue.count) video\(queue.count == 1 ? "" : "s")") {
                    ForEach(queue.items) { video in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(video.title).lineLimit(2)
                            Text(video.siteName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { queue.remove(atOffsets: $0) }
                }

                Section {
                    if job.isRunning {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: job.progress)
                            Text("Resolving \(job.resolvedCount) of \(job.totalCount)…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !job.currentTitle.isEmpty {
                                Text(job.currentTitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Button {
                            Task { await job.build(from: queue.items, playlistName: playlistName) }
                        } label: {
                            Label("Resolve playlist", systemImage: "play.rectangle.on.rectangle")
                        }
                    }
                } footer: {
                    Text("Each video's page is opened just long enough to find its stream URL. No video data is downloaded — playback streams from the source.")
                }
            }

            if let errorMessage = job.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            if !job.failures.isEmpty {
                Section("Could not resolve (\(job.failures.count))") {
                    ForEach(job.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.video.title).font(.callout).lineLimit(1)
                            Text(failure.reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !job.resolved.isEmpty {
                Section {
                    NavigationLink {
                        PlayerView(videos: job.resolved)
                    } label: {
                        Label(
                            "Play \(job.resolved.count) video\(job.resolved.count == 1 ? "" : "s") in app",
                            systemImage: "play.rectangle.fill"
                        )
                    }
                } header: {
                    Text("Ready")
                } footer: {
                    Text("Plays here with the headers each stream needs, advancing through the list automatically. The VLC export below stays available as an alternative.")
                }
            }

            if let playlistURL = job.playlistURL {
                Section("Export") {
                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label("Open playlist (Copy to VLC…)", systemImage: "square.and.arrow.up")
                    }
                    Text(playlistURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .sheet(isPresented: $isShowingShareSheet) {
                    ShareSheet(items: [playlistURL])
                }
            }
        }
        .navigationTitle("Playlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) {
                    queue.clear()
                    job.reset()
                }
                .disabled(queue.isEmpty)
            }
        }
    }
}
