//
//  SourceConnectionWizard.swift
//  AnigmaAppMac
//
//  Wizard for adding a new source connection.
//  Steps: Type Selection -> Scope Config -> Depth/Policy -> Active Ingestion
//

import SwiftUI
import OSLog

private let sourceWizardLogger = Logger(subsystem: "com.anigma.app", category: "sources")

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
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
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
                        DepthConfigView(step: $step, source: $source, stats: SourceStats(fileCount: 1420, totalSize: 450 * 1024 * 1024, entityCount: 120, durationEstimateMinutes: 12))
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
        .frame(width: 600, height: 700)
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
                    Button(action: {
                        selectedType = type
                        source.type = type
                        step = .scopeConfig
                    }) {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Image(systemName: type.icon)
                                .font(.system(size: 24))
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
                    Button("Change Type") { step = .typeSelection }
                        .buttonStyle(.link)
                }
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.surface)
                .cornerRadius(Bauhaus.Grid.cornerRadius)

                if source.type == .filesystem {
                    Button(action: {
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
                            sourceWizardLogger.error("File selection failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Name").font(Bauhaus.Font.caption)
                    TextField("e.g. Housing Documents", text: $source.name)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, Bauhaus.Grid.x2)

                Spacer()

                Button("Looks Useful, Proceed") {
                    step = .depthConfig
                }
                .bauhausAccentButton()
                .frame(maxWidth: .infinity)
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
                Button(action: { source.depth = depth }) {
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

            Button("Next: Policies") {
                step = .policyConfig
            }
            .bauhausAccentButton()
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Policy Configuration

private struct PolicyConfigView: View {
    @Binding var step: SourceConnectionWizard.ConnectionStep
    @Binding var source: AnigmaSource

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            Text("Governance Policies").font(Bauhaus.Font.header)

            SectionView(title: "COMPUTE BUDGET") {
                Toggle("Digest only when plugged into power", isOn: $source.computePolicy.allowOnBattery.inverted)
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU Throttle: \(Int(source.computePolicy.cpuThrottle * 100))%")
                        .font(Bauhaus.Font.caption)
                    Slider(value: $source.computePolicy.cpuThrottle, in: 0.1...1.0)
                }
                Picker("Schedule", selection: $source.computePolicy.schedule) {
                    Text("Always").tag("Always")
                    Text("Overnight Only").tag("Overnight")
                    Text("When Idle").tag("When Idle")
                }
            }

            SectionView(title: "EXCLUSIONS") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exclude Patterns (Glob)").font(Bauhaus.Font.caption)
                    TextField("e.g. **/node_modules/**, **/.git/**", text: .constant("")) // Placeholder binding
                        .textFieldStyle(.roundedBorder)

                    Text("Sensitive Paths (No Content)").font(Bauhaus.Font.caption)
                    TextField("e.g. **/secrets/**", text: .constant("")) // Placeholder binding
                        .textFieldStyle(.roundedBorder)
                }
            }

            SectionView(title: "RETENTION") {
                Toggle("Store extracted text locally", isOn: $source.storagePolicy.storeExtractedText)
                Toggle("Store embeddings (for search/atlas)", isOn: $source.storagePolicy.storeEmbeddings)
                HStack {
                    Text("Purge derived data after")
                    Spacer()
                    Text("Never").foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .font(Bauhaus.Font.caption)
            }

            Spacer()

            Button("Start Digestion") {
                step = .active
            }
            .bauhausAccentButton()
            .frame(maxWidth: .infinity)
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

private struct ActiveIngestionView: View {
    @Environment(AppStore.self) private var store
    @Binding var step: SourceConnectionWizard.ConnectionStep
    let source: AnigmaSource

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x4) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, Bauhaus.Grid.x2)

            Text("Indexing \(source.name)")
                .font(Bauhaus.Font.header)

            VStack(alignment: .leading, spacing: 4) {
                ProgressStepRow(label: "Discovery", status: "Complete", progress: 1.0)
                ProgressStepRow(label: "Indexing", status: "In Progress (14%)", progress: 0.14)
                ProgressStepRow(label: "Understanding", status: "Waiting", progress: 0.0)
            }
            .padding(.top, Bauhaus.Grid.x2)

            VStack(alignment: .leading, spacing: 12) {
                Text("EXECUTIVE REPORT").font(Bauhaus.Font.monoBold).foregroundStyle(Bauhaus.Color.textTertiary)

                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    ReportRow(label: "Healthy files", value: "398", icon: "checkmark.circle", color: .green)
                    ReportRow(label: "Skipped (Permission denied)", value: "12", icon: "lock.fill", color: .orange)
                    ReportRow(label: "Skipped (Unsupported format)", value: "4", icon: "questionmark.circle", color: .secondary)
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

            Button("Done") {
                store.sources.append(source)
                step = .dashboard
            }
            .buttonStyle(.link)
        }
        .padding(.vertical, Bauhaus.Grid.x4)
    }
}

private struct ProgressStepRow: View {
    let label: String
    let status: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .frame(height: 4)
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
