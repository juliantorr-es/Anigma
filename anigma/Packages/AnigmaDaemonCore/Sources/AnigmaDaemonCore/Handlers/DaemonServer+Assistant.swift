//
//  DaemonServer+Assistant.swift
//  AnigmaDaemonCore
//

import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import DatabaseCore
import Foundation
import HarmoniaV2Core
import HarmoniaV2Inference
import OSLog

private let assistantLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "Assistant")

extension DaemonServer {
    func handleAssistantStatus(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantStatusRequest
    ) async throws -> AnigmaAssistantStatusResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "system.read")

        let (mode, source) = try await runtime.showMode(for: request.projectId)
        let (killSwitchActive, killSwitchReason) = try await runtime.showKillSwitch(for: request.projectId)
        assistantLogger.debug("Assistant status projectId='\(request.projectId ?? "global", privacy: .public)' mode='\(mode.rawValue, privacy: .public)'")

        return AnigmaAssistantStatusResponse(
            operatingMode: mode.rawValue,
            modeSource: source.rawValue,
            killSwitchActive: killSwitchActive,
            killSwitchReason: killSwitchReason,
            lastDenialSummary: nil,
            error: nil
        )
    }

    func handleAssistantListProjects(
        ctx: DaemonRequestContext
    ) async throws -> AnigmaAssistantListProjectsResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "project.read")

        try await ensureAssistantProjectSchema()

        let rows = try await runtime.database.query(
            """
            SELECT id, name, created_at, embedding_model
            FROM harmonia_projects
            ORDER BY name ASC
            """,
            parameters: []
        )

        let projects = rows.compactMap { row -> AnigmaAssistantProject? in
            guard
                let id = row["id"].string,
                let name = row["name"].string,
                let createdAt = row["created_at"].double,
                let embeddingModel = row["embedding_model"].string
            else {
                return nil
            }

            return AnigmaAssistantProject(
                id: id,
                name: name,
                createdAtUnixMs: UInt64(createdAt * 1000),
                embeddingModel: embeddingModel
            )
        }

        assistantLogger.debug("Listed \(projects.count, privacy: .public) assistant projects")
        return AnigmaAssistantListProjectsResponse(projects: projects, error: nil)
    }

    func handleAssistantCreateProject(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantCreateProjectRequest
    ) async throws -> AnigmaAssistantCreateProjectResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "project.write")

        try await ensureAssistantProjectSchema()

        let principal = Principal(
            id: request.principalId,
            displayName: request.principalDisplayName
        )
        let context = ExecutionContext(principal: principal, projectId: request.id)
        let createdAt = Date()

        let mutation = DatabaseMutation(
            sql: """
            INSERT INTO harmonia_projects (id, name, created_at, embedding_model)
            VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .text(request.id),
                .text(request.name),
                .double(createdAt.timeIntervalSince1970),
                .text(request.embeddingModel)
            ],
            componentType: "project_registry",
            entityId: EntityId(uuidString: request.id)
        )

        do {
            _ = try await runtime.database.mutate(mutation, context: context)
            assistantLogger.info("Created assistant project '\(request.id, privacy: .public)'")
            return AnigmaAssistantCreateProjectResponse(
                project: AnigmaAssistantProject(
                    id: request.id,
                    name: request.name,
                    createdAtUnixMs: UInt64(createdAt.timeIntervalSince1970 * 1000),
                    embeddingModel: request.embeddingModel
                ),
                error: nil
            )
        } catch {
            assistantLogger.error("Failed to create assistant project '\(request.id, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantCreateProjectResponse(
                project: nil,
                error: makeAssistantError(code: "PROJECT_CREATE_FAILED", error: error)
            )
        }
    }

    func handleAssistantSetMode(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantSetModeRequest
    ) async throws -> AnigmaAssistantSetModeResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "governance.write")

        guard let mode = OperatingMode(rawValue: request.mode) else {
            return AnigmaAssistantSetModeResponse(
                success: false,
                error: AnigmaErrorStatus(
                    code: "INVALID_MODE",
                    message: "Unknown operating mode '\(request.mode)'",
                    detailJson: nil
                )
            )
        }

        do {
            try await runtime.setMode(
                mode,
                for: request.projectId,
                by: Principal(id: request.principalId, displayName: request.principalDisplayName)
            )
            assistantLogger.info("Set assistant mode='\(mode.rawValue, privacy: .public)' projectId='\(request.projectId ?? "global", privacy: .public)'")
            return AnigmaAssistantSetModeResponse(success: true, error: nil)
        } catch {
            assistantLogger.error("Failed setting assistant mode: \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantSetModeResponse(
                success: false,
                error: makeAssistantError(code: "SET_MODE_FAILED", error: error)
            )
        }
    }

    func handleAssistantSetKillSwitch(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantSetKillSwitchRequest
    ) async throws -> AnigmaAssistantSetKillSwitchResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "governance.write")

        do {
            try await runtime.setKillSwitch(
                active: request.active,
                for: request.projectId,
                reason: request.reason,
                by: Principal(id: request.principalId, displayName: request.principalDisplayName)
            )
            assistantLogger.info("Set assistant kill switch active=\(request.active, privacy: .public) projectId='\(request.projectId ?? "global", privacy: .public)'")
            return AnigmaAssistantSetKillSwitchResponse(success: true, error: nil)
        } catch {
            assistantLogger.error("Failed setting assistant kill switch: \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantSetKillSwitchResponse(
                success: false,
                error: makeAssistantError(code: "SET_KILLSWITCH_FAILED", error: error)
            )
        }
    }

    func handleAssistantRecall(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantRecallRequest
    ) async throws -> AnigmaAssistantRecallResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "project.read")

        let startedAt = Date()
        do {
            let memoryStore = AssistantMemoryStore(database: runtime.database)
            try await memoryStore.initializeSchema()

            let embeddingResult = try await computeAssistantEmbedding(
                text: request.query,
                projectId: request.projectId,
                userId: "assistant-recall"
            )

            let results = try await memoryStore.searchSimilar(
                embedding: embeddingResult.vector,
                embeddingModel: embeddingResult.modelName,
                projectId: request.projectId,
                limit: request.options.topK,
                threshold: request.options.threshold,
                scanLimit: request.options.scanLimit
            )

            let countResult = try await runtime.database.query(
                "SELECT count(*) AS c FROM harmonia_memories WHERE project_id = ? AND embedding IS NOT NULL",
                parameters: [.text(request.projectId)]
            )
            let rowsScanned = countResult.first?.int(for: "c") ?? 0
            assistantLogger.debug("Recall query for projectId='\(request.projectId, privacy: .public)' returned \(results.count, privacy: .public) results")

            return AnigmaAssistantRecallResponse(
                query: request.query,
                projectId: request.projectId,
                results: results.map {
                    AnigmaAssistantRecallItem(
                        id: $0.record.id,
                        content: $0.record.content,
                        similarity: $0.similarity,
                        rank: $0.rank,
                        vectorRank: $0.vectorRank,
                        ftsRank: $0.ftsRank,
                        rrfScore: $0.rrfScore,
                        metadata: $0.record.metadata
                    )
                },
                stats: AnigmaAssistantRecallStats(
                    rowsScanned: rowsScanned,
                    scanLimit: request.options.scanLimit,
                    executionTime: Date().timeIntervalSince(startedAt)
                ),
                error: nil
            )
        } catch {
            assistantLogger.error("Assistant recall failed for projectId='\(request.projectId, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantRecallResponse(
                query: request.query,
                projectId: request.projectId,
                results: [],
                stats: nil,
                error: makeAssistantError(code: "ASSISTANT_RECALL_FAILED", error: error)
            )
        }
    }

    func handleAssistantAddMemo(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantAddMemoRequest
    ) async throws -> AnigmaAssistantAddMemoResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "project.write")

        do {
            let memoryStore = AssistantMemoryStore(database: runtime.database)
            try await memoryStore.initializeSchema()

            let embeddingResult = try await computeAssistantEmbedding(
                text: request.text,
                projectId: request.projectId,
                userId: request.principalId
            )
            let metadata: [String: String] = [
                "projectId": request.projectId,
                "userId": request.principalId,
                "kind": "memo",
                "fileName": "Memo \(Date().timeIntervalSince1970)",
                "embeddingModel": embeddingResult.modelName
            ]
            let principal = Principal(id: request.principalId, displayName: request.principalDisplayName)
            let record = try await memoryStore.storeMemo(
                content: request.text,
                metadata: metadata,
                embedding: embeddingResult.vector,
                principal: principal,
                projectId: request.projectId
            )
            assistantLogger.info("Stored assistant memo id='\(record.id, privacy: .public)' projectId='\(request.projectId, privacy: .public)'")
            return AnigmaAssistantAddMemoResponse(
                record: AnigmaAssistantMemoryRecord(
                    id: record.id,
                    content: record.content,
                    metadata: record.metadata,
                    embeddingModel: record.embeddingModel,
                    createdAtUnixMs: UInt64(record.createdAt.timeIntervalSince1970 * 1000)
                ),
                error: nil
            )
        } catch {
            assistantLogger.error("Assistant addMemo failed for projectId='\(request.projectId, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantAddMemoResponse(
                record: nil,
                error: makeAssistantError(code: "ASSISTANT_ADD_MEMO_FAILED", error: error)
            )
        }
    }

    func handleAssistantStartIndex(
        ctx: DaemonRequestContext,
        request: AnigmaAssistantStartIndexRequest
    ) async throws -> AnigmaAssistantStartIndexResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "job.submit")

        do {
            let folderURL = URL(fileURLWithPath: (request.folderPath as NSString).expandingTildeInPath)
            let files = try enumerateAssistantIndexFiles(at: folderURL)
            assistantLogger.info("Assistant index start folder='\(folderURL.path, privacy: .public)' files=\(files.count, privacy: .public) dryRun=\(request.dryRun, privacy: .public)")

            if request.dryRun || files.isEmpty {
                return AnigmaAssistantStartIndexResponse(
                    jobId: nil,
                    totalFiles: files.count,
                    result: AnigmaAssistantIndexResult(
                        chunksCreated: 0,
                        chunksReused: 0,
                        embeddingsCreated: 0,
                        duration: 0
                    ),
                    error: nil
                )
            }

            let modelID = try await assistantProjectEmbeddingModel(id: request.projectId)
            let config = IndexingJobConfig(
                repoRoot: folderURL.path,
                commit: "workspace",
                files: files,
                generateEmbeddings: true,
                modelID: modelID
            )
            let configCanonical = try JSONEncoder().encode(config)
            let spec = JobSpec(kind: IndexingWorker.kind, configCanonical: configCanonical, inputs: [])
            let jobId = try await jobQueue.submit(spec: spec, clientId: ctx.clientId)
            await emitJobEvent(
                jobId: jobId,
                type: .state,
                message: JobState.queued.rawValue,
                progressPermille: 0
            )
            assistantLogger.info("Assistant index queued jobId='\(jobId, privacy: .public)'")

            return AnigmaAssistantStartIndexResponse(
                jobId: jobId,
                totalFiles: files.count,
                result: nil,
                error: nil
            )
        } catch {
            assistantLogger.error("Assistant index preparation failed: \(error.localizedDescription, privacy: .public)")
            return AnigmaAssistantStartIndexResponse(
                jobId: nil,
                totalFiles: 0,
                result: nil,
                error: makeAssistantError(code: "ASSISTANT_INDEX_START_FAILED", error: error)
            )
        }
    }

    private func ensureAssistantProjectSchema() async throws {
        let context = ExecutionContext(principal: .system, sessionId: "assistant-project-schema")
        let mutation = DatabaseMutation(
            sql: """
            CREATE TABLE IF NOT EXISTS harmonia_projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at REAL NOT NULL,
                embedding_model TEXT NOT NULL
            )
            """,
            componentType: "schema"
        )

        _ = try await runtime.database.mutate(mutation, context: context)
    }

    private func assistantProjectEmbeddingModel(id: String) async throws -> String? {
        try await ensureAssistantProjectSchema()
        let rows = try await runtime.database.query(
            "SELECT embedding_model FROM harmonia_projects WHERE id = ? LIMIT 1",
            parameters: [.text(id)]
        )
        return rows.first?["embedding_model"].string
    }

    private func computeAssistantEmbedding(
        text: String,
        projectId: String,
        userId: String
    ) async throws -> HarmoniaV2Inference.EmbeddingResult {
        let modelID = try await assistantProjectEmbeddingModel(id: projectId) ?? "text-embedding-stub-256"

        if let mlWorkerPath = resolveAssistantMLWorkerPath() {
            do {
                let vector = try await computeEmbeddingViaMLWorker(text: text, executablePath: mlWorkerPath)
                assistantLogger.info("Assistant embeddings resolved via ml-worker at '\(mlWorkerPath, privacy: .public)'")
                return HarmoniaV2Inference.EmbeddingResult(
                    vector: vector,
                    modelName: modelID,
                    backend: "ml-worker",
                    timestamp: Date()
                )
            } catch {
                assistantLogger.warning("ml-worker embedding failed at '\(mlWorkerPath, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
        } else {
            assistantLogger.warning("ml-worker executable not found; falling back to deterministic assistant embeddings")
        }

        let inference = InferenceEngine(
            embeddingBackend: DeterministicEmbeddingBackend(modelName: modelID)
        )
        let context = HarmoniaV2Core.ExecutionContext(
            sessionId: UUID().uuidString,
            userId: userId
        )
        return try await inference.embed(text: text, context: context)
    }

    private func resolveAssistantMLWorkerPath() -> String? {
        if let envPath = ProcessInfo.processInfo.environment["ML_WORKER_PATH"],
           FileManager.default.isExecutableFile(atPath: envPath) {
            return envPath
        }

        return WorkerTooling.findTool(named: "ml-worker")
    }

    private func computeEmbeddingViaMLWorker(
        text: String,
        executablePath: String
    ) async throws -> [Float] {
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("assistant-embed-\(UUID().uuidString).txt")
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("assistant-embed-\(UUID().uuidString)", isDirectory: true)

        try text.write(to: inputURL, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputDir)
        }

        let inputHash = ContractKeyDerivation.blake3Hex(Data(text.utf8))
        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "assistant-\(UUID().uuidString)",
            stepId: "assistant-embed",
            engine: .mlx,
            task: .embed,
            inputs: [MLArtifactRef(path: inputURL.path, hash: inputHash)],
            options: MLTaskOptions(seed: 42, outputDirectory: outputDir.path)
        )

        let requestData = try JSONEncoder().encode(request) + Data("\n".utf8)
        let result = try await WorkerTooling.runProcessAsync(
            config: WorkerTooling.RunProcessConfiguration(
                executable: executablePath,
                arguments: ["--engine", request.engine.rawValue],
                inputData: requestData,
                timeout: 120
            )
        )

        guard result.exitCode == 0 else {
            throw NSError(
                domain: "AssistantEmbedding",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: "ml-worker failed: \(result.stderr)"]
            )
        }

        let response = try JSONDecoder().decode(MLWorkerResponse.self, from: result.stdout)
        guard response.status == .completed, let output = response.outputs.first else {
            throw NSError(
                domain: "AssistantEmbedding",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: response.errorMessage ?? "ml-worker did not return a completed embedding response"]
            )
        }

        return try loadEmbeddingVector(from: output.path)
    }

    private func loadEmbeddingVector(from headerPath: String) throws -> [Float] {
        let headerURL = URL(fileURLWithPath: headerPath)
        let headerData = try Data(contentsOf: headerURL)
        let header = try JSONDecoder().decode(EmbeddingHeader.self, from: headerData)

        let dataURL: URL
        if header.dataPath.hasPrefix("/") {
            dataURL = URL(fileURLWithPath: header.dataPath)
        } else {
            dataURL = headerURL.deletingLastPathComponent().appendingPathComponent(header.dataPath)
        }

        let rawData = try Data(contentsOf: dataURL)
        return rawData.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
    }

    private func enumerateAssistantIndexFiles(at folderURL: URL) throws -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let allowedExtensions = Set(["swift", "md", "txt", "json", "py"])
        var files: [String] = []

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: folderURL.path.hasSuffix("/") ? folderURL.path : folderURL.path + "/",
                with: ""
            )
            files.append(relativePath)
        }

        return files.sorted()
    }

    private func makeAssistantError(code: String, error: Error) -> AnigmaErrorStatus {
        AnigmaErrorStatus(
            code: code,
            message: error.localizedDescription,
            detailJson: nil
        )
    }
}

private actor AssistantMemoryStore: MemoryStore {
    private let database: any AnigmaFoundation.DatabaseAuthority

    init(database: any AnigmaFoundation.DatabaseAuthority) {
        self.database = database
    }

    func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String {
        try await storeMemo(
            content: content,
            metadata: metadata,
            embedding: embedding,
            principal: Principal(id: metadata["userId"] ?? "unknown", displayName: metadata["userId"] ?? "unknown"),
            projectId: metadata["projectId"]
        ).id
    }

    func storeMemo(
        content: String,
        metadata: [String: String],
        embedding: [Float]?,
        principal: Principal,
        projectId: String?
    ) async throws -> StoredMemoryRecord {
        let id = UUID().uuidString
        let createdAt = Date()

        let embeddingBlob: DatabaseParameter
        let embeddingDim: DatabaseParameter
        let embeddingModelParam: DatabaseParameter

        if let embedding {
            embeddingBlob = .blob(EmbeddingCodec.encode(embedding))
            embeddingDim = .int(embedding.count)
            embeddingModelParam = metadata["embeddingModel"].map { .text($0) } ?? .null
        } else {
            embeddingBlob = .null
            embeddingDim = .null
            embeddingModelParam = .null
        }

        let metadataJSON: String
        if
            let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
            let json = String(data: jsonData, encoding: .utf8)
        {
            metadataJSON = json
        } else {
            metadataJSON = "{}"
        }

        let mutation = DatabaseMutation(
            sql: """
            INSERT OR IGNORE INTO harmonia_memories
            (id, content, created_at, project_id, embedding, embedding_dim, embedding_model, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(id),
                .text(content),
                .int(Int(createdAt.timeIntervalSince1970)),
                projectId.map { .text($0) } ?? .null,
                embeddingBlob,
                embeddingDim,
                embeddingModelParam,
                .text(metadataJSON)
            ],
            componentType: "memory",
            entityId: nil
        )

        let context = ExecutionContext(principal: principal, projectId: projectId, sessionId: metadata["sessionId"] ?? UUID().uuidString)
        _ = try await database.mutate(mutation, context: context)

        return StoredMemoryRecord(
            id: id,
            content: content,
            metadata: metadata,
            embedding: embedding,
            embeddingModel: metadata["embeddingModel"],
            createdAt: createdAt
        )
    }

    func retrieve(sessionId: String?, tenantId: String?, limit: Int) async throws -> [StoredMemoryRecord] {
        []
    }

    func searchSimilar(
        embedding: [Float],
        embeddingModel: String?,
        projectId: String,
        limit: Int,
        threshold: Float?,
        scanLimit: Int?
    ) async throws -> [SimilarMemoryResult] {
        var sql = """
        SELECT id, content, created_at, embedding, embedding_dim, embedding_model, metadata_json
        FROM harmonia_memories
        WHERE project_id = ? AND embedding IS NOT NULL
        """
        var parameters: [DatabaseParameter] = [.text(projectId)]
        if let scanLimit {
            sql += " LIMIT ?"
            parameters.append(.int(scanLimit))
        }

        let rows = try await database.query(sql, parameters: parameters)

        struct ScoredResult {
            let record: StoredMemoryRecord
            let similarity: Float
        }

        let queryDim = embedding.count
        var scored: [ScoredResult] = []

        for row in rows {
            guard
                let id = row["id"].string,
                let content = row["content"].string,
                let createdAt = row["created_at"].int,
                let embeddingValue = row["embedding"],
                case .blob(let embeddingBlob) = embeddingValue,
                let storedDim = row["embedding_dim"].int
            else {
                continue
            }

            let rowModel = row["embedding_model"].string
            if storedDim != queryDim {
                continue
            }
            if let embeddingModel, let rowModel, embeddingModel != rowModel {
                throw HarmoniaError.embeddingModelMismatch("Expected \(embeddingModel), got \(rowModel)")
            }

            let storedEmbedding = try EmbeddingCodec.decode(embeddingBlob, expectedDim: queryDim)
            let dotProduct = zip(embedding, storedEmbedding).map(*).reduce(0, +)
            let magQ = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            let magS = sqrt(storedEmbedding.map { $0 * $0 }.reduce(0, +))
            guard magQ > 0, magS > 0 else { continue }

            let similarity = dotProduct / (magQ * magS)
            if let threshold, similarity < threshold {
                continue
            }

            let metadata: [String: String]
            if
                let metadataJSON = row["metadata_json"].string,
                let data = metadataJSON.data(using: .utf8),
                let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            {
                metadata = parsed
            } else {
                metadata = [:]
            }

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
                vectorRank: index + 1,
                ftsRank: nil,
                rrfScore: result.similarity,
                tags: []
            )
        }
    }

    func initializeSchema() async throws {
        let context = ExecutionContext(principal: .system, sessionId: "assistant-memory-schema")
        _ = try await database.mutate(
            DatabaseMutation(
                sql: """
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
                """,
                componentType: "schema"
            ),
            context: context
        )

        let rows = try await database.query(
            "SELECT to_regclass('public.harmonia_memories_fts')",
            parameters: []
        )
        guard rows.isEmpty else {
            return
        }

        _ = try await database.mutate(
            DatabaseMutation(
                sql: "CREATE VIRTUAL TABLE harmonia_memories_fts USING fts5(content, content='harmonia_memories', content_rowid='rowid')",
                componentType: "schema"
            ),
            context: context
        )

        let triggers = [
            "CREATE TRIGGER harmonia_memories_ai AFTER INSERT ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content); END;",
            "CREATE TRIGGER harmonia_memories_ad AFTER DELETE ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content); END;",
            "CREATE TRIGGER harmonia_memories_au AFTER UPDATE ON harmonia_memories BEGIN INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content) VALUES('delete', old.rowid, old.content); INSERT INTO harmonia_memories_fts(rowid, content) VALUES (new.rowid, new.content); END;"
        ]

        for trigger in triggers {
            _ = try await database.mutate(
                DatabaseMutation(sql: trigger, componentType: "schema"),
                context: context
            )
        }
    }
}
