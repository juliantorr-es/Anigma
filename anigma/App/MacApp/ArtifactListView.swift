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

        Group {
            if store.artifacts.isEmpty {
                ContentUnavailableView {
                    Label("No Artifacts", systemImage: "doc.text")
                } description: {
                    Text("Artifacts will appear here when created")
                } actions: {
                    Button("Upload Artifact") {
                        isImporting = true
                    }
                }
            } else {
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
        }
        .onChange(of: selection) { _, newSelection in
            if newSelection.count == 1, let id = newSelection.first {
                store.inspectorSelection = .artifact(id: id)
            }
        }
        .searchable(text: $bindableStore.artifactSearchQuery, prompt: "Search artifacts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
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
}

struct ArtifactRow: View {
    @Environment(AppStore.self) private var store
    let artifact: AnigmaClientKit.ArtifactSummary

    var body: some View {
        HStack {
            Image(systemName: artifactIcon)
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HighlightableText(text: artifact.name, highlight: store.artifactSearchQuery)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(artifact.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(artifact.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = inside
            }
        }
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
