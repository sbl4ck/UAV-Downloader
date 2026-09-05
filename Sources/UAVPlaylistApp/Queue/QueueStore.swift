import Foundation

/// The playlist queue: videos picked while browsing, held until you build a playlist.
/// Persisted to disk so the queue survives app restarts, the same way the desktop
/// app's download queue did — except nothing here downloads.
@MainActor
final class QueueStore: ObservableObject {
    @Published private(set) var items: [VideoListing] = []

    private let fileURL: URL

    init(filename: String = "queue.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(filename)
        load()
    }

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }

    func contains(_ video: VideoListing) -> Bool {
        items.contains { $0.url == video.url }
    }

    func toggle(_ video: VideoListing) {
        if contains(video) {
            remove(video)
        } else {
            add(video)
        }
    }

    func add(_ video: VideoListing) {
        guard !contains(video) else { return }
        items.append(video)
        save()
    }

    func add(contentsOf videos: [VideoListing]) {
        var changed = false
        for video in videos where !contains(video) {
            items.append(video)
            changed = true
        }
        if changed { save() }
    }

    func remove(_ video: VideoListing) {
        items.removeAll { $0.url == video.url }
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([VideoListing].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
