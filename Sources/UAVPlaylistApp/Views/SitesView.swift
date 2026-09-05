import SwiftUI

/// Top of the browse flow: pick a site, then a category or filter tag.
struct SitesView: View {
    private let sites = BrowserRegistry.all

    var body: some View {
        List {
            Section {
                ForEach(sites.indices, id: \.self) { index in
                    let site = sites[index]
                    NavigationLink(site.siteName) {
                        CategoryListView(siteName: site.siteName)
                    }
                }
            } header: {
                Text("Sites")
            } footer: {
                Text("Browse a site, pick videos, and they go to the Playlist tab. Nothing is downloaded — the playlist is handed to VLC to stream.")
            }
        }
        .navigationTitle("Browse")
    }
}
