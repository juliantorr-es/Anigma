//
//  DocumentLibraryView.swift
//  AnigmaAppMac
//
//  Document library view with search, filtering, and metadata display.
//

import SwiftUI
import Foundation

struct DocumentLibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDocument: DocumentItem?
    
    var body: some View {
        @Bindable var state = appState
        
        HSplitView {
            DocumentListPane(
                documents: appState.filteredDocuments,
                searchText: $state.documentSearchQuery,
                selection: $selectedDocument,
                isLoading: appState.isLoadingDocuments
            )
            .frame(minWidth: 500)
            
            DocumentDetailPane(document: selectedDocument)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await appState.refreshDocuments() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoadingDocuments)
                
                Menu {
                    Button("Import Document...") {}
                    Button("Create Folder...") {}
                    Divider()
                    Button("Export All...") {}
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationTitle("Document Library")
        .navigationSubtitle("\(appState.filteredDocuments.count) documents")
    }
}

// MARK: - Document List Pane

struct DocumentListPane: View {
    let documents: [DocumentItem]
    @Binding var searchText: String
    @Binding var selection: DocumentItem?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(searchText: $searchText)
            Divider()
            
            if isLoading {
                loadingView
            } else if documents.isEmpty {
                emptyView
            } else {
                documentList
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading documents...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        ContentUnavailableView.search(text: searchText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentList: some View {
        List(documents, selection: $selection) { doc in
            DocumentRow(document: doc)
                .tag(Optional(doc))
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: DocumentItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.fileIcon)
                .foregroundStyle(.blue)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(document.path ?? "No path")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(document.fileType.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                
                Text(document.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search documents...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Document Detail Pane

struct DocumentDetailPane: View {
    let document: DocumentItem?
    
    var body: some View {
        if let doc = document {
            DocumentDetailContent(document: doc)
        } else {
            ContentUnavailableView(
                "No Document Selected",
                systemImage: "doc.text",
                description: Text("Select a document to view its details")
            )
        }
    }
}

struct DocumentDetailContent: View {
    let document: DocumentItem
    @State private var isMetadataExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                metadataSection
                tagsSection
                actionsSection
                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: document.fileIcon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text(document.name)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(document.fileType.uppercased())
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var metadataSection: some View {
        DisclosureGroup("Metadata", isExpanded: $isMetadataExpanded) {
            VStack(spacing: 12) {
                MetadataRow(label: "Path", value: document.path ?? "Unknown")
                MetadataRow(label: "Size", value: document.formattedSize)
                MetadataRow(label: "Modified", value: document.lastModified.formatted(date: .abbreviated, time: .shortened))
                MetadataRow(label: "Type", value: document.fileType.uppercased())
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            WrappingHStack(items: document.tags) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            
            Button {
                // Add tag action
            } label: {
                Label("Add Tag", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                DocumentActionButton(title: "Open in Finder", icon: "folder") {}
                DocumentActionButton(title: "Quick Look", icon: "eye") {}
                DocumentActionButton(title: "Share", icon: "square.and.arrow.up") {}
                Divider()
                DocumentActionButton(title: "Delete", icon: "trash", isDestructive: true) {}
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper Views

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct DocumentActionButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(isDestructive ? .red : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Wrapping HStack

struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
