import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    @State private var isShowingShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Video page URL") {
                    TextField("https://jable.tv/videos/...", text: $viewModel.urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        viewModel.buildPlaylist()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Build VLC playlist")
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.urlText.isEmpty)
                }

                Section("Preferred resolution") {
                    Picker("Resolution", selection: $viewModel.resolutionPreference) {
                        ForEach(ResolutionPreference.all, id: \.self) { value in
                            Text(value.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let video = viewModel.extracted, let playlistURL = viewModel.playlistURL {
                    Section("Result") {
                        LabeledContent("Site", value: video.siteName)
                        LabeledContent("Title", value: video.title)
                        LabeledContent("Stream type", value: video.isHLS ? "HLS (m3u8)" : "Direct MP4")

                        Button {
                            isShowingShareSheet = true
                        } label: {
                            Label("Open playlist (Copy to VLC…)", systemImage: "square.and.arrow.up")
                        }

                        if viewModel.canOpenDirectlyInVLC {
                            Button {
                                viewModel.openDirectlyInVLC()
                            } label: {
                                Label("Open stream directly in VLC", systemImage: "play.circle")
                            }
                        }

                        Text("Nothing is downloaded to this device. VLC streams the video directly from the source using the generated playlist.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .sheet(isPresented: $isShowingShareSheet) {
                        ShareSheet(items: [playlistURL])
                    }
                }

                Section("Supported sites") {
                    Text("JableTV, MissAV, SupJav")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("UAV Playlist")
        }
    }
}

#Preview {
    ContentView()
}
