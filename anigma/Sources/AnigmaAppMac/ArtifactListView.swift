//
//  ArtifactListView.swift
//  AnigmaAppMac
//
//  List of artifacts in the current workspace.
//

import AnigmaClientKit
import SwiftUI

struct ArtifactListView: View {
    @Environment(AppStore.self) private var store

    @State private var isImporting: Bool = false
    @State private var selection: Set<AnigmaClientKit.ArtifactID> = []

    var body: some View {
        @Bindable var bindableStore = store
        
        mainContent
            .searchable(text: $bindableStore.artifactSearchQuery, prompt: "Search artifacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    toolbarButtons
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if store.artifacts.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .onChange(of: selection) { _, newSelection in
            if newSelection.count == 1, let id = newSelection.first {
                store.inspectorSelection = .artifact(id: id)
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Artifacts", systemImage: "doc.text")
        } description: {
            Text("Artifacts will appear here when created")
        } actions: {
            Button("Upload Artifact") {
                isImporting = true
            }
        }
    }

    private var listView: some View {
        List(store.filteredArtifacts, selection: $selection) { artifact in
            ArtifactRow(artifact: artifact)
                .tag(artifact.id)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Artifact: \(artifact.name)")
                .accessibilityHint("Double tap to view details")
                .onAppear {
                    if artifact.id == store.filteredArtifacts.last?.id
                        && store.hasMoreArtifacts {
                        Task { await store.loadMoreArtifacts() }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var toolbarButtons: some View {
        HStack {
            if !selection.isEmpty {
                Button(role: .destructive) {
                    Task {
                        for id in selection {
                            await store.deleteArtifact(id: id)
                        }
                        selection.removeAll()
                    }
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
            }

            Button(action: { isImporting = true }) {
                Label("Upload", systemImage: "square.and.arrow.up")
            }
            .disabled(store.selectedWorkspaceID == nil)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        await store.uploadArtifact(name: url.lastPathComponent, data: data)
                    } catch {
                        print("Error reading file: \(error)")
                    }
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
    }
}

struct ArtifactRow: View {
    @Environment(AppStore.self) private var store
    let artifact: AnigmaClientKit.ArtifactSummary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: artifactIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Bauhaus.Color.accent)
            }
            .frame(width: 32, height: 32)
            .background(Bauhaus.Color.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Bauhaus.Color.accent.opacity(0.2), lineWidth: 0.5)
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HighlightableText(text: artifact.name, highlight: store.artifactSearchQuery)
                    .font(Bauhaus.Font.bodyBold)

                Text(artifact.type.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }

            Spacer()

            Text(artifact.createdAt.formatted(.relative(presentation: .numeric)))
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Bauhaus.Color.accent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = inside
            }
        }
    }

    @State private var isHovered = false

    private var artifactIcon: String {
        let name = artifact.name.lowercased()
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".jpg") || name.hasSuffix(".png") || name.hasSuffix(".jpeg") { return "photo" }
        if name.hasSuffix(".json") || name.hasSuffix(".yaml") || name.hasSuffix(".yml") { return "doc.plaintext" }
        return "doc.text"
    }
}
