//
//  AppModel.swift
//  AnigmaAppMac
//
//  Main application state owner for Phase 3 workflows.
//

import SwiftUI
import HarmoniaV2Contracts
import HarmoniaV2Surface
import AnigmaCore
import ContractsCore
import AnigmaPrimitives
import CryptoKit

@MainActor
class AppModel: ObservableObject {
    @Published var selectedProjectId: String?
    @Published var projects: [ProjectRecord] = []
    @Published var appStatus: AppStatus?
    @Published var lastError: String?
    @Published var assistantContextPolicy = AssistantContextSourcePolicy()
    @Published var assistantContextSummaries: [AssistantConversationContextSnapshot] = []
    @Published var assistantLatestContextSummary: AssistantConversationContextSnapshot?
    
    // Pipelines
    @Published var pipelines: [PipelineInfo] = []
    @Published var pipelineRuns: [AnigmaPipelineRunResponse] = []
    @Published var selectedPipelineRun: AnigmaPipelineRunResponse?
    @Published var pipelineStatus: AnigmaPipelineStatusResponse?
    
    // Indexing State
    public struct IndexingState {
        public enum Phase {
            case idle, ready, running, cancelled, failed, complete
        }
        public var phase: Phase = .idle
        public var selectedFolder: URL?
        public var progress: IndexProgress?
        public var startedAt: Date?
        public var elapsed: TimeInterval = 0
        public var logLines: [String] = []
        public var dryRun: Bool = false
        public var lastError: String?
    }
    
    @Published var indexingState = IndexingState()
    private var indexTask: Task<Void, Never>?
    
    // Memo State
    public struct MemoState {
        public var text: String = ""
        public var isSaving: Bool = false
        public var lastSavedId: String?
        public var lastSavedAt: Date?
        public var characterCount: Int { text.count }
    }
    
    @Published var memoState = MemoState()
    private var memoSaveTask: Task<Void, Never>?
    
    // Recall State
    public struct RecallState {
        public var isSearching: Bool = false
        public var results: [RecallItem] = []
        public var stats: RecallStats?
        public var selectedResult: RecallItem?
    }
    
    @Published var recallState = RecallState()
    @Published var recallQuery: String = ""
    @Published var recallOptions = RecallOptions()
    private var recallTask: Task<Void, Never>?
    
    private let client: any HarmoniaAppClient
    private let principal: Principal
    private let assistantSessionManager: ConversationSessionManager
    
    init(client: any HarmoniaAppClient, principal: Principal = Principal(id: "user", displayName: "User")) {
        self.client = client
        self.principal = principal
        self.assistantSessionManager = ConversationSessionManager()
    }
    
    // MARK: - Memo Actions
    
    func saveMemo() {
        guard !memoState.text.isEmpty, let projectId = selectedProjectId, !memoState.isSaving else { return }
        
        memoState.isSaving = true
        lastError = nil
        
        memoSaveTask?.cancel()
        memoSaveTask = Task {
            do {
                let record = try await client.addMemo(text: memoState.text, projectId: projectId, principal: principal)
                self.memoState.lastSavedId = record.id
                self.memoState.lastSavedAt = record.createdAt
                self.memoState.text = "" // Clear on success
                self.memoState.isSaving = false
                
                // Refresh status to see if deny counts changed (unlikely on success)
                await refreshStatus()
            } catch {
                self.memoState.isSaving = false
                handleError(error)
            }
        }
    }

    func captureMemoFromAssistantInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memoState.text = trimmed
        saveMemo()
    }
    
    func clearMemo() {
        memoState.text = ""
        lastError = nil
    }
    
    // MARK: - Recall Actions
    
    func startRecall() {
        guard !recallQuery.isEmpty, let projectId = selectedProjectId else { return }
        
        recallState.isSearching = true
        recallState.results = []
        recallState.stats = nil
        recallState.selectedResult = nil
        lastError = nil // Reset global error banner
        
        recallTask?.cancel()
        recallTask = Task {
            do {
                let result = try await client.recall(query: recallQuery, projectId: projectId, options: recallOptions)
                
                if !Task.isCancelled {
                    self.recallState.results = result.results
                    self.recallState.stats = result.stats
                    self.recallState.isSearching = false
                    
                    // Check for scan limit warning
                    if let limit = result.stats.scanLimit, result.stats.rowsScanned >= limit {
                        // Just a subtle hint or console log? 
                        // User requested UI hint: "Scan limit reached. Increase scan limit for better recall."
                        // We can set a transient warning or just rely on the UI displaying "Scanned X rows (limit Y)"
                    }
                }
            } catch {
                self.recallState.isSearching = false
                self.lastError = error.localizedDescription
            } catch {
                self.recallState.isSearching = false
                self.lastError = error.localizedDescription
            }
        }
    }
    
    func selectRecallResult(_ item: RecallItem) {
        self.recallState.selectedResult = item
    }
    
    func clearRecall() {
        recallTask?.cancel()
        recallState = RecallState()
        recallQuery = ""
    }
    
    // MARK: - Indexing Actions
    
    func selectFolder(url: URL) {
        // Start accessing security scoped resource if applicable
        let _ = url.startAccessingSecurityScopedResource()
        
        // Store bookmark for persistence (optional future step)
        // For now, we just use the URL
        
        self.indexingState.selectedFolder = url
        self.indexingState.phase = .ready
        self.indexingState.logLines.removeAll()
        self.indexingState.progress = nil
        self.indexingState.lastError = nil
    }
    
    func startIndex() {
        guard let folder = indexingState.selectedFolder, 
              let projectId = selectedProjectId,
              indexingState.phase != .running else { return }
        
        // Reset State
        indexingState.phase = .running
        indexingState.startedAt = Date()
        indexingState.elapsed = 0
        indexingState.logLines = ["Starting index of \(folder.lastPathComponent)..."]
        indexingState.lastError = nil
        indexingState.progress = IndexProgress.scanning(0)
        
        let dryRun = indexingState.dryRun
        
        // Start Task
        indexTask?.cancel()
        indexTask = Task {
            do {
                let stream = try await client.index(folder: folder, projectId: projectId, principal: principal, dryRun: dryRun)
                
                for await progress in stream {
                    if Task.isCancelled { break }
                    
                    // Update main actor state
                    await updateIndexProgress(progress)
                }
                
                await finishIndex(cancelled: Task.isCancelled)
                
            } catch {
                await handleIndexError(error)
            }
        }
    }
    
    func cancelIndex() {
        if indexingState.phase == .running {
            indexingState.phase = .cancelled
            indexingState.logLines.append("Cancelling...")
            indexTask?.cancel()
        }
    }
    
    private func updateIndexProgress(_ progress: IndexProgress) {
        self.indexingState.progress = progress
        
        // Update elapsed
        if let start = indexingState.startedAt {
            self.indexingState.elapsed = Date().timeIntervalSince(start)
        }
        
        // Log updates (bounded)
        if let file = progress.currentFile {
            appendLog("Indexing: \(file)")
        } else if let error = progress.error {
            appendLog("Error: \(error)")
        }
        
        if let error = progress.error {
             self.indexingState.lastError = error
             // If denied, the stream usually finishes itself
        }
    }
    
    private func finishIndex(cancelled: Bool) {
        if cancelled {
             self.indexingState.phase = .cancelled
             appendLog("Cancelled by user.")
        } else if let error = indexingState.lastError {
             self.indexingState.phase = .failed
             appendLog("Failed: \(error)")
             
             // Check if it was a denial to show banner
             if error.contains("Denied") {
                 self.lastError = error
             }
        } else {
             self.indexingState.phase = .complete
             appendLog("Completed successfully.")
        }
        
        // Trigger status refresh to see new counts/denials
        Task { await refreshStatus() }
    }
    
    private func handleIndexError(_ error: Error) {
        self.indexingState.phase = .failed
        self.indexingState.lastError = error.localizedDescription
        appendLog("System Error: \(error.localizedDescription)")
    }
    
    private func appendLog(_ line: String) {
        if indexingState.logLines.count > 200 {
            indexingState.logLines.removeFirst()
        }
        indexingState.logLines.append(line)
    }
    
    func bootstrap() async {
        do {
            try await client.bootstrap()
            await refreshProjects()
        } catch {
            self.lastError = "Bootstrap failed: \(error.localizedDescription)"
        }
    }
    
    func refreshProjects() async {
        do {
            self.projects = try await client.listProjects()
        } catch {
            self.lastError = "List projects failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Vault Actions
    @Published var vaultStatus: HarmoniaClient.VaultStatusResponse?
    
    func refreshVaultStatus() async {
        do {
            self.vaultStatus = try await client.getVaultStatus()
        } catch {
            handleError(error)
        }
    }
    
    func verifyVault() async throws -> HarmoniaClient.VaultVerifyResponse {
        let result = try await client.verifyVault()
        await refreshVaultStatus()
        return result
    }
    
    func runVaultGC(dryRun: Bool = false) async throws -> HarmoniaClient.VaultGCResponse {
        let result = try await client.runVaultGC(dryRun: dryRun)
        await refreshVaultStatus()
        return result
    }

    // MARK: - Pipeline Actions
    
    func loadPipelines() async {
        do {
            let response = try await client.listPipelines()
            self.pipelines = response.pipelines
        } catch {
            handleError(error)
        }
    }
    
    func createPipeline(name: String, stages: [PipelineStage]) async {
        do {
            _ = try await client.createPipeline(name: name, stages: stages)
            await loadPipelines()
        } catch {
            handleError(error)
        }
    }
    
    func runPipeline(id: String, inputs: [String: String]) async {
        do {
            let response = try await client.runPipeline(pipelineId: id, inputs: inputs)
            self.pipelineRuns.append(response)
        } catch {
            handleError(error)
        }
    }

    func selectProject(_ id: String) async {
        self.selectedProjectId = id
        await refreshStatus()
    }
    
    func refreshStatus() async {
        do {
            print("🔍 Refreshing status for project: \(selectedProjectId ?? "none")")
            self.appStatus = try await client.getStatus(projectId: selectedProjectId)
            print("✅ Status refreshed - mode: \(appStatus?.operatingMode.rawValue ?? "nil"), killSwitch: \(appStatus?.killSwitchActive ?? false)")
        } catch {
            print("❌ Status refresh error: \(error)")
            self.lastError = "Status check failed: \(error.localizedDescription)"
        }
    }
    
    func createProject(name: String, embeddingModel: String) async {
        do {
            let id = UUID().uuidString
            try await client.createProject(id: id, name: name, embeddingModel: embeddingModel, principal: principal)
            await refreshProjects()
            await selectProject(id)
        } catch {
            handleError(error)
        }
    }
    
    func setMode(_ mode: HarmoniaV2Contracts.OperatingMode) async {
        guard let projectId = selectedProjectId else {
            lastError = "No project selected"
            print("⚠️  setMode failed: No project selected")
            return
        }

        do {
            print("🔧 Setting mode to \(mode) for project \(projectId)")
            try await client.setMode(mode, for: projectId, principal: principal)
            await refreshStatus()
            print("✅ Mode set successfully")
        } catch {
            print("❌ setMode error: \(error)")
            handleError(error)
        }
    }
    func setKillSwitch(active: Bool) async {
        do {
            print("🔧 Setting kill switch to \(active ? "ON" : "OFF") for project \(selectedProjectId ?? "global")")
            try await client.setKillSwitch(active: active, for: selectedProjectId, reason: "User Toggle", principal: principal)
            await refreshStatus()
            print("✅ Kill switch set successfully")
        } catch {
            print("❌ setKillSwitch error: \(error)")
            handleError(error)
        }
    }

    func submitAssistantQuery(_ query: String) async throws -> ConversationMessage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let provenance = try await generateAssistantProvenance(for: trimmed)
        let userMessage = ConversationMessage(role: .user, content: trimmed)
        let assistantMessage = ConversationMessage(
            role: .assistant,
            content: provenance.answerText,
            createdAt: Date(),
            provenance: provenance,
            confidence: provenance.confidence
        )
        _ = await recordAssistantConversationTurn(userMessage: userMessage, assistantMessage: assistantMessage)
        return assistantMessage
    }

    public enum AssistantResponseError: Error {
        case noProjectSelected
        case contextGenerationFailed
        case retrievalFailed
        case groundingCheckFailed
    }

    func generateAssistantProvenance(for query: String) async throws -> AnswerProvenanceRecord {
        guard let projectId = selectedProjectId else {
            throw AssistantResponseError.noProjectSelected
        }

        let project = projects.first(where: { $0.id == projectId })
        let projectName = project?.name ?? projectId
        let modelName = project?.embeddingModel ?? "llama-3.2-1b"
        let sessionId = await assistantSessionManager.currentSessionID
        let sourcePolicy = assistantContextPolicy
        let options = RecallOptions(topK: 4, scanLimit: 100, threshold: 0.7, hybrid: true, explain: false)
        let recall = try await client.recall(query: query, projectId: projectId, options: options)

        let filteredResults = recall.results.filter { !sourcePolicy.isExcluded($0.id) }
        var pinnedOrder: [String: Int] = [:]
        for (index, sourceID) in sourcePolicy.pinnedSourceIDs.enumerated() {
            if pinnedOrder[sourceID] == nil {
                pinnedOrder[sourceID] = index
            }
        }
        let sources = filteredResults.sorted { lhs, rhs in
            let lhsPinned = pinnedOrder[lhs.id]
            let rhsPinned = pinnedOrder[rhs.id]
            switch (lhsPinned, rhsPinned) {
            case let (lhsIndex?, rhsIndex?):
                return lhsIndex < rhsIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.rank < rhs.rank
            }
        }.map { item in
            AssistantSourceChip(
                id: item.id,
                title: item.metadata["fileName"] ?? item.id,
                path: item.metadata["filePath"],
                excerpt: String(item.content.prefix(220)),
                similarity: Double(item.similarity),
                sourceHash: hashString([item.id, item.metadata["filePath"] ?? "", item.content].joined(separator: "||"))
            )
        }

        // Extract source IDs for provenance seal - explicit closure for Swift 6 type-checking
        let sourceIds = sources.map { $0.id }
        let sourceIdString = sourceIds.joined(separator: "|")
        
        let receipts = [
            AssistantReceipt(operationType: "assistant-recall", hash: hashString([query, projectId, modelName, "\(recall.results.count)"].joined(separator: "||"))),
            AssistantReceipt(operationType: "assistant-provenance-seal", hash: hashString([query, sourceIdString, hashString(sourcePolicy.pinnedSourceIDs.joined(separator: "|")), hashString(sourcePolicy.excludedSourceIDs.joined(separator: "|"))].joined(separator: "||")))
        ]

        let missingContext = assistantMissingContext(
            recall: recall,
            sources: sources,
            project: project,
            modelName: modelName,
            sourcePolicy: sourcePolicy
        )

        // Extract provenance components with explicit closures for Swift 6 type-checking
        let recallResultIds = recall.results.map { $0.id }
        let recallIdString = recallResultIds.joined(separator: "|")
        
        let receiptHashes = receipts.map { $0.hash ?? "" }
        let receiptHashString = receiptHashes.joined(separator: "|")
        
        let provenanceHash = hashString([
            query,
            projectId,
            modelName,
            sessionId,
            recallIdString,
            receiptHashString,
            missingContext.joined(separator: "|"),
            hashString(sourcePolicy.pinnedSourceIDs.joined(separator: "|")),
            hashString(sourcePolicy.excludedSourceIDs.joined(separator: "|"))
        ].joined(separator: "||"))

        let answerText = assistantAnswerText(
            query: query,
            projectName: project?.name ?? projectId,
            sources: sources,
            recall: recall
        )
        let replayable = !sources.isEmpty
        let nondeterminismReasons = assistantNondeterminismReasons(
            replayable: replayable,
            missingContext: missingContext
        )
        let deterministicRun = nondeterminismReasons.isEmpty
        let replayNotes = deterministicRun
            ? "Replay regenerates from the stored query, project, recall policy, and source pin/exclude policy."
            : "Replay is blocked or inconsistent because the run is non-deterministic."

        return AnswerProvenanceRecord(
            id: provenanceHash,
            query: query,
            answerText: answerText,
            modelName: modelName,
            projectId: projectId,
            projectName: projectName,
            sessionId: sessionId,
            principalId: principal.id,
            topK: options.topK,
            scanLimit: options.scanLimit ?? 0,
            threshold: Double(options.threshold ?? 0),
            confidence: assistantConfidence(for: recall, sources: sources, missingContext: missingContext),
            sources: sources,
            receipts: receipts,
            missingContext: missingContext,
            contextPolicy: sourcePolicy,
            replay: AssistantReplayMetadata(
                mode: "regenerate",
                replayable: replayable,
                deterministic: deterministicRun,
                nondeterminismReasons: nondeterminismReasons,
                replayToken: provenanceHash,
                sourceGraphHash: hashString(sources.map { $0.sourceHash }.joined(separator: "|")),
                contextPolicyHash: hashString([sourcePolicy.pinnedSourceIDs.joined(separator: "|"), sourcePolicy.excludedSourceIDs.joined(separator: "|")].joined(separator: "||")),
                receiptChainHash: hashString(receipts.compactMap { $0.hash }.joined(separator: "|")),
                notes: replayNotes
            ),
            generatedAt: Date()
        )
    }

    func loadAssistantContextPolicy() async {
        do {
            assistantContextPolicy = try await assistantSessionManager.loadContextPolicy()
        } catch {
            self.lastError = "Assistant policy load failed: \(error.localizedDescription)"
        }
    }

    func toggleAssistantSourcePin(_ sourceID: String) async {
        var policy = assistantContextPolicy
        if policy.isPinned(sourceID) {
            policy.clear(sourceID)
        } else {
            policy.pin(sourceID)
        }
        await persistAssistantContextPolicy(policy)
    }

    func toggleAssistantSourceExclusion(_ sourceID: String) async {
        var policy = assistantContextPolicy
        if policy.isExcluded(sourceID) {
            policy.clear(sourceID)
        } else {
            policy.exclude(sourceID)
        }
        await persistAssistantContextPolicy(policy)
    }

    func loadAssistantConversationHistory() async -> [ConversationMessage] {
        do {
            return try await assistantSessionManager.loadHistory()
        } catch {
            self.lastError = "Assistant history load failed: \(error.localizedDescription)"
            return []
        }
    }

    func loadAssistantContextSummaries() async -> [AssistantConversationContextSnapshot] {
        do {
            let summaries = try await assistantSessionManager.loadContextSummaries()
            assistantContextSummaries = summaries
            assistantLatestContextSummary = summaries.last
            return summaries
        } catch {
            self.lastError = "Assistant summary load failed: \(error.localizedDescription)"
            return []
        }
    }

    func loadLatestAssistantContextSummary() async -> AssistantConversationContextSnapshot? {
        do {
            let summary = try await assistantSessionManager.loadLatestContextSummary()
            assistantLatestContextSummary = summary
            if let summary {
                assistantContextSummaries.removeAll { $0.id == summary.id }
                assistantContextSummaries.append(summary)
            }
            return summary
        } catch {
            self.lastError = "Assistant summary load failed: \(error.localizedDescription)"
            return nil
        }
    }

    func recordAssistantConversationTurn(
        userMessage: ConversationMessage,
        assistantMessage: ConversationMessage
    ) async -> AssistantConversationSnapshot? {
        do {
            let snapshot = try await assistantSessionManager.recordTurn(
                userMessage: userMessage,
                assistantMessage: assistantMessage
            )
            assistantLatestContextSummary = snapshot.latestContextSummary
            if let summary = snapshot.latestContextSummary {
                assistantContextSummaries.removeAll { $0.id == summary.id }
                assistantContextSummaries.append(summary)
            }
            return snapshot
        } catch {
            self.lastError = "Assistant history save failed: \(error.localizedDescription)"
            return nil
        }
    }

    func exportAssistantConversationJSON() async -> Data? {
        do {
            return try await assistantSessionManager.exportJSON()
        } catch {
            self.lastError = "Assistant export failed: \(error.localizedDescription)"
            return nil
        }
    }

    func exportAssistantConversationMarkdown() async -> String? {
        do {
            return try await assistantSessionManager.exportMarkdown()
        } catch {
            self.lastError = "Assistant export failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func handleError(_ error: Error) {
        if let govError = error as? GovernanceError, case .writeBlocked(let violation) = govError {
            // Structured denial is also available via getStatus().lastDenial if we refresh
            // But immediate feedback is good
             self.lastError = "Denied: \(violation.summaryMessage)"
             // Also trigger status refresh to get the denial in appStatus
             Task { await refreshStatus() }
        } else {
            self.lastError = error.localizedDescription
        }
    }

    private func assistantAnswerText(
        query: String,
        projectName: String,
        sources: [AssistantSourceChip],
        recall: RecallResult
    ) -> String {
        guard let top = sources.first else {
            return "No grounded answer yet for “\(query)” in \(projectName)."
        }

        let excerpt = top.excerpt ?? recall.results.first?.content ?? "No excerpt available."
        return "Grounded answer for “\(query)” in \(projectName): \(excerpt)"
    }

    private func assistantConfidence(for recall: RecallResult, sources: [AssistantSourceChip], missingContext: [String]) -> Double {
        let topSimilarity = Double(recall.results.first?.similarity ?? 0)
        let averageSimilarity = recall.results.isEmpty
            ? 0.0
            : Double(recall.results.map(\.similarity).reduce(0, +)) / Double(recall.results.count)
        let sourceBoost = min(0.15, Double(sources.count) * 0.04)
        let contextPenalty = min(0.25, Double(missingContext.count) * 0.06)
        return max(0.05, min(0.98, 0.25 + topSimilarity * 0.45 + averageSimilarity * 0.25 + sourceBoost - contextPenalty))
    }

    private func assistantMissingContext(
        recall: RecallResult,
        sources: [AssistantSourceChip],
        project: ProjectRecord?,
        modelName: String,
        sourcePolicy: AssistantContextSourcePolicy
    ) -> [String] {
        var items: [String] = []
        if project == nil { items.append("Project metadata unavailable") }
        if recall.results.isEmpty { items.append("No recall hits") }
        if sources.isEmpty { items.append("No source chips") }
        if modelName.isEmpty { items.append("No model bound") }
        if !sourcePolicy.pinnedSourceIDs.isEmpty { items.append("Pinned sources applied: \(sourcePolicy.pinnedSourceIDs.count)") }
        let excludedHits = recall.results.filter { sourcePolicy.isExcluded($0.id) }.count
        if excludedHits > 0 { items.append("Excluded \(excludedHits) recall hits by policy") }
        if let scanLimit = recall.stats.scanLimit, recall.stats.rowsScanned >= scanLimit {
            items.append("Scan limit reached")
        }
        return items
    }

    private func assistantNondeterminismReasons(
        replayable: Bool,
        missingContext: [String]
    ) -> [String] {
        var reasons: [String] = []
        if !replayable {
            reasons.append("No grounded source chain for replay")
        }
        reasons.append(contentsOf: missingContext.map { "Missing context: \($0)" })
        return Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons
    }

    private func persistAssistantContextPolicy(_ policy: AssistantContextSourcePolicy) async {
        do {
            assistantContextPolicy = try await assistantSessionManager.updateContextPolicy(policy)
        } catch {
            self.lastError = "Assistant policy save failed: \(error.localizedDescription)"
        }
    }

    private func hashString(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
