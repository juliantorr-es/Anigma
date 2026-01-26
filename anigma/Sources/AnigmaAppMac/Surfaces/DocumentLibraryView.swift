import AnigmaClientKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: ArtifactID?
    @State private var isImporting = false

    var body: some View {
        @Bindable var bindableStore = store

        HSplitView {
            DocumentLibraryList(selection: $selection, searchText: $bindableStore.artifactSearchQuery)
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

            DocumentLibraryDetail(artifactId: selection)
                .frame(minWidth: 360)
        }
        .navigationTitle("Document Library")
        .background(Bauhaus.Color.background)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        if let workspaceId = store.selectedWorkspaceID {
                            await store.selectWorkspace(workspaceId)
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.selectedWorkspaceID == nil)

                Button {
                    isImporting = true
                } label: {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }
                .disabled(store.selectedWorkspaceID == nil)
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
                            store.showToast(title: "Upload Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle.fill")
                        }
                    }
                }
            case .failure(let error):
                store.showToast(title: "Upload Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
        }
    }
}

private struct DocumentLibraryList: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: ArtifactID?
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            DocumentLibrarySearchBar(text: $searchText)
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.surface)
                .bauhausSection()

            if store.filteredArtifacts.isEmpty {
                DocumentLibraryEmptyState(searchText: searchText)
            } else {
                List(store.filteredArtifacts, selection: $selection) { artifact in
                    ArtifactRow(artifact: artifact)
                        .tag(artifact.id)
                }
                .listStyle(.inset)
            }
        }
        .background(Bauhaus.Color.background)
    }
}

private struct DocumentLibrarySearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Bauhaus.Color.textTertiary)

            TextField("Search documents...", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Bauhaus.Color.background)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

private struct DocumentLibraryEmptyState: View {
    let searchText: String

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(Bauhaus.Font.displayS)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text(searchText.isEmpty ? "No documents yet" : "No results")
                .font(Bauhaus.Font.header)
            Text(searchText.isEmpty ? "Import artifacts to build your library." : "Try another search.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Bauhaus.Grid.x4)
    }
}

private struct DocumentLibraryDetail: View {
    @Environment(AppStore.self) private var store
    let artifactId: ArtifactID?

    @State private var isExporting = false
    @State private var downloadData: Data?
    @State private var showingDeleteConfirmation = false

    private var artifact: ArtifactSummary? {
        guard let artifactId else { return nil }
        return store.artifacts.first { $0.id == artifactId }
    }

    var body: some View {
        if let artifact {
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                    header(for: artifact)
                    metadata(for: artifact)
                    tags(for: artifact)
                    actions(for: artifact)
                }
                .padding(Bauhaus.Grid.x3)
            }
            .fileExporter(
                isPresented: $isExporting,
                document: ArtifactDocument(data: downloadData ?? Data(), name: artifact.name),
                contentType: .item,
                defaultFilename: artifact.name
            ) { _ in }
            .onChange(of: isExporting) { _, newValue in
                if newValue {
                    Task {
                        downloadData = await store.downloadArtifact(id: artifact.id)
                    }
                }
            }
        } else {
            DocumentLibraryDetailEmptyState()
        }
    }

    private func header(for artifact: ArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack(spacing: 12) {
                DocumentIconView(name: artifact.name)
                VStack(alignment: .leading, spacing: 4) {
                    Text(artifact.name)
                        .font(Bauhaus.Font.header)
                    Text(artifact.type.uppercased())
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                Spacer()
            }
        }
        .bauhausCard()
    }

    private func metadata(for artifact: ArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Metadata")
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            DocumentMetadataRow(label: "ID", value: artifact.id)
            DocumentMetadataRow(label: "Type", value: artifact.type.uppercased())
            DocumentMetadataRow(label: "Created", value: artifact.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .bauhausCard()
    }

    private func tags(for artifact: ArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Tags")
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            WrappingTagStack(tags: documentTags(for: artifact))
        }
        .bauhausCard()
    }

    private func actions(for artifact: ArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Actions")
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Button {
                isExporting = true
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .primaryButtonStyle()

            Button {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Bauhaus.Color.error)
            .confirmationDialog("Delete Artifact", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await store.deleteArtifact(id: artifact.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(artifact.name)'?")
            }
        }
        .bauhausCard()
    }

    private func documentTags(for artifact: ArtifactSummary) -> [String] {
        let extensionTag = URL(fileURLWithPath: artifact.name).pathExtension
        var tags = [artifact.type.uppercased()]
        if !extensionTag.isEmpty && extensionTag.uppercased() != artifact.type.uppercased() {
            tags.append(extensionTag.uppercased())
        }
        return tags
    }
}

private struct DocumentLibraryDetailEmptyState: View {
    var body: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "doc.text")
                .font(Bauhaus.Font.displayS)
                .foregroundStyle(Bauhaus.Color.textTertiary)
            Text("Select a document")
                .font(Bauhaus.Font.header)
            Text("Choose a document from the library to inspect details.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Bauhaus.Grid.x4)
    }
}

private struct DocumentMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

private struct DocumentIconView: View {
    let name: String

    var body: some View {
        Image(systemName: iconName)
            .font(Bauhaus.Font.icon)
            .foregroundStyle(Bauhaus.Color.accent)
            .frame(width: 40, height: 40)
            .background(Bauhaus.Color.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                    .stroke(Bauhaus.Color.accent.opacity(0.2), lineWidth: 0.5)
            )
    }

    private var iconName: String {
        let lowercased = name.lowercased()
        if lowercased.hasSuffix(".pdf") { return "doc.richtext" }
        if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpeg") { return "photo" }
        if lowercased.hasSuffix(".json") || lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml") { return "doc.plaintext" }
        return "doc.text"
    }
}

private struct WrappingTagStack: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(Bauhaus.Font.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.accent.opacity(0.12))
                    .foregroundStyle(Bauhaus.Color.accent)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    DocumentLibraryView()
        .environment(AppStore())
        .frame(width: 900, height: 600)
}
