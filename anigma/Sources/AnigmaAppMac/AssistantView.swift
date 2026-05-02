//
//  AssistantView.swift
//  AnigmaAppMac
//
//  Assistant-first conversation interface for the launcher.
//  Provides a calm, focused entry point aligned with the new product direction:
//  - Local context engine with receipts and provenance
//  - Progressive disclosure (no dashboard complexity)
//  - Lightweight launcher integration
//

import SwiftUI
import AppKit
import HarmoniaV2Surface
import ContractsCore

struct AssistantView: View {
    @ObservedObject var model: AppModel
    @State private var inputText: String = ""
    @State private var conversationHistory: [ConversationMessage] = []
    @State private var isProcessing: Bool = false
    private let calmSurfaceDefaults = AssistantCalmSurfaceDefaults.resolve()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: calm, minimal
            headerView
            
            Divider()
            
            // Conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if conversationHistory.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(conversationHistory) { message in
                                MessageBubbleView(
                                    model: model,
                                    message: message,
                                    surfaceDefaults: calmSurfaceDefaults
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: conversationHistory.count) { _, _ in
                    if let lastMessage = conversationHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            inputView
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await model.loadAssistantContextPolicy()
            let history = await model.loadAssistantConversationHistory()
            await MainActor.run {
                conversationHistory = history
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assistant")
                    .font(.headline)
                
                if let projectId = model.selectedProjectId {
                    Text(model.projects.first(where: { $0.id == projectId })?.name ?? projectId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No project selected")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            // Context indicator
            if let status = model.appStatus {
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.killSwitchActive ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(status.operatingMode.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            
            Text("How can I help you today?")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Ask questions about your projects, codebases, or documents. All analysis is performed locally and remains private.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var inputView: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Type a question...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isProcessing || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: captureMemo) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isProcessing
                        || model.memoState.isSaving
                        || model.selectedProjectId == nil
                        || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .secondary
                            : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                isProcessing
                || model.memoState.isSaving
                || model.selectedProjectId == nil
                || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .help("Save input as memo")
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !isProcessing else { return }
        
        let userMessage = ConversationMessage(role: .user, content: trimmed)
        conversationHistory.append(userMessage)
        inputText = ""
        isProcessing = true
        
        Task {
            do {
                let response = try await model.submitAssistantQuery(trimmed)
                await MainActor.run {
                    conversationHistory.append(response)
                    isProcessing = false
                }
            } catch {
                let errorMessage = ConversationMessage(
                    role: .assistant,
                    content: "Sorry, I encountered an error: \(error.localizedDescription)"
                )
                await MainActor.run {
                    conversationHistory.append(errorMessage)
                    isProcessing = false
                }
            }
        }
    }

    private func captureMemo() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.captureMemoFromAssistantInput(trimmed)
        inputText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    @ObservedObject var model: AppModel
    let message: ConversationMessage
    let surfaceDefaults: AssistantCalmSurfaceDefaults
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Content
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)
                
                // Metadata (assistant only)
                if message.role == .assistant {
                    VStack(alignment: .leading, spacing: 8) {
                        if let provenance = message.provenance {
                            AssistantProvenanceRecordView(
                                provenance: provenance,
                                currentPolicy: model.assistantContextPolicy,
                                surfaceDefaults: surfaceDefaults,
                                onPinSource: { sourceID in
                                    Task { await model.toggleAssistantSourcePin(sourceID) }
                                },
                                onExcludeSource: { sourceID in
                                    Task { await model.toggleAssistantSourceExclusion(sourceID) }
                                }
                            )
                        } else {
                            let sourceCount = message.sourceCount ?? message.sources.count
                            HStack(spacing: 8) {
                                if sourceCount > 0 {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text("\(sourceCount) sources")
                                        .font(.caption2)
                                }
                                
                                if let confidence = message.confidence {
                                    Image(systemName: "gauge.with.dots.needle.50percent")
                                        .font(.caption2)
                                    Text(String(format: "%.0f%%", confidence * 100))
                                        .font(.caption2)
                                }
                                
                                Text(message.timestamp, style: .time)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct AssistantProvenanceRecordView: View {
    let provenance: AnswerProvenanceRecord
    let currentPolicy: AssistantContextSourcePolicy
    let surfaceDefaults: AssistantCalmSurfaceDefaults
    let onPinSource: (String) -> Void
    let onExcludeSource: (String) -> Void
    @State private var revealMetadata: Bool
    @State private var revealSourceControls: Bool
    @State private var revealAllSources = false
    @State private var revealAllMissingContext = false
    @State private var revealAllNondeterminismReasons = false
    @State private var revealReplayHashes: Bool
    private let disclosureRules: AssistantDisclosureCapacityRules

    init(
        provenance: AnswerProvenanceRecord,
        currentPolicy: AssistantContextSourcePolicy,
        surfaceDefaults: AssistantCalmSurfaceDefaults,
        onPinSource: @escaping (String) -> Void,
        onExcludeSource: @escaping (String) -> Void
    ) {
        self.provenance = provenance
        self.currentPolicy = currentPolicy
        self.surfaceDefaults = surfaceDefaults
        self.onPinSource = onPinSource
        self.onExcludeSource = onExcludeSource
        self.disclosureRules = surfaceDefaults.disclosureRules
        _revealMetadata = State(initialValue: surfaceDefaults.showMetadataByDefault)
        _revealSourceControls = State(initialValue: surfaceDefaults.showSourceControlsByDefault)
        _revealReplayHashes = State(initialValue: surfaceDefaults.showReplayHashesByDefault)
    }

    private var confidenceLabel: String {
        String(format: "%.0f%%", provenance.confidence * 100)
    }

    private var replayIcon: String {
        provenance.replay.replayable ? "arrow.clockwise" : "exclamationmark.triangle"
    }

    private var determinismIcon: String {
        provenance.replay.deterministic ? "checkmark.seal" : "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
    }

    private var determinismLabel: String {
        provenance.replay.deterministic ? "Deterministic" : "Non-deterministic"
    }

    private var confidenceTint: Color {
        switch provenance.confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .yellow
        default:
            return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !disclosureRules.validationIssues.isEmpty {
                disclosureRuleViolationView
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Canonical answer provenance")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(provenance.generatedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                MetadataChip(label: "Record", value: String(provenance.id.prefix(10)), icon: "number")
            }

            confidenceSection
            metadataSection
            sourcesSection
            replaySection

            if !provenance.missingContext.isEmpty {
                missingContextSection(provenance.missingContext)
            }
        }
        .padding(10)
        .frame(maxWidth: 500, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(confidenceLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: provenance.confidence)
                .tint(confidenceTint)
        }
    }

    private var disclosureRuleViolationView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Disclosure capacity configuration is invalid.")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
            ForEach(disclosureRules.validationIssues, id: \.self) { issue in
                Text("• \(issue)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            Text("Fail-safe defaults are applied explicitly; overflow is still surfaced.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
    }

    private var provenanceMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MetadataChip(label: "Model", value: provenance.modelName, icon: "cpu")
                MetadataChip(label: "Project", value: provenance.projectName, icon: "folder")
                MetadataChip(label: "Session", value: provenance.sessionId, icon: "person.2")
            }
            HStack(spacing: 8) {
                MetadataChip(label: "Top K", value: "\(provenance.topK)", icon: "line.3.horizontal.decrease.circle")
                MetadataChip(label: "Scan", value: "\(provenance.scanLimit)", icon: "binoculars")
                MetadataChip(label: "Replay", value: provenance.replay.mode, icon: replayIcon)
                MetadataChip(label: "Run", value: determinismLabel, icon: determinismIcon)
                MetadataChip(label: "Pinned", value: "\(currentPolicy.pinnedSourceIDs.count)", icon: "pin.fill")
                MetadataChip(label: "Excluded", value: "\(currentPolicy.excludedSourceIDs.count)", icon: "nosign")
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if revealMetadata {
                provenanceMetadata
                Button("Hide technical details") {
                    withAnimation {
                        revealMetadata = false
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            } else {
                Button("Show technical details") {
                    withAnimation {
                        revealMetadata = true
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var sourcesSection: some View {
        let defaultWindow = disclosureRules.window(
            for: .sources,
            totalCount: provenance.sources.count,
            revealAll: false
        )
        let displayWindow = disclosureRules.window(
            for: .sources,
            totalCount: provenance.sources.count,
            revealAll: revealAllSources
        )
        let visibleSources = Array(provenance.sources.prefix(displayWindow.visibleCount))

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sources")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(provenance.sources.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if visibleSources.isEmpty {
                Text("No sources are available for this answer.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleSources) { source in
                        AssistantProvenanceSourceRow(
                            source: source,
                            showPolicyControls: revealSourceControls,
                            isPinned: currentPolicy.isPinned(source.id),
                            isExcluded: currentPolicy.isExcluded(source.id),
                            onPin: { onPinSource(source.id) },
                            onExclude: { onExcludeSource(source.id) }
                        )
                    }
                }
            }

            disclosureCapacityNotice(
                sectionLabel: "source",
                window: displayWindow
            )

            if revealAllSources {
                if provenance.sources.count > defaultWindow.visibleCount {
                    Button("Show fewer sources") {
                        withAnimation {
                            revealAllSources = false
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }
            } else if displayWindow.collapsedHiddenCount > 0 {
                Button("Show \(displayWindow.collapsedHiddenCount) more \(pluralized("source", count: displayWindow.collapsedHiddenCount))") {
                    withAnimation {
                        revealAllSources = true
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }

            if !visibleSources.isEmpty {
                if revealSourceControls {
                    Button("Hide source controls") {
                        withAnimation {
                            revealSourceControls = false
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                } else {
                    Button("Show source controls") {
                        withAnimation {
                            revealSourceControls = true
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var replaySection: some View {
        let defaultWindow = disclosureRules.window(
            for: .nondeterminismReasons,
            totalCount: provenance.replay.nondeterminismReasons.count,
            revealAll: false
        )
        let displayWindow = disclosureRules.window(
            for: .nondeterminismReasons,
            totalCount: provenance.replay.nondeterminismReasons.count,
            revealAll: revealAllNondeterminismReasons
        )
        let visibleReasons = Array(provenance.replay.nondeterminismReasons.prefix(displayWindow.visibleCount))

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Replay details")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(provenance.replay.replayable ? "\(determinismLabel) · Replayable" : "\(determinismLabel) · Locked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(provenance.replay.notes)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !visibleReasons.isEmpty {
                FlowLikeTags(tags: visibleReasons, icon: "exclamationmark.circle", tint: .orange)
                disclosureCapacityNotice(
                    sectionLabel: "reason",
                    window: displayWindow
                )
                if revealAllNondeterminismReasons {
                    if provenance.replay.nondeterminismReasons.count > defaultWindow.visibleCount {
                        Button("Show fewer reasons") {
                            withAnimation {
                                revealAllNondeterminismReasons = false
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                    }
                } else if displayWindow.collapsedHiddenCount > 0 {
                    Button("Show \(displayWindow.collapsedHiddenCount) more \(pluralized("reason", count: displayWindow.collapsedHiddenCount))") {
                        withAnimation {
                            revealAllNondeterminismReasons = true
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }
            }

            if revealReplayHashes {
                HStack(alignment: .top, spacing: 8) {
                    ProvenanceHashField(label: "Token", value: provenance.replay.replayToken)
                    ProvenanceHashField(label: "Source graph", value: provenance.replay.sourceGraphHash)
                    ProvenanceHashField(label: "Policy", value: provenance.replay.contextPolicyHash)
                    ProvenanceHashField(label: "Receipt chain", value: provenance.replay.receiptChainHash)
                }
                Button("Hide replay hashes") {
                    withAnimation {
                        revealReplayHashes = false
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            } else {
                Text(surfaceDefaults.showReplayHashesByDefault
                     ? "Replay hashes can be hidden to reduce visual noise."
                     : "Replay hashes are hidden by default. Reveal to inspect token, source graph, policy, and receipt chain identifiers.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Show replay hashes") {
                    withAnimation {
                        revealReplayHashes = true
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }
        }
    }

    private func missingContextSection(_ items: [String]) -> some View {
        let defaultWindow = disclosureRules.window(
            for: .missingContext,
            totalCount: items.count,
            revealAll: false
        )
        let displayWindow = disclosureRules.window(
            for: .missingContext,
            totalCount: items.count,
            revealAll: revealAllMissingContext
        )
        let visibleItems = Array(items.prefix(displayWindow.visibleCount))

        return VStack(alignment: .leading, spacing: 6) {
            Text("Missing context")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLikeTags(tags: visibleItems, icon: "exclamationmark.circle", tint: .orange)

            disclosureCapacityNotice(
                sectionLabel: "context item",
                window: displayWindow
            )

            if revealAllMissingContext {
                if items.count > defaultWindow.visibleCount {
                    Button("Show fewer context warnings") {
                        withAnimation {
                            revealAllMissingContext = false
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }
            } else if displayWindow.collapsedHiddenCount > 0 {
                Button("Show \(displayWindow.collapsedHiddenCount) more \(pluralized("context warning", count: displayWindow.collapsedHiddenCount))") {
                    withAnimation {
                        revealAllMissingContext = true
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }
        }
    }

    private func disclosureCapacityNotice(
        sectionLabel: String,
        window: AssistantDisclosureCapacityWindow
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if window.collapsedHiddenCount > 0 {
                Text("\(window.collapsedHiddenCount) \(pluralized(sectionLabel, count: window.collapsedHiddenCount)) hidden by default.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if window.overflowCount > 0 {
                Text("Disclosure capacity reached: \(window.overflowCount) \(pluralized(sectionLabel, count: window.overflowCount)) not shown.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func pluralized(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}

struct AssistantProvenanceSourceRow: View {
    let source: AssistantSourceChip
    let showPolicyControls: Bool
    let isPinned: Bool
    let isExcluded: Bool
    let onPin: () -> Void
    let onExclude: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                    
                    if let path = source.path {
                        Text(path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Spacer()
                
                Text(String(format: "%.2f", source.similarity))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if showPolicyControls {
                    Button(action: onPin) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isPinned ? .blue : .secondary)
                    .accessibilityLabel(isPinned ? "Unpin source" : "Pin source")

                    Button(action: onExclude) {
                        Image(systemName: isExcluded ? "nosign" : "nosign")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isExcluded ? .red : .secondary)
                    .accessibilityLabel(isExcluded ? "Include source" : "Exclude source")
                }
            }
            
            if let excerpt = source.excerpt {
                Text(excerpt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if isPinned {
                    FlowLikeTags(tags: ["Pinned"], icon: "pin.fill", tint: .blue)
                }
                if isExcluded {
                    FlowLikeTags(tags: ["Excluded"], icon: "nosign", tint: .red)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .cornerRadius(8)
    }
}

struct ProvenanceHashField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(shortValue(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortValue(_ value: String) -> String {
        guard value.count > 16 else { return value }
        return String(value.prefix(12)) + "…"
    }
}

struct AssistantSourceChipView: View {
    let source: AssistantSourceChip
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.caption2)
            Text(source.title)
                .font(.caption2)
                .lineLimit(1)
            if source.similarity > 0 {
                Text(String(format: "%.2f", source.similarity))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

struct FlowLikeTags: View {
    let tags: [String]
    let icon: String
    let tint: Color
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                        Text(tag)
                    }
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct MetadataChip: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text("\(label): \(value)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
