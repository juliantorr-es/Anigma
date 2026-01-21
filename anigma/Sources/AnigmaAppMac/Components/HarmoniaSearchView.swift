//
//  HarmoniaSearchView.swift
//  AnigmaAppMac
//
//  Search interface for the Harmonia ledger.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct HarmoniaSearchView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var query: String = ""
    @State private var limit: Int = 10
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedResult: HarmoniaClient.SearchResult?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            searchBarView

            if let results = store.searchResults {
                resultsView(results)
            } else if isSearching {
                loadingView
            } else if !query.isEmpty {
                emptyStateView
            } else {
                instructionsView
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Ledger Search")
                .font(Bauhaus.Font.header)

            Spacer()
        }
    }

    private var searchBarView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack(spacing: Bauhaus.Grid.x2) {
                TextField("Search ledger...", text: $query)
                    .accessibilityLabel("Search query")
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await performSearch() }
                    }

                Stepper("Limit: \(limit)", value: $limit, in: 1...100, step: 10)
                    .labelsHidden()
                    .frame(width: 100) // OK: Fixed stepper width

                Button(action: { Task { await performSearch() } }) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Execute search")
                .primaryButtonStyle()
                .disabled(query.isEmpty || isSearching)

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: Bauhaus.Grid.x2) {
                Text("Limit:")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                Text("\(limit) results")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                Spacer()

                if let results = store.searchResults {
                    Text("\(results.totalMatches) total matches")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
        }
    }

    private func resultsView(_ response: HarmoniaClient.SearchResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text("Results")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                Text("\(response.results.count) of \(response.totalMatches)")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            ScrollView {
                VStack(spacing: Bauhaus.Grid.x2) {
                    ForEach(response.results, id: \.id) { result in
                        resultRow(result)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedResult = result
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("View details for \(result.id)")
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    private func resultRow(_ result: HarmoniaClient.SearchResult) -> some View {
        let isSelected = selectedResult?.id == result.id

        return VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: typeIcon(result.type))
                    .foregroundStyle(typeColor(result.type)) // OK: Bauhaus
                    .frame(width: Bauhaus.Grid.x3)

                Text(result.type)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                Spacer()

                relevanceBadge(result.relevance)

                Text(formatDate(result.timestamp))
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }

            Text(result.preview)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .lineLimit(2)

            Text("ID: \(result.id)")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Bauhaus.Grid.x2)
        .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                .stroke(isSelected ? Bauhaus.Color.accent : Color.clear, lineWidth: 1)
        )
    }

    private func relevanceBadge(_ relevance: Double) -> some View {
        let percentage = Int(relevance * 100)
        let color = relevanceColor(relevance) // OK: Bauhaus

        return Text("\(percentage)%")
            .font(Bauhaus.Font.caption)
            .foregroundStyle(color)
            .padding(.horizontal, Bauhaus.Grid.unit)
            .padding(.vertical, Bauhaus.Grid.unit / 2)
            .background(color.opacity(0.1))
            .cornerRadius(Bauhaus.Grid.unit / 2)
    }

    private var loadingView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
                .controlSize(.small)

            Text("Searching...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No results found")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("Try a different search query")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Search Tips")
                .font(Bauhaus.Font.subHeader)

            tipRow(icon: "text.magnifyingglass", text: "Enter keywords to search across all ledger entries")
            tipRow(icon: "slider.horizontal.3", text: "Adjust limit to control number of results")
            tipRow(icon: "star.fill", text: "Higher relevance scores indicate better matches")
            tipRow(icon: "calendar", text: "Results are sorted by relevance")
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: icon)
                .foregroundStyle(Bauhaus.Color.accent)
                .frame(width: Bauhaus.Grid.x3)

            Text(text)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.error)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.error.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func performSearch() async {
        guard !query.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        await store.searchLedger(query: query, limit: limit)

        if store.searchResults == nil {
            errorMessage = "Search failed. Please try again."
        }

        isSearching = false
    }

    // MARK: - Helpers

    private func typeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "job": return "briefcase.fill"
        case "artifact": return "doc.fill"
        case "workspace": return "folder.fill"
        case "event": return "bell.fill"
        case "receipt": return "checkmark.seal.fill"
        default: return "doc.text.fill"
        }
    }

    private func typeColor(_ type: String) -> Color { // OK: Bauhaus
        switch type.lowercased() {
        case "job": return Bauhaus.Color.accent
        case "artifact": return Bauhaus.Color.success
        case "workspace": return Bauhaus.Color.warning
        case "event": return Bauhaus.Color.running
        case "receipt": return Bauhaus.Color.accentHighContrast
        default: return Bauhaus.Color.textSecondary
        }
    }

    private func relevanceColor(_ relevance: Double) -> Color { // OK: Bauhaus
        if relevance >= 0.8 {
            return Bauhaus.Color.success
        } else if relevance >= 0.5 {
            return Bauhaus.Color.warning
        } else {
            return Bauhaus.Color.textTertiary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
