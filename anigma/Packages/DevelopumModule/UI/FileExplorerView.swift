//
//  FileExplorerView.swift
//  DevelopumModule
//
//  SwiftUI component for repository file tree navigation.
//  Supports expand/collapse, file filtering, and Monaco editor integration.
//

import SwiftUI
import AnigmaCore

public struct FileItem: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var isExpanded: Bool
    public var children: [FileItem]
    public var hasUnsavedChanges: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        isExpanded: Bool = false,
        children: [FileItem] = [],
        hasUnsavedChanges: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.children = children
        self.hasUnsavedChanges = hasUnsavedChanges
    }
    
    public var fileUri: String {
        "anigma://\(path)"
    }
    
    public var languageId: String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py", "pyw": return "python"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "cs": return "csharp"
        case "rb", "erb": return "ruby"
        case "php": return "php"
        case "scala": return "scala"
        case "html", "htm": return "html"
        case "css", "scss", "sass", "less": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "md", "markdown": return "markdown"
        case "txt": return "plaintext"
        case "sh", "bash", "zsh": return "shell"
        case "dockerfile": return "dockerfile"
        default: return "plaintext"
        }
    }
}

@MainActor
public final class FileExplorerViewModel: ObservableObject {
    @Published private(set) var rootItem: FileItem?
    @Published private(set) var visibleItems: [FileItem] = []
    @Published private(set) var selectedItem: FileItem?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    private let repoPath: String
    private let databaseService: DevelopumDatabaseService
    private let onFileSelected: (FileItem) -> Void
    private var allItems: [FileItem] = []
    private var expandedPaths: Set<String> = []
    
    public var rootFolderName: String {
        (repoPath as NSString).lastPathComponent
    }
    
    public init(
        repoPath: String,
        databaseService: DevelopumDatabaseService,
        onFileSelected: @escaping (FileItem) -> Void
    ) {
        self.repoPath = repoPath
        self.databaseService = databaseService
        self.onFileSelected = onFileSelected
    }
    
    public func loadFiles() async {
        isLoading = true
        error = nil
        
        do {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: repoPath) else {
                error = "Repository path not found: \(repoPath)"
                isLoading = false
                return
            }
            
            let rootName = (repoPath as NSString).lastPathComponent
            rootItem = FileItem(
                name: rootName,
                path: repoPath,
                isDirectory: true
            )
            
            await buildFileTree()
            isLoading = false
        }
    }
    
    public func refresh() async {
        await loadFiles()
    }
    
    public func toggle(item: FileItem) {
        func toggleInTree(_ node: FileItem) -> FileItem {
            if node.id == item.id {
                var updated = node
                updated.isExpanded.toggle()
                return updated
            } else if !node.children.isEmpty {
                var updated = node
                updated.children = node.children.map { toggleInTree($0) }
                return updated
            }
            return node
        }
        
        if let root = rootItem {
            rootItem = toggleInTree(root)
            if item.isExpanded {
                expandedPaths.insert(item.path)
            } else {
                expandedPaths.remove(item.path)
            }
            updateVisibleItems()
        }
    }
    
    public func select(item: FileItem) {
        selectedItem = item
        onFileSelected(item)
    }
    
    public func filterFiles(query: String) {
        guard !query.isEmpty else {
            visibleItems = allItems
            return
        }
        
        let filtered = allItems.filter { item in
            item.name.lowercased().contains(query.lowercased())
        }
        visibleItems = filtered
    }
    
    public func clearFilter() {
        visibleItems = allItems
    }
    
    public func openFile(item: FileItem) {
        guard !item.isDirectory else { return }
        select(item: item)
    }
    
    public func openFileInNewTab(item: FileItem) {
        guard !item.isDirectory else { return }
        onFileSelected(item)
    }
    
    public func copyPath(item: FileItem) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
        #endif
    }
    
    public func revealInFinder(item: FileItem) {
        #if canImport(AppKit)
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
        #endif
    }
    
    private func buildFileTree() async {
        let fileManager = FileManager.default
        var root = FileItem(
            name: (repoPath as NSString).lastPathComponent,
            path: repoPath,
            isDirectory: true,
            isExpanded: true
        )
        
        root.children = buildChildren(
            for: repoPath,
            parentPath: repoPath,
            fileManager: fileManager
        )
        
        rootItem = root
        updateVisibleItems()
    }
    
    private func buildChildren(for path: String, parentPath: String, fileManager: FileManager) -> [FileItem] {
        var items: [FileItem] = []
        
        do {
            let directoryURL = URL(fileURLWithPath: path)
            let contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let sortedContents = contents.sorted { lhs, rhs in
                let lhsIsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rhsIsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if lhsIsDir != rhsIsDir {
                    return lhsIsDir
                }
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
            
            for url in sortedContents {
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let relativePath = url.path.replacingOccurrences(of: parentPath + "/", with: "")
                
                let item = FileItem(
                    name: url.lastPathComponent,
                    path: relativePath,
                    isDirectory: isDirectory,
                    isExpanded: isDirectory && expandedPaths.contains(url.path),
                    children: isDirectory ? buildChildren(for: url.path, parentPath: parentPath, fileManager: fileManager) : []
                )
                items.append(item)
            }
        } catch {
            self.error = "Failed to read directory: \(error.localizedDescription)"
        }
        
        return items
    }
    
    private func updateVisibleItems() {
        guard let root = rootItem else { return }
        
        func collectVisible(_ node: FileItem, depth: Int) -> [FileItem] {
            var result: [FileItem] = []
            result.append(node)
            
            if node.isExpanded && !node.children.isEmpty {
                for child in node.children {
                    result.append(contentsOf: collectVisible(child, depth: depth + 1))
                }
            }
            
            return result
        }
        
        visibleItems = collectVisible(root, depth: 0)
        allItems = visibleItems
    }
}

public struct FileExplorerView: View {
    @StateObject private var viewModel: FileExplorerViewModel
    @State private var searchText = ""
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    public init(
        repoPath: String,
        databaseService: DevelopumDatabaseService,
        onFileSelected: @escaping (FileItem) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: FileExplorerViewModel(
            repoPath: repoPath,
            databaseService: databaseService,
            onFileSelected: onFileSelected
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBarView
            contentView
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            await viewModel.loadFiles()
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            Text(viewModel.rootFolderName)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh")
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            TextField("Search files", text: $searchText)
                .font(.system(size: 13))
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    viewModel.filterFiles(query: newValue)
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.clearFilter()
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
        if viewModel.isLoading {
            VStack(spacing: gridUnit) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading files...")
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
        } else {
            fileTreeView
        }
    }
    
    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(viewModel.visibleItems) { item in
                    FileTreeItemView(
                        item: item,
                        depth: 0,
                        isSelected: viewModel.selectedItem?.id == item.id,
                        onToggle: { viewModel.toggle(item: item) },
                        onSelect: { viewModel.select(item: item) }
                    )
                    .contextMenu {
                        FileContextMenu(
                            item: item,
                            onOpen: { viewModel.openFile(item: item) },
                            onOpenInNewTab: { viewModel.openFileInNewTab(item: item) },
                            onCopyPath: { viewModel.copyPath(item: item) },
                            onRevealInFinder: { viewModel.revealInFinder(item: item) }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct FileTreeItemView: View {
    let item: FileItem
    let depth: Int
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    
    private let gridUnit: CGFloat = 8
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        HStack(spacing: 4) {
            Button {
                if item.isDirectory {
                    onToggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .rotationEffect(.degrees(item.isExpanded ? 90 : 0))
                    .frame(width: 16, height: 16)
                    .opacity(item.isDirectory ? 1 : 0)
            }
            .buttonStyle(.plain)
            
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .frame(width: 18, height: 18)
            
            Text(item.name)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            
            Spacer()
            
            if item.hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.leading, CGFloat(depth * 16 + 8))
        .padding(.vertical, 4)
        .padding(.trailing, gridUnit * 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
            if item.isDirectory {
                onToggle()
            } else {
                onSelect()
            }
        }
    }
    
    private var iconName: String {
        if item.isDirectory {
            return item.isExpanded ? "folder.open" : "folder"
        }
        return FileIconProvider.iconName(for: item.path)
    }
    
    private var iconColor: Color {
        if item.isDirectory {
            return .yellow.opacity(0.8)
        }
        return FileIconProvider.iconColor(for: item.path)
    }
}

struct FileContextMenu: View {
    let item: FileItem
    let onOpen: () -> Void
    let onOpenInNewTab: () -> Void
    let onCopyPath: () -> Void
    let onRevealInFinder: () -> Void
    
    var body: some View {
        Group {
            if !item.isDirectory {
                Button(action: onOpen) {
                    Label("Open", systemImage: "doc.text")
                }
                
                Button(action: onOpenInNewTab) {
                    Label("Open in New Tab", systemImage: "doc.badge.plus")
                }
                
                Divider()
            }
            
            Button(action: onCopyPath) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            
            Button(action: onRevealInFinder) {
                Label("Reveal in Finder", systemImage: "finder")
            }
        }
    }
}

public struct FileIconProvider {
    public static func iconName(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py", "pyw": return "chevron.left.forwardslash.chevron.right"
        case "js", "jsx", "mjs": return "p.circle"
        case "ts", "tsx": return "t.square"
        case "java": return "cup.and.saucer"
        case "kt", "kts": return "k.circle"
        case "go": return "g.circle"
        case "rs": return "r.circle"
        case "c", "h", "cpp", "cc", "cxx", "hpp": return "c.circle"
        case "cs": return "c.square"
        case "rb", "erb": return "diamond"
        case "php": return "p.circle.fill"
        case "scala": return "s.circle"
        case "html", "htm": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "sass", "less": return "paintbrush"
        case "json": return "curlybraces"
        case "yaml", "yml": return "text.alignleft"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        case "md", "markdown": return "doc.text"
        case "txt": return "doc.plaintext"
        case "sh", "bash", "zsh": return "terminal"
        case "dockerfile": return "shippingbox"
        case "gitignore", "gitattributes": return "chevron.left.forwardslash.chevron.right"
        case "plist": return "list.bullet"
        case "sqlite", "db": return "cylinder"
        case "png", "jpg", "jpeg", "gif", "bmp", "svg", "webp": return "photo"
        case "mp3", "wav", "ogg", "m4a": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "pdf": return "doc.fill"
        case "zip", "tar", "gz", "bz2", "xz": return "doc.zipper"
        case "env": return "lock.shield"
        case "toml", "ini", "cfg", "conf": return "gearshape"
        default: return "doc"
        }
    }
    
    public static func iconColor(for path: String) -> Color {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "py", "pyw": return .blue
        case "js", "jsx", "mjs": return .yellow
        case "ts", "tsx": return .blue
        case "java": return .red
        case "kt", "kts": return .purple
        case "go": return .cyan
        case "rs": return .orange
        case "c", "h", "cpp", "cc", "cxx", "hpp": return .blue
        case "cs": return .green
        case "rb", "erb": return .red
        case "php": return .purple
        case "scala": return .teal
        case "html", "htm": return .orange
        case "css", "scss", "sass", "less": return .pink
        case "json": return .gray
        case "yaml", "yml": return .red
        case "md", "markdown": return .blue
        case "txt": return .gray
        case "sh", "bash", "zsh": return .gray
        case "dockerfile": return .blue
        case "png", "jpg", "jpeg", "gif", "bmp", "svg", "webp": return .purple
        case "pdf": return .red
        default: return .gray
        }
    }
}

#Preview {
//    FileExplorerView(
//        repoPath: "/Users/user/Developer/GitHub/Anigma",
//        databaseService: DevelopumDatabaseService(databaseAuthority: MemoryDatabaseAuthority()),
//        onFileSelected: { item in
//            print("Selected: \(item.path)")
//        }
//    )
//    .frame(width: 280, height: 500)
    EmptyView()
}
