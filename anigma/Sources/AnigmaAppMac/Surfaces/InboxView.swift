//
//  InboxView.swift
//  AnigmaAppMac
//
//  Inbox - triage queue for imported artifacts.
//  Bauhaus style: flatter, sharper, visible structure.
//

import SwiftUI
import AnigmaClientKit
import UniformTypeIdentifiers
import Foundation
import ContractsCore

struct InboxView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Set<ArtifactID> = []
    @State private var isDropTargeted = false
    @StateObject private var pdfImportViewModel = PDFImportViewModel(job: PDFImportJob())

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x3) {
            PDFImportView(viewModel: pdfImportViewModel) { result in
                Task {
                    await handlePDFImportResult(result)
                }
            }
            if store.artifacts.isEmpty {
                InboxEmptyState(isDropTargeted: $isDropTargeted)
            } else {
                InboxContent(selection: $selection)
            }
        }
        .navigationTitle("Inbox")
        .background(Bauhaus.Color.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { // Toolbar ButtonStyle
                    // Logic to manually trigger a sync if needed
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityLabel("Refresh artifacts")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                importFile(url: url)
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay(
            Rectangle()
                .stroke(isDropTargeted ? Bauhaus.Color.accent : Color.clear, lineWidth: 2)
        )
    }

    private func importFile(url: URL) {
        Task {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                store.handleIntake(url: url)
            }
        }
    }

    private func handlePDFImportResult(_ result: OperationResult<PDFImportJob.ImportResult>) async {
        switch result.state {
        case .success:
            if let payload = result.payload {
                await store.uploadArtifact(name: payload.fileName, data: payload.data)
                store.showToast(
                    title: "PDF Imported",
                    subtitle: "\(payload.fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(payload.byteCount), countStyle: .file)))",
                    icon: "checkmark.circle.fill"
                )
            }
        case .failure:
            if let failure = result.failure {
                store.showToast(
                    title: "PDF Import Failed",
                    subtitle: failure.message,
                    icon: "exclamationmark.triangle.fill"
                )
            }
        default:
            break
        }
    }
}

// MARK: - Empty State

struct InboxEmptyState: View {
    @Environment(AppStore.self) private var store
    @Binding var isDropTargeted: Bool

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x4) {
            Spacer()

            VStack(spacing: Bauhaus.Grid.x3) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(Bauhaus.Font.displayXL)
                    .foregroundStyle(isDropTargeted ? Bauhaus.Color.accent : Bauhaus.Color.textTertiary)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Intake queue empty")
                        .font(Bauhaus.Font.header)
                        .accessibilityAddTraits(.isHeader)
                    Text("Use the command bar, drop files, or connect sources to begin.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .accessibilityElement(children: .combine)

                Button("Connect Sources") { // Primary ButtonStyle
                    store.isSourceConnectionPresented = true
                }
                .primaryButtonStyle()
                .accessibilityLabel("Connect Sources")
                .accessibilityHint("Opens the source connection dialog")
                .padding(.top, 8)
            }

            // Capabilities - certainty of use
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                Text("Accepted formats".uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                HStack(spacing: Bauhaus.Grid.unit) {
                    FormatBadge(label: "PDF", icon: "doc.richtext")
                    FormatBadge(label: "Image", icon: "photo")
                    FormatBadge(label: "JSON", icon: "curlybraces")
                    FormatBadge(label: "ZIP", icon: "archivebox")
                }
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )

            Spacer()
        }
        .padding(Bauhaus.Grid.x6)
    }
}

struct FormatBadge: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(Bauhaus.Font.caption)
            Text(label).font(Bauhaus.Font.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Bauhaus.Color.background)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Content

struct InboxContent: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: Set<ArtifactID>

    var body: some View {
        List(selection: $selection) {
            ForEach(store.artifacts, id: \.id) { artifact in
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Bauhaus.Color.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.name).font(Bauhaus.Font.body)
                        Text("Ready for triage").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .tag(artifact.id)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(artifact.name), Ready for triage")
                .accessibilityHint("Select to inspect this artifact")
                .accessibilityAddTraits(.isButton)
            }
        }
        .listStyle(.inset)
        .typeToNavigate(items: store.artifacts, keyPath: \.name, selection: $selection)
        .onChange(of: selection) { _, newValue in
            if let first = newValue.first {
                store.inspectorSelection = .artifact(id: first)
            }
        }
    }
}
