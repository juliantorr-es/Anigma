//
//  DevelopSearchView.swift
//  AnigmaAppMac
//
//  Local repository search with LSP-like features.
//

import SwiftUI
import AnigmaClientKit

struct DevelopSearchView: View {
    let workspace: RepoWorkspace
    @Environment(AppStore.self) private var store
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Bauhaus.Font.body)
                    .accessibilityLabel("Search query")
                    .accessibilityHint("Enter text to search file names")
                    .onChange(of: searchQuery) { _, newValue in
                        performSearch(query: newValue)
                    }

                if isSearching {
                    ProgressView().controlSize(.small)
                        .padding(.trailing, Bauhaus.Grid.unit / 2)
                }
            }
            .padding(Bauhaus.Grid.unit)
            .background(Bauhaus.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.unit / 2)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
            .padding(Bauhaus.Grid.unit)

            // Filters
            HStack(spacing: Bauhaus.Grid.x2) {
                FilterChip(label: "Files", isSelected: true)
                    .accessibilityLabel("Filter by Files")
                    .accessibilityAddTraits(.isSelected)
                FilterChip(label: "Symbols", isSelected: false)
                    .accessibilityLabel("Filter by Symbols")
                FilterChip(label: "Text", isSelected: false)
                    .accessibilityLabel("Filter by Text")
                Spacer()
            }
            .padding(.horizontal, Bauhaus.Grid.unit)
            .padding(.bottom, Bauhaus.Grid.unit)

            Divider()

            if searchQuery.isEmpty {
                VStack(spacing: Bauhaus.Grid.unit) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(Bauhaus.Font.displayM)
                        .foregroundStyle(Bauhaus.Color.borderStrong)
                    Text("Search Workplace")
                        .font(Bauhaus.Font.subHeader)
                    Text("Enter a query to search across the indexed repository.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Bauhaus.Grid.unit)
                    Spacer()
                }
            } else if searchResults.isEmpty && !isSearching {
                VStack(spacing: Bauhaus.Grid.unit) {
                    Spacer()
                    Text("No matches found")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Spacer()
                }
            } else {
                List {
                    Section("Results") {
                        ForEach(searchResults) { result in
                            SearchResultRow(
                                title: result.fileName,
                                subtitle: result.relativePath,
                                icon: result.icon
                            )
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Bauhaus.Color.surface)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // Simple file search implementation
        Task.detached(priority: .userInitiated) {
            let root = workspace.rootURL
            let manager = FileManager.default
            var results: [SearchResult] = []

            // Stack-based iteration to avoid NSEnumerator concurrency issues
            var stack = [root]
            var processedCount = 0

            while !stack.isEmpty && processedCount < 10000 {
                let currentDir = stack.removeLast()
                processedCount += 1

                guard let contents = try? manager.contentsOfDirectory(
                    at: currentDir,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                for url in contents {
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                    if isDirectory {
                        stack.append(url)
                    } else {
                        let fileName = url.lastPathComponent
                        if fileName.localizedCaseInsensitiveContains(query) {
                            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
                            results.append(SearchResult(
                                fileName: fileName,
                                relativePath: relativePath,
                                icon: iconForFile(fileName)
                            ))
                        }
                    }

                    if results.count >= 50 { break }
                }
                if results.count >= 50 { break }
            }

            let finalResults = results
            await MainActor.run {
                self.searchResults = finalResults
                self.isSearching = false
            }
        }
    }
}

// Helper function outside the View struct to avoid isolation issues
private func iconForFile(_ fileName: String) -> String {
    let ext = (fileName as NSString).pathExtension.lowercased()
    switch ext {
    case "swift": return "bird.fill"
    case "md": return "doc.text.fill"
    case "json", "yaml", "yml": return "doc.plaintext.fill"
    case "plist": return "list.bullet.rectangle"
    default: return "doc.text"
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let fileName: String
    let relativePath: String
    let icon: String
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(Bauhaus.Font.microBold)
            .padding(.horizontal, Bauhaus.Grid.unit / 2 + 2)
            .padding(.vertical, Bauhaus.Grid.unit / 2)
            .background(isSelected ? Bauhaus.Color.accent.opacity(0.2) : Bauhaus.Color.surface)
            .foregroundStyle(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: 1)
            )
    }
}

private struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Bauhaus.Color.accent)
                .frame(width: Bauhaus.Grid.x2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Bauhaus.Font.body).fontWeight(.medium)
                Text(subtitle).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
        .padding(.vertical, Bauhaus.Grid.unit / 2)
    }
}
