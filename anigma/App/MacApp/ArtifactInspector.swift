import AnigmaClientKit
import ContractsCore
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let artifactInspectorLogger = Logger(subsystem: "com.anigma.app", category: "artifact-inspector")

struct ArtifactDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.item] }

    var data: Data
    var name: String

    init(data: Data, name: String) {
        self.data = data
        self.name = name
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        name = "Unknown"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ArtifactInspector: View {
    @Environment(AppStore.self) private var store
    let artifactId: String

    private var artifact: AnigmaClientKit.ArtifactSummary? {
        store.artifacts.first { $0.id == artifactId }
    }

    @State private var isExporting: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var downloadData: Data?

    @State private var isEvaluating = false
    @State private var downloadEvaluation: IntentEvaluation = .allowed
    @State private var deleteEvaluation: IntentEvaluation = .allowed

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        if let artifact = artifact {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Artifact", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(artifact.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "ID", value: artifact.id)
                    InfoRow(label: "Type", value: artifact.type)
                    InfoRow(label: "Created", value: Self.relativeDateFormatter.string(from: artifact.createdAt))
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Artifact Metadata")

                Divider()

                // Actions
                VStack(spacing: 8) {
                    Button(action: { isExporting = true }) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(downloadEvaluation != .allowed && !isEvaluating)

                    Button(action: { verifyReceipt() }) {
                        Label("Verify Receipt", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Divider()
                        .padding(.vertical, 4)

                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .disabled(deleteEvaluation != .allowed && !isEvaluating)
                    .confirmationDialog(
                        "Delete Artifact",
                        isPresented: $showingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            Task {
                                await store.deleteArtifact(id: artifact.id)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "Are you sure you want to delete '\(artifact.name)'? This action cannot be undone."
                        )
                    }
                }

                if case .denied(let reason) = downloadEvaluation {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if case .denied(let reason) = deleteEvaluation {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .task(id: artifactId) {
                await evaluateActions()
            }
            .fileExporter(
                isPresented: $isExporting,
                document: ArtifactDocument(data: downloadData ?? Data(), name: artifact.name),
                contentType: .item,
                defaultFilename: artifact.name
            ) { result in
                if case .success = result {
                    artifactInspectorLogger.info("Artifact exported")
                }
            }
            .onChange(of: isExporting) { _, newValue in
                if newValue {
                    Task {
                        downloadData = await store.downloadArtifact(id: artifact.id)
                    }
                }
            }
        } else {
            ContentUnavailableView("Artifact Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    private func evaluateActions() async {
        guard let artifact = artifact else { return }
        isEvaluating = true

        downloadEvaluation = await store.evaluateAction(
            action: "artifact.download",
            parameters: ["artifactId": .string(artifact.id)]
        )

        deleteEvaluation = await store.evaluateAction(
            action: "artifact.delete",
            parameters: ["artifactId": .string(artifact.id)]
        )

        isEvaluating = false
    }

    private func verifyReceipt() {
        store.showToast(
            title: "Verification Not Yet Implemented",
            subtitle: "Artifact receipt verification is under development.",
            icon: "exclamationmark.triangle"
        )
    }
}
