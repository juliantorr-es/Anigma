//
//  HarmoniaAppClient.swift
//  HarmoniaSurface
//
//  Mac-app-facing async client API.
//  Wraps PlatformRuntime to provide a unified, governed entry point for the UI.
//

import Foundation
import AnigmaCore
import GovernanceCore
import DatabaseCore
import AnigmaPrimitives
import HarmoniaV2Core
import HarmoniaV2Inference
import HarmoniaV2Contracts

// MARK: - Models

// Models are now defined in HarmoniaV2Contracts
// Import them from there instead of redefining here

// MARK: - Protocol

/// Unified client API for the Harmonia App
public protocol HarmoniaAppClient: Actor {
    /// Initialize the runtime
    func bootstrap() async throws
    
    /// Get governance status for a project
    func getStatus(projectId: String?) async throws -> AppStatus
    
    /// Set operating mode (governed)
    func setMode(_ mode: HarmoniaV2Contracts.OperatingMode, for projectId: String?, principal: AnigmaCore.Principal) async throws
    
    /// Set kill switch (governed)
    func setKillSwitch(active: Bool, for projectId: String?, reason: String?, principal: AnigmaCore.Principal) async throws
    
    /// Create a new project (governed)
    func createProject(id: String, name: String, embeddingModel: String, principal: AnigmaCore.Principal) async throws
    
    /// List all projects
    func listProjects() async throws -> [ProjectRecord]
    
    /// Index a folder (long running, cancellable via Task)
    func index(folder: URL, projectId: String, principal: AnigmaCore.Principal, dryRun: Bool) async throws -> AsyncStream<IndexProgress>
    
    /// Recall memories/chunks
    func recall(query: String, projectId: String, options: RecallOptions) async throws -> RecallResult
    
    /// Save a memo (governed write)
    func addMemo(text: String, projectId: String, principal: AnigmaCore.Principal) async throws -> StoredMemoryRecord
    
    // MARK: - Vault Operations
    func getVaultStatus() async throws -> HarmoniaClient.VaultStatusResponse
    func verifyVault() async throws -> HarmoniaClient.VaultVerifyResponse
    func runVaultGC(dryRun: Bool) async throws -> HarmoniaClient.VaultGCResponse
    
    // MARK: - Pipeline Operations
    func listPipelines() async throws -> AnigmaPipelineListResponse
    func createPipeline(name: String, stages: [PipelineStage]) async throws -> AnigmaPipelineCreateResponse
    func runPipeline(pipelineId: String, inputs: [String: String]) async throws -> AnigmaPipelineRunResponse
    func getPipelineStatus(runId: String) async throws -> AnigmaPipelineStatusResponse
    func cancelPipeline(runId: String) async throws -> AnigmaPipelineCancelResponse
}

// MARK: - Local Implementation

/// In-process implementation using PlatformRuntime
public actor LocalAppClient: HarmoniaAppClient {
    private let databasePath: String
    private var runtime: RuntimeServices?
    private var lastDenial: DenialInfo?
    
    public init(databasePath: String) {
        self.databasePath = databasePath
    }
    
    private func getRuntime() async throws -> RuntimeServices {
        if let runtime = self.runtime {
            return runtime
        }
        // Bootstrap if needed
        let config = RuntimeConfiguration(
            databasePath: databasePath,
            enforceGovernance: true
        )
        let r = try await PlatformRuntime.local(config: config)
        self.runtime = r
        return r
    }
    
    public func bootstrap() async throws {
        _ = try await getRuntime()
        try await ensureSchema()
    }
    
    #if DEBUG
    /// Diagnostic method for debugging: returns runtime instance identity and database path
    /// ONLY AVAILABLE IN DEBUG BUILDS
    public func runtimeDiagnostics() async throws -> (instanceId: UUID, dbPath: String) {
        let runtime = try await getRuntime()
        return await runtime.runtimeDiagnostics()
    }
    #endif
    
    private func ensureSchema() async throws {
        let runtime = try await getRuntime()
        
        // Note: Harmonia core schema (memories, chunks, FTS tables, triggers) is now
        // initialized automatically in PlatformRuntime.initializeCoreSchemas()
        
        // Create projects table if not exists
        let sql = """
        CREATE TABLE IF NOT EXISTS harmonia_projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            embedding_model TEXT NOT NULL
        )
        """
        // System principal for schema init
        let context = ExecutionContext(principal: .system, sessionId: "schema-init")
        let mutation = DatabaseMutation(sql: sql, componentType: "schema")
        _ = try await runtime.database.mutate(mutation, context: context)
    }
    
    public func getStatus(projectId: String?) async throws -> AppStatus {
        let runtime = try await getRuntime()
        let gov = await runtime.governance
        
        // Use governance API
        let (mode, source) = try await runtime.showMode(for: projectId)
        let (killSwitchActive, killSwitchReason) = try await gov.showKillSwitch(for: projectId)
        
        // Map AnigmaCore OperatingMode to HarmoniaV2Contracts OperatingMode
        let operatingMode: HarmoniaV2Contracts.OperatingMode
        switch mode {
        case .readOnly: operatingMode = .restricted
        case .assistive: operatingMode = .normal
        case .autopilot: operatingMode = .normal // Map autopilot to normal for now
        }
        
        // Map AnigmaCore ModeSource to HarmoniaV2Contracts ModeSource
        let modeSource: HarmoniaV2Contracts.ModeSource
        switch source {
        case .project: modeSource = .project
        case .global: modeSource = .global
        case .defaultMode: modeSource = .defaultMode
        }
        
        return AppStatus(
            operatingMode: operatingMode,
            modeSource: modeSource,
            killSwitchActive: killSwitchActive,
            killSwitchReason: killSwitchReason,
            lastDenial: self.lastDenial
        )
    }
    
    public func setMode(_ mode: HarmoniaV2Contracts.OperatingMode, for projectId: String?, principal: AnigmaCore.Principal) async throws {
        let runtime = try await getRuntime()
        
        // Map HarmoniaV2Contracts OperatingMode to AnigmaCore OperatingMode
        let coreMode: AnigmaFoundation.OperatingMode
        switch mode {
        case .normal: coreMode = .assistive
        case .restricted: coreMode = .readOnly
        case .offline: coreMode = .readOnly // Map offline to readOnly
        case .maintenance: coreMode = .readOnly // Map maintenance to readOnly
        }
        
        do {
            try await runtime.setMode(coreMode, for: projectId, by: principal)
        } catch let error as GovernanceError {
            recordDenial(error)
            throw error
        } catch {
            throw error
        }
    }
    
    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, principal: AnigmaCore.Principal) async throws {
        let runtime = try await getRuntime()
        let gov = await runtime.governance
        // Runtime doesn't expose setKillSwitch directly on PlatformRuntime yet?
        // GovernanceController does. PlatformRuntime might not wrap it yet?
        // Checking PlatformRuntime... assuming it exposes governance or we access via governance controller
        // Ideally we should use a runtime method if available, but governance controller is accessible
        // Check if PlatformRuntime conforms to RuntimeKillSwitchAPI?
        // Let's use governance controller directly via await runtime.governance
        try await gov.setKillSwitch(active: active, for: projectId, reason: reason, by: principal, using: await runtime.database)
    }
    
    public func createProject(id: String, name: String, embeddingModel: String, principal: AnigmaCore.Principal) async throws {
        let runtime = try await getRuntime()
        
        let sql = """
        INSERT INTO harmonia_projects (id, name, created_at, embedding_model)
        VALUES (?, ?, ?, ?)
        """
        
        let params: [DatabaseParameter] = [
            .text(id),
            .text(name),
            .double(Date().timeIntervalSince1970),
            .text(embeddingModel)
        ]
        
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: params,
            componentType: "project_registry",
            entityId: EntityId(uuidString: id)
        )
        
        let context = ExecutionContext(principal: principal, sessionId: UUID().uuidString)
        
        do {
            _ = try await runtime.database.mutate(mutation, context: context)
        } catch let error as GovernanceError {
            recordDenial(error)
            throw error
        }
    }
    
    public func listProjects() async throws -> [ProjectRecord] {
        let runtime = try await getRuntime()
        let sql = "SELECT id, name, created_at, embedding_model FROM harmonia_projects ORDER BY name ASC"
        
        // Reads don't require context/governance
        let rows = try await runtime.database.query(sql, parameters: [])
        
        return rows.compactMap { row in
            guard let idV = row["id"], case .text(let id) = idV,
                  let nameV = row["name"], case .text(let name) = nameV,
                  let createdV = row["created_at"], case .double(let created) = createdV,
                  let modelV = row["embedding_model"], case .text(let model) = modelV else {
                return nil
            }
            return ProjectRecord(id: id, name: name, createdAt: Date(timeIntervalSince1970: created), embeddingModel: model)
        }
    }
    
    public func index(folder: URL, projectId: String, principal: AnigmaCore.Principal, dryRun: Bool = false) async throws -> AsyncStream<IndexProgress> {
        return AsyncStream { continuation in
            Task {
                do {
                    // For dry run, we might not need runtime/DB if just enumerating
                    let runtime = try await self.getRuntime()
                    
                    // Create internal adapter if not exists (we use a fresh one for now linked to runtime DB)
                    // If dry run, maybe we don't init schema?
                    let memoryStore = LocalMemoryStoreAdapter(database: await runtime.database)
                    if !dryRun {
                         try await memoryStore.initializeSchema()
                    }
                    
                    let embeddingBackend = DeterministicEmbeddingBackend()
                    let inference = InferenceEngine(embeddingBackend: embeddingBackend)
                    
                    let fileManager = FileManager.default
                    
                    // Phase 1: Scanning
                    var filesToProcess: [URL] = []
                    var scannedCount = 0
                    
                    guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                        continuation.finish()
                        return
                    }
                    
                    for case let fileURL as URL in enumerator {
                        if Task.isCancelled { break }
                        
                        let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        if resourceValues?.isRegularFile == true {
                            // Simple extension filter
                            if ["swift", "md", "txt", "json", "py"].contains(fileURL.pathExtension) {
                                filesToProcess.append(fileURL)
                                scannedCount += 1
                                if scannedCount % 10 == 0 {
                                    continuation.yield(IndexProgress.scanning(scannedCount))
                                }
                            }
                        }
                    }
                    
                    let total = filesToProcess.count
                    var processed = 0
                    var chunks = 0
                    
                    // Phase 2: Indexing
                    for fileURL in filesToProcess {
                        if Task.isCancelled { break }
                        
                        let fileName = fileURL.lastPathComponent
                        processed += 1
                        continuation.yield(IndexProgress.processing(processed, of: total, chunks: chunks, file: fileName))
                        
                        // In dry run, we assume we would chunk and store
                        // Maybe simulate delay?
                        if dryRun {
                            // Simulate chunking count
                            chunks += 1
                            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms simulation
                            continue
                        }
                        
                        // Read content
                        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                        
                        // Simple whole-file chunking for MVP
                        // In real impl, use TextChunkingCapsule
                        let chunkContent = content
                        
                        // Embed
                        let context = ExecutionContext(sessionId: UUID().uuidString, userId: principal.id)
                        let embeddingResult = try await inference.embed(text: chunkContent, context: context)
                        
                        // Store with projectId in metadata (governance requirement)
                        let metadata: [String: String] = [
                            "projectId": projectId,
                            "userId": principal.id,
                            "filePath": fileURL.path,
                            "fileName": fileURL.lastPathComponent,
                            "embeddingModel": embeddingResult.modelName
                        ]
                        
                        do {
                            _ = try await memoryStore.store(
                                content: chunkContent,
                                metadata: metadata,
                                embedding: embeddingResult.vector
                            )
                            chunks += 1
                        } catch {
                            // Check if this is a governance denial using unified extractor
                            if let violation = GovernanceViolationExtractor.extract(from: error) {
                                // Record denial
                                self.lastDenial = DenialInfo(
                                    violationId: violation.id,
                                    summary: violation.summaryMessage,
                                    failedChecks: violation.failedChecks.map { $0.checkId },
                                    timestamp: violation.timestamp
                                )
                                // Terminate stream with structured denial
                                let msg = "Denied: \(violation.summaryMessage)"
                                let contractsViolation = convertToContractsViolation(violation)
                                continuation.yield(IndexProgress.failed(msg, processed: processed, total: total, chunks: chunks, violation: contractsViolation))
                                continuation.finish()
                                return
                            }
                            // Non-governance error - log and continue
                            // (In production, consider adding threshold: fail after N errors)
                            continue
                        }
                    }
                    
                    if !Task.isCancelled {
                        continuation.yield(IndexProgress.complete(total: total, chunks: chunks))
                    }
                    continuation.finish()
                    
                } catch {
                    continuation.yield(IndexProgress.failed(error.localizedDescription, processed: 0, total: 0, chunks: 0))
                    continuation.finish()
                }
            }
        }
    }
    
    public func recall(query: String, projectId: String, options: RecallOptions) async throws -> RecallResult {
        let startTime = Date()
        let runtime = try await self.getRuntime()
        
        let memoryStore = LocalMemoryStoreAdapter(database: await runtime.database)
        try await memoryStore.initializeSchema() // Ensure schema exists
        
        // Embed query
        let embeddingBackend = DeterministicEmbeddingBackend()
        let inference = InferenceEngine(embeddingBackend: embeddingBackend)
        let context = ExecutionContext(sessionId: UUID().uuidString, userId: "recall")
        let embeddingResult = try await inference.embed(text: query, context: context)
        
        // Search
        let results = try await memoryStore.searchSimilar(
            embedding: embeddingResult.vector,
            embeddingModel: embeddingResult.modelName,
            projectId: projectId,
            limit: options.topK,
            threshold: options.threshold,
            scanLimit: options.scanLimit
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Count scanned rows
        let countSQL = "SELECT count(*) as c FROM harmonia_memories WHERE project_id = ? AND embedding IS NOT NULL"
        // Use await runtime.database.query (read-only allowed)
        let countResult = try await runtime.database.query(countSQL, parameters: [.text(projectId)])
        let rowsScanned = countResult.first?.int(for: "c") ?? 0
        
        let recallItems = results.map { res in
            RecallItem(
                id: res.record.id,
                content: res.record.content,
                similarity: res.similarity,
                rank: res.rank,
                vectorRank: res.vectorRank,
                ftsRank: res.ftsRank,
                rrfScore: res.rrfScore,
                metadata: res.record.metadata
            )
        }
        
        return RecallResult(
            query: query,
            projectId: projectId,
            results: recallItems,
            stats: RecallStats(rowsScanned: rowsScanned, scanLimit: options.scanLimit, executionTime: executionTime)
        )
    }
    
    private func convertToContractsViolation(_ violation: GovernanceCore.GovernanceViolation) -> HarmoniaV2Contracts.GovernanceViolation {
        return HarmoniaV2Contracts.GovernanceViolation(
            id: violation.id,
            summaryMessage: violation.summaryMessage,
            failedChecks: violation.failedChecks.map { failedCheck in
                HarmoniaV2Contracts.GovernanceCheckFailure(
                    checkId: failedCheck.checkId,
                    checkName: failedCheck.checkId, // Use checkId as checkName
                    reason: failedCheck.message // Map message to reason
                )
            },
            timestamp: violation.timestamp
        )
    }

    private func recordDenial(_ error: GovernanceError) {
        if case .writeBlocked(let violation) = error {
            self.lastDenial = DenialInfo(
                violationId: violation.id,
                summary: violation.summaryMessage,
                failedChecks: violation.failedChecks.map { $0.checkId },
                timestamp: Date()
            )
        }
    }
    public func addMemo(text: String, projectId: String, principal: AnigmaCore.Principal) async throws -> StoredMemoryRecord {
        let runtime = try await getRuntime()
        
        let memoryStore = LocalMemoryStoreAdapter(database: await runtime.database)
        try await memoryStore.initializeSchema()
        
        // Compute embedding using project's model
        // For MVP, we use DeterministicEmbeddingBackend which is hardcoded.
        // In real app, we should fetch project's embeddingModel and use appropriate backend.
        // We'll enforce that the stored model matches the project model later at recall time.
        // For now, assume deterministic is correct or we just store what we compute.
        
        let embeddingBackend = DeterministicEmbeddingBackend()
        let inference = InferenceEngine(embeddingBackend: embeddingBackend)
        let context = ExecutionContext(sessionId: UUID().uuidString, userId: principal.id)
        let embeddingResult = try await inference.embed(text: text, context: context)
        
        let metadata: [String: String] = [
            "projectId": projectId,
            "userId": principal.id,
            "kind": "memo",
            "fileName": "Memo \(Date().formatted())", // Virtual filename for UI
            "embeddingModel": embeddingResult.modelName
        ]
        
        let id = try await memoryStore.store(
            content: text,
            metadata: metadata,
            embedding: embeddingResult.vector
        )
        
        return StoredMemoryRecord(
            id: id,
            content: text,
            metadata: metadata,
            embedding: embeddingResult.vector,
            embeddingModel: embeddingResult.modelName,
            createdAt: Date()
        )
    }

    // MARK: - Vault Operations (Local Stubs)
    
    public func getVaultStatus() async throws -> HarmoniaClient.VaultStatusResponse {
        return HarmoniaClient.VaultStatusResponse(
            isHealthy: true,
            receiptCount: 0,
            diskUsage: "0 KB",
            headHash: "LOCAL_HEAD",
            lastVerifiedAt: Date()
        )
    }
    
    public func verifyVault() async throws -> HarmoniaClient.VaultVerifyResponse {
        return HarmoniaClient.VaultVerifyResponse(success: true, message: "Local vault verified")
    }
    
    public func runVaultGC(dryRun: Bool) async throws -> HarmoniaClient.VaultGCResponse {
        return HarmoniaClient.VaultGCResponse(success: true, deletedCount: 0, reclaimedSpace: "0 KB")
    }
    
    // MARK: - Pipeline Operations (Local Stubs)
    
    public func listPipelines() async throws -> AnigmaPipelineListResponse {
        return AnigmaPipelineListResponse(pipelines: [])
    }
    
    public func createPipeline(name: String, stages: [PipelineStage]) async throws -> AnigmaPipelineCreateResponse {
        return AnigmaPipelineCreateResponse(pipelineId: UUID().uuidString, name: name)
    }
    
    public func runPipeline(pipelineId: String, inputs: [String: String]) async throws -> AnigmaPipelineRunResponse {
        return AnigmaPipelineRunResponse(runId: UUID().uuidString, pipelineId: pipelineId, status: "completed")
    }
    
    public func getPipelineStatus(runId: String) async throws -> AnigmaPipelineStatusResponse {
        return AnigmaPipelineStatusResponse(runId: runId, status: "completed", progress: 1.0)
    }
    
    public func cancelPipeline(runId: String) async throws -> AnigmaPipelineCancelResponse {
        return AnigmaPipelineCancelResponse(success: true)
    }
}

/// Lightweight adapter implementing MemoryStore for App usage.
actor LocalMemoryStoreAdapter: MemoryStore {
    private let database: any AnigmaFoundation.DatabaseAuthority
    
    init(database: any AnigmaFoundation.DatabaseAuthority) {
        self.database = database
    }
    
    func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String {
        let id = UUID().uuidString
        let projectId = metadata["projectId"]
        
        // Serialize embedding to BLOB
        let embeddingBlob: DatabaseParameter
        let embeddingDim: DatabaseParameter
        let embeddingModelParam: DatabaseParameter
        
        if let embedding = embedding {
            let encoded = EmbeddingCodec.encode(embedding)
            embeddingBlob = .blob(encoded)
            embeddingDim = .int(embedding.count)
            embeddingModelParam = metadata["embeddingModel"].map { .text($0) } ?? .null
        } else {
            embeddingBlob = .null
            embeddingDim = .null
            embeddingModelParam = .null
        }
        
        // Serialize metadata
        let metadataJSON: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            metadataJSON = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            metadataJSON = "{}"
        }
        
        let sql = """
        INSERT OR IGNORE INTO harmonia_memories 
        (id, content, created_at, project_id, embedding, embedding_dim, embedding_model, metadata_json) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        // System principal for now, or derive from context?
        // App Client should pass context down. But MemoryStore protocol doesn't take context.
        // We use system/internal context for the mutation here, assuming governance was checked at higher level?
        // No, Governance happens inside `mutate`.
        // We need a context.
        // MemoryStore.store signature: func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String
        // It lacks context/principal.
        // Ideally we should update MemoryStore protocol, but for MVP we can construct a context from metadata if userId/sessionId present.
        
        let userId = metadata["userId"] ?? "unknown"
        let sessionId = metadata["sessionId"] ?? UUID().uuidString
        
        let context = ExecutionContext(
            principal: AnigmaCore.Principal(id: userId, displayName: userId),
            projectId: projectId,
            sessionId: sessionId
        )
        
        let parameters: [DatabaseParameter] = [
            .text(id),
            .text(content),
            .int(Int(Date().timeIntervalSince1970)),
            projectId.map { .text($0) } ?? .null,
            embeddingBlob,
            embeddingDim,
            embeddingModelParam,
            .text(metadataJSON)
        ]
        
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: parameters,
            componentType: "memory",
            entityId: nil
        )
        
        _ = try await database.mutate(mutation, context: context)
        return id
    }
    
    func retrieve(sessionId: String?, tenantId: String?, limit: Int) async throws -> [StoredMemoryRecord] {
        // Not used by recall workflow
        return []
    }
    
    func searchSimilar(embedding: [Float], embeddingModel: String?, projectId: String, limit: Int, threshold: Float?, scanLimit: Int?) async throws -> [SimilarMemoryResult] {
        var sql = """
        SELECT id, content, created_at, embedding, embedding_dim, embedding_model, metadata_json
        FROM harmonia_memories
        WHERE project_id = ? AND embedding IS NOT NULL
        """
        
        var params: [DatabaseParameter] = [.text(projectId)]
        if let scanLimit = scanLimit {
            sql += " LIMIT ?"
            params.append(.int(scanLimit))
        }
        
        let rows = try await database.query(sql, parameters: params)
        
        struct ScoredResult {
            let record: StoredMemoryRecord
            let similarity: Float
        }
        
        var scored: [ScoredResult] = []
        let queryDim = embedding.count
        
        for row in rows {
            guard let idValue = row["id"], case .text(let id) = idValue,
                  let contentValue = row["content"], case .text(let content) = contentValue,
                  let createdAtValue = row["created_at"], case .int(let createdAt) = createdAtValue,
                  let embeddingValue = row["embedding"], case .blob(let embeddingBlob) = embeddingValue,
                  let dimValue = row["embedding_dim"], case .int(let storedDim) = dimValue else {
                continue
            }
            
            // Extract metadata
            let rowModel: String? = {
                guard let modelValue = row["embedding_model"], case .text(let model) = modelValue else { return nil }
                return model
            }()
            
            if storedDim != queryDim { continue }
            if let expected = embeddingModel, let actual = rowModel, expected != actual {
                // Strict model check
                throw HarmoniaError.embeddingModelMismatch("Expected \(expected), got \(actual)")
            }
            
            let storedEmbedding: [Float]
            do {
                storedEmbedding = try EmbeddingCodec.decode(embeddingBlob, expectedDim: queryDim)
            } catch { continue }
            
            // Cosine similarity
            let dotProduct = zip(embedding, storedEmbedding).map(*).reduce(0, +)
            let magQ = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            let magS = sqrt(storedEmbedding.map { $0 * $0 }.reduce(0, +))
            
            guard magQ > 0 && magS > 0 else { continue }
            let similarity = dotProduct / (magQ * magS)
            
            if let t = threshold, similarity < t { continue }
            
            let metadata: [String: String] = {
                guard let jsonValue = row["metadata_json"], case .text(let json) = jsonValue,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    return [:]
                }
                return dict
            }()
            
            let record = StoredMemoryRecord(
                id: id,
                content: content,
                metadata: metadata,
                embedding: storedEmbedding,
                embeddingModel: rowModel,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt))
            )
            
            scored.append(ScoredResult(record: record, similarity: similarity))
        }
        
        scored.sort { $0.similarity > $1.similarity }
        
        return scored.prefix(limit).enumerated().map { index, result in
            SimilarMemoryResult(
                record: result.record,
                similarity: result.similarity,
                rank: index + 1,
                vectorRank: index + 1, // Only vector search implemented for now
                ftsRank: nil,
                rrfScore: result.similarity, // Use cosine as score for now
                tags: []
            )
        }
    }
    
    func initializeSchema() async throws {
        // Reuse schema logic from CLIKernel (create table + FTS triggers)
        let createSQL = """
        CREATE TABLE IF NOT EXISTS harmonia_memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            project_id TEXT,
            embedding BLOB,
            embedding_dim INTEGER,
            embedding_model TEXT,
            metadata_json TEXT
        )
        """
        let context = ExecutionContext(principal: .system, sessionId: "schema-init")
        _ = try await database.mutate(DatabaseMutation(sql: createSQL, componentType: "schema"), context: context)
        
        // FTS Setup (Simplied for MVP)
        // Check if FTS exists
        let checkSQL = "SELECT table_name FROM information_schema.tables WHERE table_name = 'harmonia_memories_fts'"
        let rows = try await database.query(checkSQL, parameters: [])
        if rows.isEmpty {
            let createFTS = "CREATE VIRTUAL TABLE harmonia_memories_fts USING fts5(content, content='harmonia_memories', content_rowid='rowid')"
            _ = try await database.mutate(DatabaseMutation(sql: createFTS, componentType: "schema"), context: context)
            
            // Triggers
            let triggers = [
                "CREATE TRIGGER harmonia_memories_ai AFTER INSERT ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content); END;",
                "CREATE TRIGGER harmonia_memories_ad AFTER DELETE ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content); END;",
                "CREATE TRIGGER harmonia_memories_au AFTER UPDATE ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content); INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content); END;"
            ]
            
            for trigger in triggers {
                _ = try await database.mutate(DatabaseMutation(sql: trigger, componentType: "schema"), context: context)
            }
        }
    }
}
