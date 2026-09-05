import SwiftUI

struct ContentView: View {
    @StateObject private var queue = QueueStore()

    var body: some View {
        TabView {
            NavigationStack {
                SitesView()
            }
            .tabItem { Label("Browse", systemImage: "square.grid.2x2") }

            NavigationStack {
                AddByURLView()
            }
            .tabItem { Label("Add URL", systemImage: "link") }

            NavigationStack {
                QueueView()
            }
            .tabItem { Label("Playlist", systemImage: "list.and.film") }
            .badge(queue.count)
        }
        .environmentObject(queue)
    }
}

#Preview {
    ContentView()
}
