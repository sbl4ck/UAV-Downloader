import SwiftUI

/// Adds a single video page URL to the queue by hand, for when you already have a
/// link rather than browsing for one. The stream URL and real title are resolved
/// later, when the playlist is built.
struct AddByURLView: View {
    @EnvironmentObject private var queue: QueueStore

    @State private var urlText = ""
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                TextField("https://jable.tv/videos/…", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Add to playlist queue") { add() }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Video page URL")
            } footer: {
                Text("Supported: JableTV, MissAV, SupJav.")
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(isError ? .red : .green)
                }
            }

            Section {
                Text("\(queue.count) video\(queue.count == 1 ? "" : "s") queued")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add by URL")
    }

    private func add() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            message = "Enter a valid video page URL (starting with https://)."
            isError = true
            return
        }
        guard let extractor = ExtractorRegistry.extractor(for: url) else {
            message = ExtractionError.unsupportedURL.errorDescription
            isError = true
            return
        }

        // Provisional title from the URL; the real one arrives when the playlist builds.
        let provisionalTitle = url.lastPathComponent.isEmpty
            ? url.absoluteString
            : url.lastPathComponent
        let listing = VideoListing(
            url: url,
            title: provisionalTitle,
            siteName: extractor.siteName
        )

        if queue.contains(listing) {
            message = "That video is already in the queue."
            isError = true
        } else {
            queue.add(listing)
            message = "Added to the queue (\(extractor.siteName))."
            isError = false
            urlText = ""
        }
    }
}
