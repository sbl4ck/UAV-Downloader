import Foundation

@MainActor
final class PlaylistViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var extracted: ExtractedVideo?
    @Published var playlistURL: URL?
    @Published var resolutionPreference: String = ResolutionPreference.current {
        didSet { ResolutionPreference.current = resolutionPreference }
    }

    var canOpenDirectlyInVLC: Bool {
        guard let stream = extracted?.streamURL else { return false }
        return VLCOpener.canOpenDirectly(streamURL: stream)
    }

    func openDirectlyInVLC() {
        guard let stream = extracted?.streamURL else { return }
        VLCOpener.openStreamDirectly(stream)
    }

    func buildPlaylist() {
        errorMessage = nil
        extracted = nil
        playlistURL = nil

        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            errorMessage = "Enter a valid video page URL (starting with https://)."
            return
        }
        guard let extractor = ExtractorRegistry.extractor(for: url) else {
            errorMessage = ExtractionError.unsupportedURL.errorDescription
            return
        }

        isLoading = true
        Task {
            do {
                let video = try await extractor.extract(url: url)
                let fileURL = try PlaylistBuilder.write(video)
                extracted = video
                playlistURL = fileURL
            } catch let error as ExtractionError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
