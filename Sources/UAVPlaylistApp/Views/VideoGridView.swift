import SwiftUI

/// A paged video listing. When several categories are selected, their pages are fetched
/// together and merged into one de-duplicated grid (a video appearing in two selected
/// categories shows once). Tapping a card adds/removes it from the playlist queue.
struct VideoGridView: View {
    let siteName: String
    let title: String
    let sources: [BrowseCategory]

    @EnvironmentObject private var queue: QueueStore

    @State private var videos: [VideoListing] = []
    @State private var nextPage: [URL: Int] = [:]
    @State private var exhausted: Set<URL> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var browser: (any SiteBrowser.Type)? {
        BrowserRegistry.browser(named: siteName)
    }

    private var reachedEnd: Bool {
        exhausted.count >= sources.count
    }

    var body: some View {
        ScrollView {
            if sources.count > 1 {
                Text(sources.map(\.name).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(videos) { video in
                    VideoCard(video: video, isQueued: queue.contains(video))
                        .onTapGesture { queue.toggle(video) }
                }
            }
            .padding(.horizontal, 12)

            if isLoading {
                ProgressView().padding()
            } else if !reachedEnd && !videos.isEmpty {
                Button("Load more") { Task { await loadNextPage() } }
                    .padding()
            } else if videos.isEmpty && errorMessage == nil {
                ContentUnavailableView(
                    "No videos found",
                    systemImage: "film",
                    description: Text("This listing returned nothing. The site layout may have changed, or the page may be blocked.")
                )
                .padding(.top, 40)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    queue.add(contentsOf: videos)
                } label: {
                    Label("Add all", systemImage: "text.badge.plus")
                }
                .disabled(videos.isEmpty)
            }
        }
        .task {
            guard videos.isEmpty else { return }
            await loadNextPage()
        }
    }

    /// Pulls the next page from every source that still has one, then merges.
    private func loadNextPage() async {
        guard !isLoading, !reachedEnd, let browser else { return }
        isLoading = true
        errorMessage = nil

        var known = Set(videos.map(\.url))
        var merged: [VideoListing] = []
        var failures: [String] = []

        for source in sources where !exhausted.contains(source.url) {
            let page = nextPage[source.url] ?? 1
            do {
                let batch = try await browser.videos(at: source.url, page: page)
                let fresh = batch.filter { !known.contains($0.url) }
                if batch.isEmpty {
                    exhausted.insert(source.url)
                } else {
                    nextPage[source.url] = page + 1
                    known.formUnion(fresh.map(\.url))
                    merged.append(contentsOf: fresh)
                }
            } catch let error as ExtractionError {
                exhausted.insert(source.url)
                failures.append("\(source.name): \(error.errorDescription ?? "failed")")
            } catch {
                exhausted.insert(source.url)
                failures.append("\(source.name): \(error.localizedDescription)")
            }
        }

        videos.append(contentsOf: merged)
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
        isLoading = false
    }
}

/// One video card: thumbnail, title, duration, and a queued indicator.
struct VideoCard: View {
    let video: VideoListing
    let isQueued: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: video.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.2).aspectRatio(16 / 9, contentMode: .fill)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    default:
                        Color.gray.opacity(0.15).aspectRatio(16 / 9, contentMode: .fill)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Image(systemName: isQueued ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, isQueued ? Color.accentColor : Color.black.opacity(0.5))
                    .padding(6)
            }

            Text(video.title)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !video.duration.isEmpty || !video.date.isEmpty {
                Text([video.duration, video.date].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isQueued ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }
}
