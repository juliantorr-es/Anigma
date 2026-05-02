//
//  ModelRegistryView.swift
//  AnigmaAppMac
//
//  Model Registry UI - governed ML model management
//

import SwiftUI
import ContractsCore

private func normalizedTrustTier(_ trustTier: String) -> String {
    trustTier
        .lowercased()
        .replacingOccurrences(of: "_", with: "-")
}

private func displayTrustTier(_ trustTier: String) -> String {
    normalizedTrustTier(trustTier)
        .replacingOccurrences(of: "-", with: " ")
        .capitalized
}

// NonPersistent
struct ModelRegistryCardView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var selectedTier: ModelTrustTier?
    @State private var selectedBackend: MLBackend?
    @State private var selectedTask: ModelTaskKind?
    @State private var showingImport = false

    var filteredModels: [ModelRegistryEntry] {
        store.registeredModels.filter { model in
            if !searchText.isEmpty {
                let matches = model.modelId.localizedCaseInsensitiveContains(searchText) ||
                             model.sourceLocation.localizedCaseInsensitiveContains(searchText)
                if !matches { return false }
            }
            // trustTier is now a String, compare with rawValue
            if let tier = selectedTier, model.trustTier != tier.rawValue {
                return false
            }
            if let backend = selectedBackend, model.backendFormat.lowercased() != backend.rawValue.lowercased() {
                return false
            }
            // taskKind is now a String, compare with rawValue
            if let task = selectedTask, model.taskKind != task.rawValue {
                return false
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Model Registry")
                    .font(Bauhaus.Font.header)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    showingImport = true
                } label: {
                    Label("Import Model", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain) // OK: Icon button

                Button {
                    Task {
                        await store.loadRegisteredModels()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(Bauhaus.Grid.x2)

            Divider()

            // Filters
            HStack(spacing: Bauhaus.Grid.unit + 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                Picker("Trust Tier", selection: $selectedTier) {
                    Text("All Tiers").tag(ModelTrustTier?.none)
                    Divider()
                    Text("First Class").tag(ModelTrustTier?.some(.firstClass))
                    Text("Compatible").tag(ModelTrustTier?.some(.compatible))
                    Text("Experimental").tag(ModelTrustTier?.some(.experimental))
                    Text("Quarantined").tag(ModelTrustTier?.some(.quarantined))
                }
                .accessibilityLabel("Filter by Trust Tier")
                .frame(width: 160)

                Picker("Backend", selection: $selectedBackend) {
                    Text("All Backends").tag(MLBackend?.none)
                    Divider()
                    Text("MLX").tag(MLBackend?.some(.mlx))
                    Text("GGUF").tag(MLBackend?.some(.gguf))
                    Text("CoreML").tag(MLBackend?.some(.coreml))
                }
                .accessibilityLabel("Filter by ML Backend")
                .frame(width: 140)

                Picker("Task", selection: $selectedTask) {
                    Text("All Tasks").tag(ModelTaskKind?.none)
                    Divider()
                    Text("Inference").tag(ModelTaskKind?.some(.inference))
                    Text("Embedding").tag(ModelTaskKind?.some(.embedding))
                    Text("Transcription").tag(ModelTaskKind?.some(.transcription))
                    Text("Classification").tag(ModelTaskKind?.some(.classification))
                    Text("Image Gen").tag(ModelTaskKind?.some(.imageGeneration))
                    Text("Speech Synth").tag(ModelTaskKind?.some(.speechSynthesis))
                }
                .accessibilityLabel("Filter by Model Task")
                .frame(width: 140)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    TextField("Search models...", text: $searchText)
                        .accessibilityLabel("Search models by ID or source")
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(.horizontal, Bauhaus.Grid.unit)
                .padding(.vertical, Bauhaus.Grid.unit / 2)
                .background(Bauhaus.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.unit))
            }
            .padding(.horizontal)
            .padding(.vertical, Bauhaus.Grid.unit)

            Divider()

            // Models List
            if filteredModels.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Bauhaus.Grid.unit) {
                        ForEach(filteredModels) { entry in
                            ModelActionRow(entry: entry)
                        }
                    }
                    .padding(Bauhaus.Grid.x2)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            ModelImportCardSheet()
        }
        .task {
            await store.loadRegisteredModels()
        }
    }

    var emptyState: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "cube.transparent")
                .font(Bauhaus.Font.displayXL)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No Models Registered")
                .font(Bauhaus.Font.bodyBold)

            Text("Import models from HuggingFace or local sources")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Button {
                showingImport = true
            } label: {
                Label("Import Your First Model", systemImage: "plus.circle.fill")
            }
            .primaryButtonStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// NonPersistent
struct ModelActionRow: View, Sendable {
    @Environment(AppStore.self) private var store
    let entry: ModelRegistryEntry
    @State private var showingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack(alignment: .top) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)
                    .padding(.top, Bauhaus.Grid.unit)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.modelId)
                            .font(Bauhaus.Font.bodyBold)

                        if entry.isRunnable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Bauhaus.Color.success)
                                .help("Runnable")
                        }

                        Spacer()

                        // Trust tier badge
                        Text(displayTrustTier(entry.trustTier))
                            .font(Bauhaus.Font.micro)
                            .padding(.horizontal, Bauhaus.Grid.unit)
                            .padding(.vertical, Bauhaus.Grid.unit / 4)
                            .background(tierColor.opacity(0.1))
                            .foregroundStyle(tierColor)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: Bauhaus.Grid.unit) {
                        Label(entry.taskKind.capitalized, systemImage: taskIcon)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Label(entry.backendFormat.uppercased(), systemImage: "cpu")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Label(entry.license.declared ?? "unknown", systemImage: licenseIcon)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Text(entry.formattedStorageSize)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                    }

                    Text(entry.sourceLocation)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }

                Spacer()

                // Actions
                HStack(spacing: Bauhaus.Grid.unit) {
                    Button {
                        Task {
                            do {
                                try await store.verifyModelIntegrity(modelId: entry.id)
                            } catch {
                                store.showError("Failed to verify model: \(error.localizedDescription)")
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark.shield")
                    }
                    .help("Verify Integrity")

                    Button {
                        showingDetails = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .help("Details")

                    Button(role: .destructive) {
                        Task {
                            await store.deleteModel(entry.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete model \(entry.modelId)")
                    .help("Delete")
                }
                .buttonStyle(.plain)
            }

            if entry.status == .degraded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Bauhaus.Color.warning)
                    Text("Model files are missing or corrupted")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.warning)
                }
                .padding(.leading, Bauhaus.Grid.x2)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
        .sheet(isPresented: $showingDetails) {
            ModelDetailSheet(entry: entry)
        }
    }

    var statusColor: Color {
        switch entry.status {
        case .ready: return Bauhaus.Color.success
        case .downloading, .verifying, .converting: return Bauhaus.Color.running
        case .degraded: return Bauhaus.Color.warning
        case .quarantined: return Bauhaus.Color.error
        }
    }

    var tierColor: Color {
        // trustTier is now a String, compare string values
        switch normalizedTrustTier(entry.trustTier) {
        case "first-class": return Bauhaus.Color.accent
        case "compatible": return Bauhaus.Color.success
        case "experimental": return Bauhaus.Color.warning
        default: return Bauhaus.Color.textSecondary
        }
    }

    var taskIcon: String {
        // taskKind is now a String, check string values
        if entry.taskKind.contains("inference") { return "text.bubble" }
        if entry.taskKind.contains("embedding") { return "vector.square" }
        if entry.taskKind.contains("transcription") { return "waveform" }
        if entry.taskKind.contains("classification") { return "tag" }
        if entry.taskKind.contains("generation") { return "photo" }
        if entry.taskKind.contains("synthesis") { return "speaker.wave.2" }
        return "gear"
    }

    var licenseIcon: String {
        return "doc.text"
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// NonPersistent
struct ModelDetailSheet: View, Sendable {
    @Environment(\.dismiss) private var dismiss
    let entry: ModelRegistryEntry

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Model Details")
                    .font(Bauhaus.Font.header)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityLabel("Close model details")
            }
            .padding(Bauhaus.Grid.x2)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                    // Identity
                    Group {
                        Text("Identity")
                            .font(Bauhaus.Font.subHeader)

                        LabeledContent("ID", value: entry.modelId)
                        LabeledContent("Source", value: entry.sourceLocation)
                        LabeledContent("Model Hash", value: String(entry.artifactHash.prefix(16)) + "...")
                            .font(Bauhaus.Font.mono)
                    }

                    Divider()

                    // Configuration
                    Group {
                        Text("Configuration")
                            .font(Bauhaus.Font.subHeader)

                        LabeledContent("Task", value: entry.taskKind)
                        LabeledContent("Backend", value: entry.backendFormat)
                        LabeledContent("Trust Tier", value: displayTrustTier(entry.trustTier))
                        LabeledContent("Status", value: entry.status.rawValue)
                    }

                    Divider()

                    // License
                    Group {
                        Text("License")
                            .font(Bauhaus.Font.subHeader)

                        LabeledContent("Declared", value: entry.license.declared ?? "unknown")
                        LabeledContent("Allowed", value: entry.license.allowed ? "Yes" : "No")
                        if let reason = entry.license.reason {
                            LabeledContent("Reason", value: reason)
                        }
                    }

                    Divider()

                    // Artifacts
                    Group {
                        Text("Artifacts")
                            .font(Bauhaus.Font.subHeader)

                        LabeledContent("Model Hash", value: entry.artifactHash)
                            .font(Bauhaus.Font.mono)
                        if let tokHash = entry.tokenizerHash {
                            LabeledContent("Tokenizer Hash", value: tokHash)
                                .font(Bauhaus.Font.mono)
                        }
                        ForEach(Array(entry.artifactHashes.keys.sorted()), id: \.self) { key in
                            if let hash = entry.artifactHashes[key] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(Bauhaus.Font.caption)
                                        .foregroundStyle(Bauhaus.Color.textSecondary)
                                    Text(hash)
                                        .font(Bauhaus.Font.monoMicro)
                                        .foregroundStyle(Bauhaus.Color.textTertiary)
                                }
                            }
                        }
                    }

                    Divider()

                    // Storage
                    Group {
                        Text("Storage")
                            .font(Bauhaus.Font.subHeader)

                        if let path = entry.installPath {
                            LabeledContent("Path", value: path)
                                .font(Bauhaus.Font.monoMicro)
                        }
                        LabeledContent("Size", value: entry.formattedStorageSize)
                        if let dimension = entry.dimension {
                            LabeledContent("Dimension", value: String(dimension))
                        }
                    }

                    Divider()

                    // Metadata
                    Group {
                        Text("Metadata")
                            .font(Bauhaus.Font.subHeader)

                        LabeledContent("Source Type", value: entry.sourceType)
                        if let revision = entry.sourceRevision {
                            LabeledContent("Revision", value: revision)
                        }
                        LabeledContent("Registered", value: entry.registeredAt.formatted())
                        LabeledContent("Last Verified", value: entry.lastVerified.formatted())
                        if let lastUsed = entry.lastUsed {
                            LabeledContent("Last Used", value: lastUsed.formatted())
                        }
                        LabeledContent("Usage Count", value: "\(entry.usageCount)")
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }
        }
        .frame(width: 600, height: 700) // OK: Sheet size
    }
}

// NonPersistent
struct ModelImportCardSheet: View, Sendable {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var repoId = ""
    @State private var revision = "main"
    @State private var importing = false
    @State private var progress: Double = 0
    @State private var descriptor: HFModelDescriptor?
    @State private var describing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Model")
                    .font(Bauhaus.Font.header)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel model import")
            }
            .padding(Bauhaus.Grid.x2)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                    // Source
                    Group {
                        Text("HuggingFace Repository")
                            .font(Bauhaus.Font.subHeader)

                        TextField("Repository (e.g., meta-llama/Llama-3.2-1B)", text: $repoId)
                            .accessibilityLabel("Hugging Face Repository ID")
                            .textFieldStyle(.roundedBorder)
                            .disabled(importing)

                        HStack {
                            TextField("Revision", text: $revision)
                                .accessibilityLabel("Git revision or branch name")
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200) // OK: Fixed field width
                                .disabled(importing)

                            Button {
                                Task {
                                    describing = true
                                    descriptor = await store.describeHuggingFaceModel(repo: repoId, revision: revision)
                                    describing = false
                                }
                            } label: {
                                if describing {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                } else {
                                    Text("Preview")
                                }
                            }
                            .disabled(repoId.isEmpty || importing || describing)
                        }
                    }

                    // Preview
                    if let desc = descriptor {
                        Divider()

                        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                            Text("Model Preview")
                                .font(Bauhaus.Font.subHeader)

                            HStack {
                                Image(systemName: desc.isRunnable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(desc.isRunnable ? Bauhaus.Color.success : Bauhaus.Color.warning)

                                Text(desc.isRunnable ? "Compatible" : "Not Runnable")
                                    .font(Bauhaus.Font.body)
                                    .foregroundStyle(desc.isRunnable ? Bauhaus.Color.success : Bauhaus.Color.warning)
                            }

                            if let task = desc.inferredTask {
                                LabeledContent("Task", value: task.rawValue)
                            }

                            if !desc.compatibleBackends.isEmpty {
                                LabeledContent("Backends", value: desc.compatibleBackends.map { $0.rawValue }.joined(separator: ", "))
                            }

                            if let license = desc.license {
                                LabeledContent("License", value: license)
                            }

                            if let size = desc.estimatedSizeBytes {
                                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }

                            HStack(spacing: Bauhaus.Grid.unit) {
                                if desc.mlx {
                                    Label("MLX", systemImage: "checkmark.circle")
                                        .foregroundStyle(Bauhaus.Color.success)
                                }
                                if desc.gguf {
                                    Label("GGUF", systemImage: "checkmark.circle")
                                        .foregroundStyle(Bauhaus.Color.success)
                                }
                                if desc.safetensors {
                                    Label("SafeTensors", systemImage: "checkmark.circle")
                                        .foregroundStyle(Bauhaus.Color.success)
                                }
                            }
                            .font(Bauhaus.Font.caption)
                        }
                        .padding(Bauhaus.Grid.x2)
                        .background(Bauhaus.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.radius))
                    }

                    // Progress
                    if importing {
                        Divider()

                        VStack(spacing: Bauhaus.Grid.unit) {
                            ProgressView(value: progress)
                            Text("Downloading and verifying... \(Int(progress * 100))%")
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }

                    Spacer()

                    // Actions
                    HStack {
                        Spacer()

                        Button("Import") {
                            Task {
                                importing = true
                                await store.importHuggingFaceModel(repo: repoId, revision: revision) { p in
                                    progress = p
                                }
                                importing = false
                                dismiss()
                            }
                        }
                        .accessibilityLabel("Start model import process")
                        .primaryButtonStyle()
                        .disabled(repoId.isEmpty || importing)
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }
        }
        .frame(width: 600, height: 500) // OK: Sheet size
    }
}
