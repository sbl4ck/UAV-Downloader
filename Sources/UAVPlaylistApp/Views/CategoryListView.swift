import SwiftUI

/// Categories and filter tags for one site, selected with checkboxes so several can be
/// combined at once — the same multi-select shape the desktop app's category picker had.
struct CategoryListView: View {
    let siteName: String

    @State private var categories: [BrowseCategory] = []
    @State private var tags: [BrowseCategory] = []
    @State private var selected: Set<BrowseCategory> = []
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

    /// Selection in the order the sections present it, so the merged listing is stable.
    private var orderedSelection: [BrowseCategory] {
        (categories + tags).filter { selected.contains($0) }
    }

    private var browseTitle: String {
        switch orderedSelection.count {
        case 0: return siteName
        case 1: return orderedSelection[0].name
        default: return "\(orderedSelection.count) selected"
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
                            sources: [BrowseCategory(name: searchText, url: searchURL)]
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
                        CheckboxRow(
                            title: category.name,
                            isOn: selected.contains(category)
                        ) {
                            toggle(category)
                        }
                    }
                }
            }

            ForEach(groupedTags, id: \.0) { groupName, items in
                Section(groupName) {
                    ForEach(items) { tag in
                        CheckboxRow(
                            title: tag.name,
                            isOn: selected.contains(tag)
                        ) {
                            toggle(tag)
                        }
                    }
                }
            }
        }
        .navigationTitle(siteName)
        .searchable(text: $searchText, prompt: "Search \(siteName)")
        .safeAreaInset(edge: .bottom) {
            if !orderedSelection.isEmpty {
                NavigationLink {
                    VideoGridView(
                        siteName: siteName,
                        title: browseTitle,
                        sources: orderedSelection
                    )
                } label: {
                    Text("Browse \(orderedSelection.count) selected")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { selected.removeAll() }
                    .disabled(selected.isEmpty)
            }
        }
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

    private func toggle(_ category: BrowseCategory) {
        if selected.contains(category) {
            selected.remove(category)
        } else {
            selected.insert(category)
        }
    }
}

/// A tappable checkbox row.
struct CheckboxRow: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
