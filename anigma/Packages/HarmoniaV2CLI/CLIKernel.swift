//
//  CLIKernel.swift
//  HarmoniaV2CLI - Testable kernel functions
//
//  Separates parsing from execution for integration testing
//

import Foundation
import HarmoniaV2Core
import HarmoniaV2Memory
import HarmoniaV2Inference
import AnigmaCore
import AnigmaFoundation
import ContractsCore
import GovernanceCore
import DatabaseCore

// MARK: - Simple Memory Store Adapter

/// Lightweight adapter implementing MemoryStore for CLI usage.
/// In production, this would live in a runtime integration module.
actor SimpleMemoryStoreAdapter: MemoryStore {
    private let database: any AnigmaFoundation.DatabaseAuthority
    
    init(database: any AnigmaFoundation.DatabaseAuthority) {
        self.database = database
    }
    
    func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String {
        let id = UUID().uuidString
        
        let userId = metadata["userId"] ?? "unknown"
        let projectId = metadata["tenantId"]  // MemoryManager uses "tenantId" key
        let sessionId = metadata["sessionId"] ?? UUID().uuidString
        let embeddingModel = metadata["embeddingModel"]
        
        let context = ExecutionContext(
            principal: Principal(id: userId, displayName: userId),
            projectId: projectId,
            sessionId: sessionId
        )
        
        // Serialize embedding to BLOB if present
        let embeddingBlob: DatabaseParameter
        let embeddingDim: DatabaseParameter
        let embeddingModelParam: DatabaseParameter
        
        if let embedding = embedding {
            let encoded = EmbeddingCodec.encode(embedding)
            embeddingBlob = .blob(encoded)
            embeddingDim = .int(embedding.count)
            embeddingModelParam = embeddingModel.map { .text($0) } ?? .null
        } else {
            embeddingBlob = .null
            embeddingDim = .null
            embeddingModelParam = .null
        }
        
        // Serialize metadata to JSON
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
        
        // This goes through governance!
        _ = try await database.mutate(mutation, context: context)
        
        return id
    }
    
    func retrieve(sessionId: String?, tenantId: String?, limit: Int) async throws -> [StoredMemoryRecord] {
        return []
    }
    
    func searchSimilar(embedding: [Float], embeddingModel: String? = nil, projectId: String, limit: Int, threshold: Float?, scanLimit: Int? = nil) async throws -> [SimilarMemoryResult] {
        // Query all memories for this project that have embeddings
        var sql = """
        SELECT id, content, created_at, embedding, embedding_dim, embedding_model, metadata_json
        FROM harmonia_memories
        WHERE project_id = ? AND embedding IS NOT NULL
        """
        
        var params: [DatabaseParameter] = [.text(projectId)]
        
        // Apply scan limit for safety (O(n) bound)
        if let scanLimit = scanLimit {
            sql += " LIMIT ?"
            params.append(.int(scanLimit))
        }
        
        let rows = try await database.query(sql, parameters: params)
        
        // Decode embeddings and compute cosine similarity
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
            
            // Verify dimension matches
            guard storedDim == queryDim else {
                // Skip mismatched dimensions (could throw, but skip for robustness)
                continue
            }
            
            // Verify model matches (Strict Check)
            if let expectedModel = embeddingModel, let storedModel = rowModel {
                if expectedModel != storedModel {
                     throw HarmoniaError.embeddingModelMismatch("Project \(projectId) mixed models: Expected \(expectedModel), found \(storedModel) in memory \(id)")
                }
            }
            
            // Decode embedding
            let storedEmbedding: [Float]
            do {
                storedEmbedding = try EmbeddingCodec.decode(embeddingBlob, expectedDim: queryDim)
            } catch {
                // Skip corrupt embeddings
                continue
            }
            
            // Compute cosine similarity
            let dotProduct = zip(embedding, storedEmbedding).map(*).reduce(0, +)
            let magnitudeQuery = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            let magnitudeStored = sqrt(storedEmbedding.map { $0 * $0 }.reduce(0, +))
            
            guard magnitudeQuery > 0 && magnitudeStored > 0 else { continue }
            
            let similarity = dotProduct / (magnitudeQuery * magnitudeStored)
            
            // Apply threshold if provided
            if let threshold = threshold, similarity < threshold {
                continue
            }
            
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
        
        // Sort by similarity descending, then id ascending (stable tie-break)
        scored.sort { lhs, rhs in
            if abs(lhs.similarity - rhs.similarity) < 0.0001 {
                return lhs.record.id < rhs.record.id
            }
            return lhs.similarity > rhs.similarity
        }
        
        // Take top K and convert to SimilarMemoryResult
        let topK = scored.prefix(limit)
        return topK.enumerated().map { index, result in
            SimilarMemoryResult(
                record: result.record,
                similarity: result.similarity,
                rank: index + 1
            )
        }
    }
    
    func initializeSchema() async throws {
        // Create base table
        let createSQL = """
        CREATE TABLE IF NOT EXISTS harmonia_memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
        """
        
        let context = ExecutionContext(
            principal: .system,
            projectId: nil,
            sessionId: "schema-init"
        )
        
        let mutation = DatabaseMutation(
            sql: createSQL,
            parameters: [],
            componentType: "schema",
            entityId: nil
        )
        
        _ = try await database.mutate(mutation, context: context)
        
        // Add columns idempotently (check existence first)
        try await ensureColumn("project_id", type: "TEXT")
        try await ensureColumn("embedding", type: "BLOB")
        try await ensureColumn("embedding_dim", type: "INTEGER")
        try await ensureColumn("embedding_model", type: "TEXT")
        try await ensureColumn("metadata_json", type: "TEXT")
        
        // Setup FTS
        try await setupFTS()
    }
    
    private func setupFTS() async throws {
        let context = ExecutionContext(principal: .system, projectId: nil, sessionId: "schema-fts")
        
        // 1. Check if FTS table exists
        let checkSQL = "SELECT to_regclass('public.harmonia_memories_fts')"
        let rows = try await database.query(checkSQL, parameters: [])
        var createdTable = false
        
        if rows.isEmpty {
            // Create FTS table (external content)
            // Note: content_rowid is 'rowid' which refers to standard integer rowid of harmonia_memories
            let createFTS = "CREATE VIRTUAL TABLE harmonia_memories_fts USING fts5(content, content='harmonia_memories', content_rowid='rowid')"
            
            // We use mutate for DDL
            _ = try await database.mutate(DatabaseMutation(sql: createFTS, parameters: [], componentType: "schema", entityId: nil), context: context)
            createdTable = true
        }
        
        // 2. Ensure Triggers (Self-healing: Create if missing)
        let triggers = [
            ("harmonia_memories_ai", """
            CREATE TRIGGER harmonia_memories_ai AFTER INSERT ON harmonia_memories BEGIN
              INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content);
            END;
            """),
            ("harmonia_memories_ad", """
            CREATE TRIGGER harmonia_memories_ad AFTER DELETE ON harmonia_memories BEGIN
              INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content);
            END;
            """),
            ("harmonia_memories_au", """
            CREATE TRIGGER harmonia_memories_au AFTER UPDATE ON harmonia_memories BEGIN
              INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content);
              INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content);
            END;
            """)
        ]
        
        for (name, sql) in triggers {
            let checkTrigger = "SELECT tgname FROM pg_trigger WHERE tgname = ? AND NOT tgisinternal"
            let existing = try await database.query(checkTrigger, parameters: [DatabaseParameter.text(name)])
            
            if existing.isEmpty {
                 _ = try await database.mutate(DatabaseMutation(sql: sql, parameters: [], componentType: "schema", entityId: nil), context: context)
            }
        }
        
        // 3. Initial population (Only if we created the table)
        if createdTable {
            let populate = "INSERT INTO harmonia_memories_fts(rowid, content) SELECT rowid, content FROM harmonia_memories"
            _ = try await database.mutate(DatabaseMutation(sql: populate, parameters: [], componentType: "schema", entityId: nil), context: context)
        }
    }
    
    func rebuildFTS(for projectId: String?) async throws -> Int {
        // Governance check implicit via mutate
        let context = ExecutionContext(
            principal: Principal(id: "maintenance", displayName: "FTS Maintenance"),
            projectId: projectId,
            sessionId: "fts-rebuild"
        )
        
        // 1. Clear existing FTS data
        // For external content tables, 'rebuild' command or delete all is standard.
        // Since we have triggers, deleting from the materialized search surface directly is safer than a rebuild shortcut.
        // But let's do manual wipe and repopulate to be sure and respect project scope if possible.
        // FTS external content tables are tricky with partial rebuilds.
        // Best practice for 'rebuild' is the magic command.
        
        if let pid = projectId {
            // Scoped rebuild is harder with FTS5 external content.
            // We have to delete entries for this project from FTS index manually.
            // rowid is shared.
            
            // Delete from FTS where rowid corresponds to project
            // Note: FTS delete syntax: INSERT INTO t(t, rowid, content) VALUES('delete', rowid, content)
            // But with external content, we can just delete from FTS table using rowid?
            // "DELETE FROM fts_table WHERE rowid = ?" works.
            
            let deleteSQL = """
            DELETE FROM harmonia_memories_fts 
            WHERE rowid IN (SELECT rowid FROM harmonia_memories WHERE project_id = ?)
            """
            _ = try await database.mutate(DatabaseMutation(sql: deleteSQL, parameters: [.text(pid)], componentType: "maintenance"), context: context)
            
            // Re-insert
            let insertSQL = """
            INSERT INTO harmonia_memories_fts(rowid, content) 
            SELECT rowid, content FROM harmonia_memories WHERE project_id = ?
            """
            _ = try await database.mutate(DatabaseMutation(sql: insertSQL, parameters: [.text(pid)], componentType: "maintenance"), context: context)
            
            // Count rows to report
            let countRows = try await database.query("SELECT count(*) as c FROM harmonia_memories WHERE project_id = ?", parameters: [.text(pid)])
            return countRows.first?.int(for: "c") ?? 0
            
        } else {
            // Global rebuild
            let rebuildSQL = "INSERT INTO harmonia_memories_fts(harmonia_memories_fts) VALUES('rebuild')"
            _ = try await database.mutate(DatabaseMutation(sql: rebuildSQL, parameters: [], componentType: "maintenance"), context: context)
            // Rows affected for rebuild command is often 0 or undefined, so we query count
            
            let countRows = try await database.query("SELECT count(*) as c FROM harmonia_memories_fts", parameters: [])
            return countRows.first?.int(for: "c") ?? 0
        }
    }

    // Keyword Search Result
    struct KeywordResult {
        let id: String
        let content: String
        let rank: Float
    }
    
    func searchKeyword(query: String, projectId: String, limit: Int) async throws -> [KeywordResult] {
        // FTS Match query
        // Escape quotes to prevent SQL injection in FTS syntax if needed, though parameters handle SQL injection.
        // FTS syntax injection is possible inside the parameter string (e.g. OR, NOT).
        // For MVP we wrap in quotes to treat as phrase or exact match.
        let ftsQuery = "\"\(query)\""
        
        let sql = """
        SELECT m.id, m.content, harmonia_memories_fts.rank 
        FROM harmonia_memories_fts 
        JOIN harmonia_memories m ON m.rowid = harmonia_memories_fts.rowid 
        WHERE harmonia_memories_fts MATCH ? AND m.project_id = ? 
        ORDER BY harmonia_memories_fts.rank 
        LIMIT ?
        """
        
        let rows = try await database.query(sql, parameters: [.text(ftsQuery), .text(projectId), .int(limit)])
        
        return rows.compactMap { row in
            guard let idV = row["id"], case .text(let id) = idV,
                  let contentV = row["content"], case .text(let content) = contentV else { return nil }
            
            // Handle rank (might be double or other numeric)
            let rank: Float
            if let rankV = row["rank"] {
                switch rankV {
                case .double(let d): rank = Float(d)
                case .int(let i): rank = Float(i)
                default: rank = 0
                }
            } else {
                rank = 0
            }
            
            return KeywordResult(id: id, content: content, rank: rank)
        }
    }
    
    private func ensureColumn(_ columnName: String, type: String) async throws {
        // Check if column exists via PRAGMA table_info
        let rows = try await database.query("PRAGMA table_info(harmonia_memories)", parameters: [])
        
        let columnExists = rows.contains { row in
            guard let nameValue = row["name"], case .text(let name) = nameValue else { return false }
            return name == columnName
        }
        
        if !columnExists {
            let alterSQL = "ALTER TABLE harmonia_memories ADD COLUMN \(columnName) \(type)"
            let context = ExecutionContext(
                principal: .system,
                projectId: nil,
                sessionId: "schema-migration"
            )
            
            let mutation = DatabaseMutation(
                sql: alterSQL,
                parameters: [],
                componentType: "schema",
                entityId: nil
            )
            
            _ = try await database.mutate(mutation, context: context)
        }
    }
}

// MARK: - CLI Kernel Types

/// Result of a memo operation
public struct MemoResult: Sendable {
    public let memoryId: String
    public let userId: String
    public let projectId: String?
    public let sessionId: String
    
    public init(memoryId: String, userId: String, projectId: String?, sessionId: String) {
        self.memoryId = memoryId
        self.userId = userId
        self.projectId = projectId
        self.sessionId = sessionId
    }
}

/// Result of a recall operation
public struct RecallResult: Sendable {
    public let query: String
    public let projectId: String
    public let results: [(id: String, content: String, similarity: Float, rank: Int)]
    public let stats: RecallStats?
    
    public struct RecallStats: Sendable {
        public let rowsScanned: Int
        public let scanLimit: Int?
        public let executionTime: TimeInterval
        
        public init(rowsScanned: Int, scanLimit: Int? = nil, executionTime: TimeInterval) {
            self.rowsScanned = rowsScanned
            self.scanLimit = scanLimit
            self.executionTime = executionTime
        }
    }
    
    public init(query: String, projectId: String, results: [(id: String, content: String, similarity: Float, rank: Int)], stats: RecallStats? = nil) {
        self.query = query
        self.projectId = projectId
        self.results = results
        self.stats = stats
    }
}

/// Configuration for CLI kernel operations
public struct CLIKernelConfig: Sendable {
    public let databasePath: String
    public let enforceGovernance: Bool
    
    public init(databasePath: String, enforceGovernance: Bool = true) {
        self.databasePath = databasePath
        self.enforceGovernance = enforceGovernance
    }
}

/// Testable CLI kernel functions (no ArgumentParser dependency)
public enum CLIKernel {
    
    /// Run memo command with explicit dependencies
    /// Returns memory ID on success, throws on governance denial or error
    public static func runMemo(
        content: String,
        userId: String,
        projectId: String?,
        sessionId: String?,
        config: CLIKernelConfig
    ) async throws -> MemoResult {
        // Create runtime with governance configuration using factory method
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: config.enforceGovernance,
            principalId: userId
        )
        
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Create memory store adapter (uses nonisolated property to access underlying authority)
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        try await memoryStore.initializeSchema()
        
        // Create inference engine with deterministic stub for MVP
        let embeddingBackend = DeterministicEmbeddingBackend(modelName: "text-embedding-stub-256", dimensions: 256)
        let inferenceEngine = InferenceEngine(embeddingBackend: embeddingBackend)
        
        // Compute embedding for content
        let sessionIdToUse = sessionId ?? UUID().uuidString
        let embeddingResult = try await inferenceEngine.embed(
            text: content,
            context: ExecutionContext(sessionId: sessionIdToUse, userId: userId)
        )
        
        // Store directly with embedding (bypass MemoryManager for MVP)
        let metadata: [String: String] = [
            "tenantId": projectId ?? "default",
            "sessionId": sessionIdToUse,
            "userId": userId,
            "embeddingModel": embeddingResult.modelName
        ]
        
        let memoryId = try await memoryStore.store(
            content: content,
            metadata: metadata,
            embedding: embeddingResult.vector
        )
        
        return MemoResult(
            memoryId: memoryId,
            userId: userId,
            projectId: projectId,
            sessionId: sessionIdToUse
        )
    }
    
    /// Run recall command to search similar memories
    public static func runRecall(
        query: String,
        projectId: String,
        topK: Int = 5,
        threshold: Float? = nil,
        scanLimit: Int? = nil,
        config: CLIKernelConfig
    ) async throws -> RecallResult {
        let startTime = Date()
        
        // Create runtime (read-only operation, no governance enforcement needed for reads)
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: false  // Reads don't need governance
        )
        
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Create memory store adapter
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        try await memoryStore.initializeSchema()
        
        // Create inference engine with same deterministic backend
        let embeddingBackend = DeterministicEmbeddingBackend(modelName: "text-embedding-stub-256", dimensions: 256)
        let inferenceEngine = InferenceEngine(embeddingBackend: embeddingBackend)
        
        // Compute query embedding
        let embeddingResult = try await inferenceEngine.embed(
            text: query,
            context: ExecutionContext(sessionId: UUID().uuidString, userId: "recall-user")
        )
        
        // Search similar memories
        let similarMemories = try await memoryStore.searchSimilar(
            embedding: embeddingResult.vector,
            embeddingModel: embeddingResult.modelName,
            projectId: projectId,
            limit: topK,
            threshold: threshold,
            scanLimit: scanLimit
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Count scanned rows (O(n) scan means all rows for project with embedding)
        let countSQL = "SELECT count(*) as c FROM harmonia_memories WHERE project_id = ? AND embedding IS NOT NULL"
        let countResult = try await runtime.database.query(countSQL, parameters: [.text(projectId)])
        let rowsScanned = countResult.first?.int(for: "c") ?? 0
        
        // Convert to result format
        let results: [(id: String, content: String, similarity: Float, rank: Int)] = similarMemories.map { result in
            (
                id: result.record.id,
                content: result.record.content,
                similarity: result.similarity,
                rank: result.rank
            )
        }
        
        return RecallResult(
            query: query,
            projectId: projectId,
            results: results,
            stats: RecallResult.RecallStats(rowsScanned: rowsScanned, scanLimit: scanLimit, executionTime: executionTime)
        )
    }

    /// Run maintenance command to rebuild FTS index
    public static func runRebuildFTS(
        projectId: String?,
        config: CLIKernelConfig
    ) async throws -> Int {
        // Create runtime with governance (this is a WRITE operation)
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: config.enforceGovernance,
            principalId: "maintenance-admin"
        )
        
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Create memory store adapter
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        
        // Run rebuild
        return try await memoryStore.rebuildFTS(for: projectId)
    }
    
    /// Get row count from database (for testing)
    public static func getRowCount(databasePath: String, table: String) async throws -> Int {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: false
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Query database directly for row count
        let sql = "SELECT COUNT(*) as count FROM \(table)"
        let result = try await runtime.database.query(sql, parameters: [])
        let count = result.first?.int(for: "count") ?? 0
        return count
    }
    
    // MARK: - Governance Mode Commands
    
    /// Presentation type for mode source (for CLI display)
    /// Maps from canonical AnigmaFoundation.Runtime.GovernanceTypes.ModeSource
    public enum ModeSourceView: String, Sendable {
        case project = "project"
        case global = "global"
        case defaultMode = "default"
        
        init?(_ source: ModeSource) {
            switch source {
            case .project:
                self = .project
            case .global:
                self = .global
            case .defaultMode:
                self = .defaultMode
            }
        }
    }
    
    /// Result of mode show operation
    public struct ModeShowResult: Sendable {
        public let effectiveMode: OperatingMode
        public let source: ModeSourceView
        public let projectId: String?
        
        public init(effectiveMode: OperatingMode, source: ModeSourceView, projectId: String?) {
            self.effectiveMode = effectiveMode
            self.source = source
            self.projectId = projectId
        }
    }
    
    /// Set governance operating mode (global or project-scoped)
    public static func runSetMode(
        mode: OperatingMode,
        projectId: String?,
        principal: String,
        databasePath: String
    ) async throws {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true,
            principalId: principal
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let principalObj = Principal(id: principal, displayName: principal)
        
        try await runtime.setMode(mode, for: projectId, by: principalObj)
    }
    
    /// Show effective mode for a project or global
    public static func runShowMode(
        projectId: String?,
        databasePath: String
    ) async throws -> ModeShowResult {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let (effectiveMode, source) = try await runtime.showMode(for: projectId)
        
        guard let sourceView = ModeSourceView(source) else {
            throw RuntimeInitializationError.configurationError("Invalid mode source: \(source)")
        }
        
        return ModeShowResult(
            effectiveMode: effectiveMode,
            source: sourceView,
            projectId: projectId
        )
    }
    
    /// Clear project-specific mode override (revert to global)
    public static func runClearMode(
        projectId: String,
        principal: String,
        databasePath: String
    ) async throws {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true,
            principalId: principal
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let principalObj = Principal(id: principal, displayName: principal)
        
        try await runtime.clearMode(for: projectId, by: principalObj)
    }
    
    // MARK: - Chunk Operations
    
    /// Result of chunk indexing
    public struct ChunkIndexResult: Sendable {
        public let chunkIds: [String]
        public let count: Int
        
        public init(chunkIds: [String], count: Int) {
            self.chunkIds = chunkIds
            self.count = count
        }
    }
    
    /// Result of chunk recall
    public struct ChunkRecallResult: Sendable {
        public let query: String
        public let projectId: String
        public let results: [(id: String, content: String, filePath: String, range: String, similarity: Float)]
        public let stats: Stats?
        
        public struct Stats: Sendable {
            public let rowsScanned: Int
            public let scanLimit: Int?
            public let executionTime: TimeInterval
            public init(rowsScanned: Int, scanLimit: Int? = nil, executionTime: TimeInterval) {
                self.rowsScanned = rowsScanned
                self.scanLimit = scanLimit
                self.executionTime = executionTime
            }
        }
        
        public init(query: String, projectId: String, results: [(id: String, content: String, filePath: String, range: String, similarity: Float)], stats: Stats? = nil) {
            self.query = query
            self.projectId = projectId
            self.results = results
            self.stats = stats
        }
    }
    
    /// Index chunks from content
    public static func runIndexChunks(
        content: String,
        filePath: String,
        projectId: String,
        userId: String,
        config: CLIKernelConfig
    ) async throws -> ChunkIndexResult {
        // Create runtime with governance
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: config.enforceGovernance,
            principalId: userId
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Create chunk store
        let chunkStore = SimpleChunkStoreAdapter(database: runtime.database)
        try await chunkStore.initializeSchema()
        
        // Chunk content
        let chunks = Chunker.chunk(content: content, filePath: filePath, projectId: projectId)
        
        // Inference engine
        let embeddingBackend = DeterministicEmbeddingBackend(modelName: "text-embedding-stub-256", dimensions: 256)
        let inferenceEngine = InferenceEngine(embeddingBackend: embeddingBackend)
        
        var chunkIds: [String] = []
        
        for chunk in chunks {
            // Embed
            let embeddingResult = try await inferenceEngine.embed(
                text: chunk.content,
                context: ExecutionContext(sessionId: UUID().uuidString, userId: userId)
            )
            
            // Store
            let id = try await chunkStore.store(
                chunk: chunk,
                embedding: embeddingResult.vector,
                embeddingModel: embeddingResult.modelName
            )
            chunkIds.append(id)
        }
        
        return ChunkIndexResult(chunkIds: chunkIds, count: chunkIds.count)
    }
    
    /// Recall chunks
    public static func runRecallChunks(
        query: String,
        projectId: String,
        topK: Int = 5,
        scanLimit: Int? = nil,
        config: CLIKernelConfig
    ) async throws -> ChunkRecallResult {
        let startTime = Date()
        
        // Create runtime (no governance for reads)
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: false
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Create chunk store
        let chunkStore = SimpleChunkStoreAdapter(database: runtime.database)
        try await chunkStore.initializeSchema()
        
        // Inference
        let embeddingBackend = DeterministicEmbeddingBackend(modelName: "text-embedding-stub-256", dimensions: 256)
        let inferenceEngine = InferenceEngine(embeddingBackend: embeddingBackend)
        
        let embeddingResult = try await inferenceEngine.embed(
            text: query,
            context: ExecutionContext(sessionId: UUID().uuidString, userId: "recall-user")
        )
        
        // Search
        let similarChunks = try await chunkStore.searchSimilar(
            embedding: embeddingResult.vector,
            embeddingModel: embeddingResult.modelName,
            projectId: projectId,
            limit: topK,
            threshold: nil,
            scanLimit: scanLimit
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Count scanned rows
        let countSQL = "SELECT count(*) as c FROM harmonia_chunks WHERE project_id = ? AND embedding IS NOT NULL"
        let countResult = try await runtime.database.query(countSQL, parameters: [.text(projectId)])
        let rowsScanned = countResult.first?.int(for: "c") ?? 0
        
        // Format
        let results = similarChunks.map { result in
            (
                id: result.record.id,
                content: result.record.chunk.content,
                filePath: result.record.chunk.filePath,
                range: "\(result.record.chunk.startLine)-\(result.record.chunk.endLine)",
                similarity: result.similarity
            )
        }
        
        return ChunkRecallResult(
            query: query,
            projectId: projectId,
            results: results,
            stats: ChunkRecallResult.Stats(rowsScanned: rowsScanned, scanLimit: scanLimit, executionTime: executionTime)
        )
    }
    
    // MARK: - Hybrid Search
    
    /// Result of hybrid recall
    public struct HybridRecallResult: Sendable {
        public let query: String
        public let projectId: String
        public let results: [Item]
        
        // Timing Metrics
        public let embeddingTime: TimeInterval
        public let dbQueryTime: TimeInterval
        public let fusionTime: TimeInterval
        public let totalTime: TimeInterval
        public let rowsScanned: Int
        public let scanLimit: Int?
        public let embeddingModel: String
        
        public struct Item: Sendable {
            public let id: String
            public let content: String
            public let score: Float
            public let tags: [String]
            public let vectorRank: Int?
            public let ftsRank: Int?
            public let rrfScore: Float?
        }
        
        public init(
            query: String,
            projectId: String,
            results: [Item],
            embeddingTime: TimeInterval,
            dbQueryTime: TimeInterval,
            fusionTime: TimeInterval,
            totalTime: TimeInterval,
            rowsScanned: Int,
            scanLimit: Int? = nil,
            embeddingModel: String = "text-embedding-stub-256"
        ) {
            self.query = query
            self.projectId = projectId
            self.results = results
            self.embeddingTime = embeddingTime
            self.dbQueryTime = dbQueryTime
            self.fusionTime = fusionTime
            self.totalTime = totalTime
            self.rowsScanned = rowsScanned
            self.scanLimit = scanLimit
            self.embeddingModel = embeddingModel
        }
    }
    
    /// Run hybrid recall (vector + keyword)
    public static func runHybridRecall(
        query: String,
        projectId: String,
        topK: Int = 5,
        alpha: Float = 0.5,
        scanLimit: Int? = nil,
        config: CLIKernelConfig
    ) async throws -> HybridRecallResult {
        let startTime = Date()
        
        let kernelConfig = PlatformRuntime.KernelConfig(databasePath: config.databasePath, enforceGovernance: false)
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        try await memoryStore.initializeSchema()
        
        // 1. Vector Search
        let embeddingStart = Date()
        let embeddingBackend = DeterministicEmbeddingBackend(modelName: "text-embedding-stub-256", dimensions: 256)
        let inferenceEngine = InferenceEngine(embeddingBackend: embeddingBackend)
        let embeddingResult = try await inferenceEngine.embed(
            text: query,
            context: ExecutionContext(sessionId: UUID().uuidString, userId: "hybrid-user")
        )
        let embeddingDuration = Date().timeIntervalSince(embeddingStart)
        
        // 2. Database Queries
        let dbStart = Date()
        let vectorResults = try await memoryStore.searchSimilar(
            embedding: embeddingResult.vector,
            embeddingModel: embeddingResult.modelName,
            projectId: projectId,
            limit: topK * 2, // Fetch more for re-ranking
            threshold: nil,
            scanLimit: scanLimit
        )
        
        let keywordResults = try await memoryStore.searchKeyword(
            query: query,
            projectId: projectId,
            limit: topK * 2
        )
        let dbDuration = Date().timeIntervalSince(dbStart)
        
        // 3. Merge (RRF - Reciprocal Rank Fusion)
        let fusionStart = Date()
        
        var fusedScores: [String: Float] = [:]
        var details: [String: (content: String, tags: Set<String>, vectorRank: Int?, ftsRank: Int?)] = [:]
        let k: Float = 60.0
        
        for (index, item) in vectorResults.enumerated() {
            let rank = index + 1
            let score = 1.0 / (k + Float(rank))
            fusedScores[item.record.id, default: 0] += score
            details[item.record.id] = (item.record.content, ["vector"], rank, nil)
        }
        
        for (index, item) in keywordResults.enumerated() {
            let rank = index + 1
            let score = 1.0 / (k + Float(rank))
            fusedScores[item.id, default: 0] += score
            if var detail = details[item.id] {
                detail.tags.insert("keyword")
                detail.ftsRank = rank
                details[item.id] = detail
            } else {
                details[item.id] = (item.content, ["keyword"], nil, rank)
            }
        }
        
        // Sort
        let sortedIds = fusedScores.keys.sorted { fusedScores[$0]! > fusedScores[$1]! }
        
        let finalResults = sortedIds.prefix(topK).map { id -> HybridRecallResult.Item in
            let score = fusedScores[id]!
            let detail = details[id]!
            return HybridRecallResult.Item(
                id: id,
                content: detail.content,
                score: score,
                tags: Array(detail.tags).sorted(),
                vectorRank: detail.vectorRank,
                ftsRank: detail.ftsRank,
                rrfScore: score
            )
        }
        let fusionDuration = Date().timeIntervalSince(fusionStart)
        let totalDuration = Date().timeIntervalSince(startTime)
        
        // Count scanned rows
        let countSQL = "SELECT count(*) as c FROM harmonia_memories WHERE project_id = ? AND embedding IS NOT NULL"
        let countResult = try await runtime.database.query(countSQL, parameters: [.text(projectId)])
        let rowsScanned = countResult.first?.int(for: "c") ?? 0
        
        return HybridRecallResult(
            query: query,
            projectId: projectId,
            results: finalResults,
            embeddingTime: embeddingDuration,
            dbQueryTime: dbDuration,
            fusionTime: fusionDuration,
            totalTime: totalDuration,
            rowsScanned: rowsScanned,
            scanLimit: scanLimit,
            embeddingModel: embeddingResult.modelName
        )
    }
    
    // MARK: - Kill Switch Commands
    
    /// Set kill switch (activate)
    public static func runKillSwitchSet(
        projectId: String?,
        reason: String,
        principal: String,
        databasePath: String
    ) async throws {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true,
            principalId: principal
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let principalObj = Principal(id: principal, displayName: principal)
        
        try await runtime.setKillSwitch(active: true, for: projectId, reason: reason, by: principalObj)
    }
    
    /// Clear kill switch (deactivate)
    public static func runKillSwitchClear(
        projectId: String?,
        principal: String,
        databasePath: String
    ) async throws {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true,
            principalId: principal
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let principalObj = Principal(id: principal, displayName: principal)
        
        try await runtime.setKillSwitch(active: false, for: projectId, reason: "Manual clear", by: principalObj)
    }
    
    /// Show kill switch status
    public static func runKillSwitchShow(
        projectId: String?,
        databasePath: String
    ) async throws -> KillSwitchShowResult {
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: databasePath,
            enforceGovernance: true
        )
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        let (active, reason) = try await runtime.showKillSwitch(for: projectId)
        
        return KillSwitchShowResult(
            active: active,
            reason: reason,
            projectId: projectId
        )
    }
}

/// Result of kill switch show operation
public struct KillSwitchShowResult: Sendable {
    public let active: Bool
    public let reason: String?
    public let projectId: String?
    
    public init(active: Bool, reason: String?, projectId: String?) {
        self.active = active
        self.reason = reason
        self.projectId = projectId
    }
}

// MARK: - Simple Chunk Store Adapter

actor SimpleChunkStoreAdapter: ChunkStore {
    private let database: any AnigmaFoundation.DatabaseAuthority
    
    init(database: any AnigmaFoundation.DatabaseAuthority) {
        self.database = database
    }
    
    func store(chunk: Chunk, embedding: [Float]?, embeddingModel: String?) async throws -> String {
        let id = UUID().uuidString
        let context = ExecutionContext(
            principal: Principal(id: "system", displayName: "system"),
            projectId: chunk.projectId,
            sessionId: "chunk-store"
        )
        
        // Serialize embedding
        let embeddingBlob: DatabaseParameter
        let embeddingDim: DatabaseParameter
        let embeddingModelParam: DatabaseParameter
        
        if let embedding = embedding {
            let encoded = EmbeddingCodec.encode(embedding)
            embeddingBlob = .blob(encoded)
            embeddingDim = .int(embedding.count)
            embeddingModelParam = embeddingModel.map { .text($0) } ?? .null
        } else {
            embeddingBlob = .null
            embeddingDim = .null
            embeddingModelParam = .null
        }
        
        let sql = """
        INSERT OR IGNORE INTO harmonia_chunks 
        (id, project_id, content, file_path, start_line, end_line, content_hash, embedding, embedding_dim, embedding_model, created_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(id),
            .text(chunk.projectId),
            .text(chunk.content),
            .text(chunk.filePath),
            .int(chunk.startLine),
            .int(chunk.endLine),
            .text(chunk.contentHash),
            embeddingBlob,
            embeddingDim,
            embeddingModelParam,
            .int(Int(Date().timeIntervalSince1970))
        ]
        
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: parameters,
            componentType: "chunk",
            entityId: nil
        )
        
        // Governance check!
        _ = try await database.mutate(mutation, context: context)
        
        return id
    }
    
    func searchSimilar(embedding: [Float], embeddingModel: String? = nil, projectId: String, limit: Int, threshold: Float?, scanLimit: Int? = nil) async throws -> [SimilarChunkResult] {
        var sql = """
        SELECT id, project_id, content, file_path, start_line, end_line, content_hash, embedding, embedding_dim, embedding_model, created_at
        FROM harmonia_chunks
        WHERE project_id = ? AND embedding IS NOT NULL
        """
        
        var params: [DatabaseParameter] = [.text(projectId)]
        
        if let scanLimit = scanLimit {
            sql += " LIMIT ?"
            params.append(.int(scanLimit))
        }
        
        let rows = try await database.query(sql, parameters: params)
        
        // Safety limit (O(n) protection)
        // Hard limit of 5000 scans per project for MVP to prevent timeouts
        if rows.count > 5000 {
            // In a real system we would use an index. For MVP we warn/cap or just accept O(n).
            // Let's just log it if we could. For now, we process all but this comment documents the known limit.
        }
        
        var scored: [(record: StoredChunkRecord, similarity: Float)] = []
        let queryDim = embedding.count
        
        for row in rows {
            guard let idValue = row["id"], case .text(let id) = idValue,
                  let contentValue = row["content"], case .text(let content) = contentValue,
                  let filePathValue = row["file_path"], case .text(let filePath) = filePathValue,
                  let startLineValue = row["start_line"], case .int(let startLine) = startLineValue,
                  let endLineValue = row["end_line"], case .int(let endLine) = endLineValue,
                  let _ = row["content_hash"], // Hash ignored
                  let dimValue = row["embedding_dim"], case .int(let storedDim) = dimValue,
                  let embeddingValue = row["embedding"], case .blob(let embeddingBlob) = embeddingValue,
                  let createdAtValue = row["created_at"], case .int(let createdAt) = createdAtValue
            else { continue }
            
            if storedDim != queryDim { continue }
            
            // Extract model
            let rowModel: String? = {
                 guard let v = row["embedding_model"], case .text(let m) = v else { return nil }
                 return m
            }()
            
            // Verify model matches (Strict Check)
            if let expectedModel = embeddingModel, let storedModel = rowModel {
                if expectedModel != storedModel {
                     throw HarmoniaError.embeddingModelMismatch("Project \(projectId) mixed models: Expected \(expectedModel), found \(storedModel) in chunk \(id)")
                }
            }
            
            let storedEmbedding: [Float]
            do {
                storedEmbedding = try EmbeddingCodec.decode(embeddingBlob, expectedDim: queryDim)
            } catch { continue }
            
            // Cosine
            let dotProduct = zip(embedding, storedEmbedding).map(*).reduce(0, +)
            let magnitudeQuery = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            let magnitudeStored = sqrt(storedEmbedding.map { $0 * $0 }.reduce(0, +))
            
            guard magnitudeQuery > 0 && magnitudeStored > 0 else { continue }
            let similarity = dotProduct / (magnitudeQuery * magnitudeStored)
            
            if let threshold = threshold, similarity < threshold { continue }
            
            let embeddingModel: String? = {
                 guard let v = row["embedding_model"], case .text(let m) = v else { return nil }
                 return m
            }()
            
            let chunk = Chunk(content: content, filePath: filePath, startLine: startLine, endLine: endLine, projectId: projectId)
            // Note: Hash is recomputed in init, but we assume it matches stored or we trust stored.
            // Chunk init computes hash.
            
            let record = StoredChunkRecord(
                id: id,
                chunk: chunk,
                embedding: storedEmbedding,
                embeddingModel: embeddingModel,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt))
            )
            
            scored.append((record, similarity))
        }
        
        // Sort
        scored.sort { lhs, rhs in
            if abs(lhs.similarity - rhs.similarity) < 0.0001 {
                return lhs.record.id < rhs.record.id
            }
            return lhs.similarity > rhs.similarity
        }
        
        return scored.prefix(limit).enumerated().map { index, item in
            SimilarChunkResult(record: item.record, similarity: item.similarity, rank: index + 1)
        }
    }
    
    func initializeSchema() async throws {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS harmonia_chunks (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            content TEXT NOT NULL,
            file_path TEXT NOT NULL,
            start_line INTEGER NOT NULL,
            end_line INTEGER NOT NULL,
            content_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
        """
        
        let context = ExecutionContext(principal: .system, projectId: nil, sessionId: "schema-init")
        _ = try await database.mutate(
            DatabaseMutation(sql: createSQL, parameters: [], componentType: "schema", entityId: nil),
            context: context
        )
        
        // Add columns
        try await ensureColumn("embedding", type: "BLOB")
        try await ensureColumn("embedding_dim", type: "INTEGER")
        try await ensureColumn("embedding_model", type: "TEXT")
    }
    
    private func ensureColumn(_ columnName: String, type: String) async throws {
        let rows = try await database.query("PRAGMA table_info(harmonia_chunks)", parameters: [])
        let exists = rows.contains {
            guard let nameV = $0["name"], case .text(let name) = nameV else { return false }
            return name == columnName
        }
        
        if !exists {
            let sql = "ALTER TABLE harmonia_chunks ADD COLUMN \(columnName) \(type)"
            let context = ExecutionContext(principal: .system, projectId: nil, sessionId: "schema-migration")
            _ = try await database.mutate(
                DatabaseMutation(sql: sql, parameters: [], componentType: "schema", entityId: nil),
                context: context
            )
        }
    }
}
