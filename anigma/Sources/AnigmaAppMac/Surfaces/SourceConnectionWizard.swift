//
//  SourceConnectionWizard.swift
//  AnigmaAppMac
//
//  Wizard for adding a new source connection.
//  Steps: Type Selection -> Scope Config -> Depth/Policy -> Active Ingestion
//

import SwiftUI
import Combine
import ContractsCore

struct SourceConnectionWizard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum ConnectionStep {
        case typeSelection
        case scopeConfig
        case depthConfig
        case policyConfig
        case active
        case dashboard // Not used in wizard, but kept for enum compatibility if needed
    }

    @State private var step: ConnectionStep = .typeSelection
    @State private var selectedType: SourceType?
    @State private var source = AnigmaSource()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Connect Source")
                    .font(Bauhaus.Font.header)
                Spacer()
                Button(action: { dismiss() }) { // plain ButtonStyle
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Bauhaus.Grid.x4) {
                    switch step {
                    case .typeSelection:
                        TypeSelectionView(step: $step, selectedType: $selectedType, source: $source)
                    case .scopeConfig:
                        ScopeConfigView(step: $step, source: $source)
                    case .depthConfig:
                        DepthConfigView(step: $step, source: $source, stats: nil)
                    case .policyConfig:
                        PolicyConfigView(step: $step, source: $source)
                    case .active:
                        ActiveIngestionView(step: $step, source: source)
                    case .dashboard:
                        Text("Done") // Should dismiss
                            .onAppear { dismiss() }
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
        .frame(width: 600, height: 700) // OK: Fixed wizard size
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Type Selection

private struct TypeSelectionView: View {
    @Binding var step: SourceConnectionWizard.ConnectionStep
    @Binding var selectedType: SourceType?
    @Binding var source: AnigmaSource

    // Show all available types, or a curated list that includes more than just the basics
    let types: [SourceType] = SourceType.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            Text("Where is the data?").font(Bauhaus.Font.header)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Bauhaus.Grid.x2)], spacing: Bauhaus.Grid.x2) {
                    ForEach(types, id: \.self) { type in
                    Button(action: { // bauhausCard ButtonStyle
                        selectedType = type
                        source.type = type
                        step = .scopeConfig
                    }) {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Image(systemName: type.icon)
                                .font(Bauhaus.Font.displayS)
                                .foregroundStyle(Bauhaus.Color.accent)
                            Text(type.rawValue)
                                .font(Bauhaus.Font.subHeader)
                            Text(type.description)
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .bauhausCard(selected: selectedType == type)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Connect to \(type.rawValue)")
                    .accessibilityHint(type.description)
                }
            }
            .padding(.bottom, Bauhaus.Grid.x2)
            }
        }
    }
}

// MARK: - Scope Configuration

private struct ScopeConfigView: View {
    @Binding var step: SourceConnectionWizard.ConnectionStep
    @Binding var source: AnigmaSource

    @State private var isFileImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            Text("Define Scope").font(Bauhaus.Font.header)

            VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                Text("Target Location").font(Bauhaus.Font.subHeader)

                HStack {
                    Image(systemName: source.type.icon)
                    Text(source.type.rawValue).font(Bauhaus.Font.bodyBold)
                    Spacer()
                    Button("Change Type") { step = .typeSelection } // link ButtonStyle
                        .buttonStyle(.link)
                        .accessibilityLabel("Change source type")
                }
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.surface)
                .cornerRadius(Bauhaus.Grid.cornerRadius)

                if source.type == .filesystem {
                    Button(action: { // plain ButtonStyle
                        isFileImporterPresented = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text(source.path.isEmpty ? "Select Folder..." : source.path)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Bauhaus.Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(Bauhaus.Color.textTertiary)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(source.path.isEmpty ? "Select folder" : "Change folder: \(source.path)")
                    .accessibilityHint("Opens file picker to select a folder")
                    .fileImporter(
                        isPresented: $isFileImporterPresented,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                // In a sandboxed app, we MUST start accessing the security scoped resource.
                                // For now, we just take the path, but in production we'd save a bookmark.
                                _ = url.startAccessingSecurityScopedResource()
                                source.path = url.path
                                source.name = url.lastPathComponent
                                // We don't stop accessing immediately if we want to read it later, 
                                // but we should handle this properly in a real data layer.
                            }
                        case .failure(let error):
                            print("File selection failed: \(error.localizedDescription)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Name").font(Bauhaus.Font.caption)
                    TextField("e.g. Housing Documents", text: $source.name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Source name")
                        .accessibilityHint("Enter a descriptive name for this source")
                }
                .padding(.top, Bauhaus.Grid.x2)

                Spacer()

                Button("Looks Useful, Proceed") { // primaryButtonStyle
                    step = .depthConfig
                }
                .primaryButtonStyle()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Proceed to depth configuration")
            }
        }
    }
}

// MARK: - Depth Configuration

private struct DepthConfigView: View {
    @Binding var step: SourceConnectionWizard.ConnectionStep
    @Binding var source: AnigmaSource
    let stats: SourceStats?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            Text("Indexing Depth").font(Bauhaus.Font.header)

            ForEach(IndexingDepth.allCases, id: \.self) { depth in
                Button(action: { source.depth = depth }) { // bauhausCard ButtonStyle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(depth.rawValue).font(Bauhaus.Font.subHeader)
                            Text(depth.description).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        Spacer()
                        if source.depth == depth {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Bauhaus.Color.accent)
                        }
                    }
                    .bauhausCard(selected: source.depth == depth)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(depth.rawValue) indexing depth")
                .accessibilityHint(depth.description)
                .accessibilityAddTraits(source.depth == depth ? [.isSelected] : [])
            }

            if let s = stats {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED IMPACT").font(Bauhaus.Font.monoBold).foregroundStyle(Bauhaus.Color.textTertiary)
                    Text("Time: ~\(s.durationEstimateMinutes) minutes (Local CPU)")
                    Text("Storage: ~240 MB derived data")
                    Text("No data will leave this machine.")
                }
                .font(Bauhaus.Font.caption)
                .padding(Bauhaus.Grid.x3)
                .background(Bauhaus.Color.accent.opacity(0.05))
                .cornerRadius(Bauhaus.Grid.cornerRadius)
            }

            Spacer()

            Button("Next: Policies") { // primaryButtonStyle
                step = .policyConfig
            }
            .primaryButtonStyle()
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Proceed to policy configuration")
        }
    }
}

// MARK: - Policy Configuration

private struct PolicyConfigView: View {
    @Environment(AppStore.self) private var store
    @Binding var step: SourceConnectionWizard.ConnectionStep
    @Binding var source: AnigmaSource

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            Text("Governance Policies").font(Bauhaus.Font.header)

            SectionView(title: "COMPUTE BUDGET") {
                Toggle("Digest only when plugged into power", isOn: $source.computePolicy.allowOnBattery.inverted)
                    .accessibilityLabel("Require power connection")
                    .accessibilityHint("Only process files when connected to power")
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU Throttle: \(Int(source.computePolicy.cpuThrottle * 100))%")
                        .font(Bauhaus.Font.caption)
                    Slider(value: $source.computePolicy.cpuThrottle, in: 0.1...1.0)
                        .accessibilityLabel("CPU throttle")
                        .accessibilityValue("\(Int(source.computePolicy.cpuThrottle * 100)) percent")
                }
                Picker("Schedule", selection: $source.computePolicy.schedule) {
                    Text("Always").tag("Always")
                    Text("Overnight Only").tag("Overnight")
                    Text("When Idle").tag("When Idle")
                }
                .accessibilityLabel("Processing schedule")
                .accessibilityHint("Choose when to process files")
            }

            SectionView(title: "EXCLUSIONS") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exclude Patterns (Glob)").font(Bauhaus.Font.caption)
                    TextField("e.g. **/node_modules/**, **/.git/**", text: $source.storagePolicy.excludePatterns)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Exclude patterns")
                        .accessibilityHint("Enter glob patterns for files to exclude")

                    Text("Sensitive Paths (No Content)").font(Bauhaus.Font.caption)
                    TextField("e.g. **/secrets/**", text: $source.storagePolicy.sensitivePaths)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Sensitive paths")
                        .accessibilityHint("Enter paths containing sensitive data")
                }
            }

            SectionView(title: "RETENTION") {
                Toggle("Store extracted text locally", isOn: $source.storagePolicy.storeExtractedText)
                    .accessibilityLabel("Store extracted text")
                Toggle("Store embeddings (for search/atlas)", isOn: $source.storagePolicy.storeEmbeddings)
                    .accessibilityLabel("Store embeddings")
                    .accessibilityHint("Required for search and atlas features")
                HStack {
                    Text("Purge derived data after")
                    Spacer()
                    Text("Never").foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .font(Bauhaus.Font.caption)
            }

            Spacer()

            Button("Start Digestion") { // primaryButtonStyle
                step = .active
                Task { await store.submitJob(action: "source_ingest", parameters: ["name": .string(source.name)]) }
            }
            .primaryButtonStyle()
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Start processing source")
            .accessibilityHint("Begins indexing and analyzing the selected source")
        }
    }
}

private struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text(title).font(Bauhaus.Font.monoBold).foregroundStyle(Bauhaus.Color.textTertiary)
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                content
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .cornerRadius(Bauhaus.Grid.cornerRadius)
        }
    }
}

// MARK: - Active Ingestion

private struct SourceIngestPayload: Codable, Sendable {
    let stage: String
}

private struct ActiveIngestionView: View {
    @Environment(AppStore.self) private var store
    @Binding var step: SourceConnectionWizard.ConnectionStep
    let source: AnigmaSource
    private let progressSubject: PassthroughSubject<OperationResult<SourceIngestPayload>, Never>
    @StateObject private var progressViewModel: OperationProgressViewModel<SourceIngestPayload>

    private let stages: [(percent: Double, label: String)] = [
        (0, "Queued"),
        (10, "Discovery"),
        (40, "Indexing"),
        (75, "Understanding"),
        (100, "Sealing evidence")
    ]

    init(step: Binding<SourceConnectionWizard.ConnectionStep>, source: AnigmaSource) {
        self._step = step
        self.source = source
        let subject = PassthroughSubject<OperationResult<SourceIngestPayload>, Never>()
        self.progressSubject = subject
        _progressViewModel = StateObject(
            wrappedValue: OperationProgressViewModel(
                publisher: subject.eraseToAnyPublisher(),
                label: "Source ingestion"
            )
        )
    }

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x4) {
            OperationProgressView(
                viewModel: progressViewModel,
                title: "Indexing \(source.name)"
            )
            .tint(Bauhaus.Color.accentHighContrast)

            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                ForEach(stages, id: \.label) { stage in
                    ProgressStepRow(
                        label: stage.label,
                        status: stageStatus(for: stage.percent),
                        progress: stage.percent == 0
                            ? (progressViewModel.progressValue > 0 ? 1.0 : 0.0)
                            : min(progressViewModel.progressValue / stage.percent, 1.0)
                    )
                }
            }
            .padding(.top, Bauhaus.Grid.x2)

            VStack(alignment: .leading, spacing: 12) {
                Text("EXECUTIVE REPORT").font(Bauhaus.Font.monoBold).foregroundStyle(Bauhaus.Color.textTertiary)

                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    ReportRow(label: "Healthy files", value: "398", icon: "checkmark.circle", color: Bauhaus.Color.success)
                    ReportRow(label: "Skipped (Permission denied)", value: "12", icon: "lock.fill", color: Bauhaus.Color.warning)
                    ReportRow(label: "Skipped (Unsupported format)", value: "4", icon: "questionmark.circle", color: Bauhaus.Color.textSecondary)
                }
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .cornerRadius(Bauhaus.Grid.cornerRadius)
            .padding(.top, Bauhaus.Grid.unit)

            Text("Digestion is running as a background job. You can close this window; the governed process will continue.")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .multilineTextAlignment(.center)

            Button("Done") { // link ButtonStyle
                store.sources.append(source)
                step = .dashboard
            }
            .accessibilityLabel("Complete wizard")
            .accessibilityHint("Adds the new source and returns to dashboard")
            .buttonStyle(.link)
        }
        .padding(.vertical, Bauhaus.Grid.x4)
        .onAppear {
            startIngestionIfNeeded()
        }
    }

    private func startIngestionIfNeeded() {
        guard progressViewModel.latest == nil else { return }
        Task {
            for stage in stages {
                let state: OperationResult<SourceIngestPayload>.State = stage.percent >= 100 ? .success : .running
                let result = OperationResult(
                    kind: "source_ingest",
                    state: state,
                    payload: .init(stage: stage.label),
                    progress: .init(percent: stage.percent, message: stage.label),
                    failure: nil
                )
                progressSubject.send(result)
                try? await Task.sleep(nanoseconds: UInt64(300_000_000))
            }
        }
    }

    private func stageStatus(for percent: Double) -> String {
        let current = progressViewModel.progressValue
        if current >= percent {
            return "Complete"
        } else if current + 0.1 >= percent {
            return "In Progress"
        } else {
            return "Waiting"
        }
    }
}

private struct ProgressStepRow: View {
    let label: String
    let status: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit / 2) {
            HStack {
                Text(label).font(Bauhaus.Font.caption).fontWeight(.bold)
                Spacer()
                Text(status).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Bauhaus.Color.border)
                    Rectangle()
                        .fill(Bauhaus.Color.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4) // OK: Fixed progress height
            .cornerRadius(2)
        }
    }
}

private struct ReportRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(Bauhaus.Font.caption)
            Spacer()
            Text(value).font(Bauhaus.Font.monoBold)
        }
    }
}

// MARK: - Helpers

extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}
