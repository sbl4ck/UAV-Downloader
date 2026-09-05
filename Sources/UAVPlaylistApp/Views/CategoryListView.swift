import SwiftUI

/// Categories and filter tags for one site.
struct CategoryListView: View {
    let siteName: String

    @State private var categories: [BrowseCategory] = []
    @State private var tags: [BrowseCategory] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private var browser: (any SiteBrowser.Type)? {
        BrowserRegistry.browser(named: siteName)
    }

    private var groupedTags: [(String, [BrowseCategory])] {
        let groups = Dictionary(grouping: tags) { $0.group ?? "Tags" }
        return SiteCatalog.jableTagGroups.compactMap { name in
            guard let items = groups[name], !items.isEmpty else { return nil }
            return (name, items)
        }
    }

    var body: some View {
        List {
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty,
               let searchURL = browser?.searchURL(query: searchText) {
                Section("Search") {
                    NavigationLink("Results for “\(searchText)”") {
                        VideoGridView(
                            siteName: siteName,
                            title: "Search: \(searchText)",
                            listingURL: searchURL
                        )
                    }
                }
            }

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading categories…").foregroundStyle(.secondary)
                }
            }

            if !categories.isEmpty {
                Section("Categories") {
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            VideoGridView(
                                siteName: siteName,
                                title: category.name,
                                listingURL: category.url
                            )
                        }
                    }
                }
            }

            ForEach(groupedTags, id: \.0) { groupName, items in
                Section(groupName) {
                    ForEach(items) { tag in
                        NavigationLink(tag.name) {
                            VideoGridView(
                                siteName: siteName,
                                title: tag.name,
                                listingURL: tag.url
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(siteName)
        .searchable(text: $searchText, prompt: "Search \(siteName)")
        .task {
            guard categories.isEmpty else { return }
            guard let browser else {
                isLoading = false
                return
            }
            tags = browser.tags()
            categories = await browser.categories()
            isLoading = false
        }
    }
}
