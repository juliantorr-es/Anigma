//
//  SearchResultsView.swift
//  DevelopumModule
//
//  SwiftUI component for displaying search results from IndexCapsule.
//  Supports file grouping, match highlighting, and click navigation.
//

import SwiftUI
import AnigmaCore

public struct SearchResultItem: Identifiable, Hashable {
    public let id: UUID
    public let result: SearchResult
    public let filePath: String
    public let matchRange: Swift.Range<String.Index>
    
    public init(result: SearchResult) {
        self.id = UUID()
        self.result = result
        self.filePath = result.fileUri.replacingOccurrences(of: "anigma://", with: "")
        if let range = result.lineText.range(of: result.match, options: .caseInsensitive) {
            self.matchRange = range
        } else {
            self.matchRange = result.lineText.startIndex..<result.lineText.startIndex
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SearchResultGroup: Identifiable, Hashable {
    public let id: UUID
    public let filePath: String
    public let items: [SearchResultItem]
    public let matchCount: Int
    
    public init(filePath: String, items: [SearchResultItem]) {
        self.id = UUID()
        self.filePath = filePath
        self.items = items
        self.matchCount = items.count
    }
}

@MainActor
public final class SearchResultsViewModel: ObservableObject {
    @Published private(set) var groups: [SearchResultGroup] = []
    @Published private(set) var isSearching = false
    @Published private(set) var error: String?
    @Published private(set) var totalMatchCount = 0
    @Published var searchQuery = ""
    @Published var searchOptions = SearchOptions()
    
    let repoId: UUID
    let indexCapsule: IndexCapsule
    let onNavigate: (String, Int, Int) -> Void
    
    public var isEmpty: Bool {
        groups.isEmpty && !isSearching && error == nil
    }
    
    public init(
        repoId: UUID,
        indexCapsule: IndexCapsule,
        onNavigate: @escaping (String, Int, Int) -> Void
    ) {
        self.repoId = repoId
        self.indexCapsule = indexCapsule
        self.onNavigate = onNavigate
    }
    
    public func search(query: String, options: SearchOptions = .default) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            groups = []
            totalMatchCount = 0
            searchQuery = query
            searchOptions = options
            return
        }
        
        isSearching = true
        error = nil
        searchQuery = query
        searchOptions = options
        
        do {
            let results = try await indexCapsule.searchFiles(
                repoId: repoId,
                query: query,
                options: options
            )
            
            let grouped = groupResults(results)
            groups = grouped
            totalMatchCount = results.count
            isSearching = false
        } catch {
            self.error = error.localizedDescription
            isSearching = false
        }
    }
    
    public func refresh() async {
        guard !searchQuery.isEmpty else { return }
        await search(query: searchQuery, options: searchOptions)
    }
    
    public func clear() {
        groups = []
        totalMatchCount = 0
        searchQuery = ""
        error = nil
    }
    
    public func navigate(to item: SearchResultItem) {
        onNavigate(item.result.fileUri, item.result.line, item.result.column)
    }
    
    private func groupResults(_ results: [SearchResult]) -> [SearchResultGroup] {
        var groupedDict: [String: [SearchResultItem]] = [:]
        
        for result in results {
            let filePath = result.fileUri.replacingOccurrences(of: "anigma://", with: "")
            let item = SearchResultItem(result: result)
            groupedDict[filePath, default: []].append(item)
        }
        
        return groupedDict
            .map { SearchResultGroup(filePath: $0.key, items: $0.value) }
            .sorted { $0.matchCount > $1.matchCount }
    }
}

public struct SearchResultsView: View {
    @StateObject private var viewModel: SearchResultsViewModel
    @State private var searchText = ""
    @State private var expandedGroups: Set<UUID> = []
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    public init(
        repoId: UUID,
        indexCapsule: IndexCapsule,
        onNavigate: @escaping (String, Int, Int) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: SearchResultsViewModel(
            repoId: repoId,
            indexCapsule: indexCapsule,
            onNavigate: onNavigate
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBarView
            contentView
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            Text("Search Results")
                .font(.system(size: 15, weight: .medium))
            Spacer()
            if viewModel.totalMatchCount > 0 {
                Text("\(viewModel.totalMatchCount) matches")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh results")
            .disabled(viewModel.isSearching || viewModel.searchQuery.isEmpty)
        }
        .padding(.horizontal, gridUnit * 2)
        .padding(.vertical, gridUnit)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            TextField("Search in files...", text: $searchText)
                .font(.system(size: 13))
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await viewModel.search(query: searchText) }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, gridUnit * 2)
        .padding(.vertical, gridUnit)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isSearching {
            VStack(spacing: gridUnit) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Searching...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            VStack(spacing: gridUnit) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.orange)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(gridUnit * 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isEmpty {
            emptyStateView
        } else {
            resultsView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: gridUnit) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Text("No Search Results")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
            Text("Enter a search query above to find matches in your codebase.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, gridUnit * 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.groups) { group in
                    SearchResultGroupView(
                        group: group,
                        isExpanded: expandedGroups.contains(group.id),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedGroups.contains(group.id) {
                                    expandedGroups.remove(group.id)
                                } else {
                                    expandedGroups.insert(group.id)
                                }
                            }
                        },
                        onNavigate: { item in
                            viewModel.navigate(to: item)
                        }
                    )
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct SearchResultGroupView: View {
    let group: SearchResultGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    let onNavigate: (SearchResultItem) -> Void
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHeader
            if isExpanded {
                groupContent
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var groupHeader: some View {
        HStack(spacing: 4) {
            Button {
                onToggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            Image(systemName: FileIconProvider.iconName(for: group.filePath))
                .font(.system(size: 13))
                .foregroundStyle(FileIconProvider.iconColor(for: group.filePath))
                .frame(width: 18, height: 18)
            
            Text(group.filePath)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(group.matchCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
                Text(group.matchCount == 1 ? "match" : "matches")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, gridUnit * 2)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
    
    private var groupContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(group.items) { item in
                SearchResultItemView(item: item, onNavigate: onNavigate)
                    .padding(.leading, gridUnit * 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchResultItemView: View {
    let item: SearchResultItem
    let onNavigate: (SearchResultItem) -> Void
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            lineNumberColumn
            matchColumn
        }
        .padding(.horizontal, gridUnit * 2)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onNavigate(item)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(0.05))
        )
    }
    
    private var lineNumberColumn: some View {
        Text("\(item.result.line)")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.secondary)
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, gridUnit)
    }
    
    private var matchColumn: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(highlightedLineText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private var highlightedLineText: AttributedString {
        var result = AttributedString(item.result.lineText)
        
        if let matchRange = Swift.Range(item.matchRange, in: result) {
            result[matchRange].backgroundColor = Color.accentColor.opacity(0.3)
            result[matchRange].foregroundColor = Color.primary
        }
        
        return result
    }
}

public struct SearchResultsPanel: View {
    @Binding var isVisible: Bool
    @StateObject private var viewModel: SearchResultsViewModel
    @State private var width: CGFloat = 320
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    public init(
        isVisible: Binding<Bool>,
        repoId: UUID,
        indexCapsule: IndexCapsule,
        onNavigate: @escaping (String, Int, Int) -> Void
    ) {
        _isVisible = isVisible
        _viewModel = StateObject(wrappedValue: SearchResultsViewModel(
            repoId: repoId,
            indexCapsule: indexCapsule,
            onNavigate: onNavigate
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            SearchResultsView(
                repoId: viewModel.repoId,
                indexCapsule: viewModel.indexCapsule,
                onNavigate: viewModel.onNavigate
            )
        }
        .frame(width: width)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.12)),
            alignment: .leading
        )
    }
    
    private var panelHeader: some View {
        HStack {
            Image(systemName: "list.bullet")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            Text("Search")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Button {
                withAnimation {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, gridUnit * 2)
        .padding(.vertical, gridUnit)
    }
}

#Preview("Search Results View") {
//    SearchResultsView(
//        repoId: UUID(),
//        indexCapsule: IndexCapsule(
//            databaseService: DevelopumDatabaseService(
//                databaseAuthority: MemoryDatabaseAuthority()
//            )
//        ),
//        onNavigate: { uri, line, column in
//            print("Navigate to: \(uri) at line \(line), column \(column)")
//        }
//    )
//    .frame(width: 320, height: 500)
    Text("Preview Disabled")
}

#Preview("Search Results Panel") {
//    SearchResultsPanel(
//        isVisible: .constant(true),
//        repoId: UUID(),
//        indexCapsule: IndexCapsule(
//            databaseService: DevelopumDatabaseService(
//                databaseAuthority: MemoryDatabaseAuthority()
//            )
//        ),
//        onNavigate: { uri, line, column in
//            print("Navigate to: \(uri) at line \(line), column \(column)")
//        }
//    )
    Text("Preview Disabled")
}
