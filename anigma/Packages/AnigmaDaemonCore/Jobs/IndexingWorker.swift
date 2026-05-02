//
//  IndexingWorker.swift
//  AnigmaDaemonCore
//
//  Worker for repository indexing with FTS5 and vector support.
//

import Foundation
import CryptoKit
import AnigmaPrimitives
import AnigmaCore
import DatabaseCore
import MLWorkerCommon
import TextChunkingCapsule
import ContractsCore
import OSLog

private let indexingLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "IndexingWorker")

private protocol VectorAvailabilityDatabase: DatabaseExecutor {
    func isVectorAvailable() async -> Bool
}

extension DatabaseActor: VectorAvailabilityDatabase {}

/// Configuration for indexing job.
public struct IndexingJobConfig: Codable, Sendable {
    public let repoRoot: String
    public let commit: String
    public let files: [String]
    public let generateEmbeddings: Bool
    public let modelID: String?
    
    public init(repoRoot: String, commit: String, files: [String], generateEmbeddings: Bool = false, modelID: String? = nil) {
        self.repoRoot = repoRoot
        self.commit = commit
        self.files = files
        self.generateEmbeddings = generateEmbeddings
        self.modelID = modelID
    }
}

/// Worker that handles repository indexing.
public struct IndexingWorker: JobWorker {
    public static let kind = "repo.index"
    
    private let db: any DatabaseExecutor
    private let vectorDatabase: (any VectorAvailabilityDatabase)?
    private let useRealEmbeddings: Bool
    
    public init(database: any DatabaseExecutor) {
        self.db = database
        self.vectorDatabase = database as? any VectorAvailabilityDatabase
        self.useRealEmbeddings = ProcessInfo.processInfo.environment["ANIGMA_INDEX_USE_REAL_ML"] == "1"
    }
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let jobConfig = try JSONDecoder().decode(IndexingJobConfig.self, from: config)
        try await ensureSchema()
        
        let startTime = Date()
        var chunksCreated = 0
        var chunksReused = 0
        var embeddingsCreated = 0
        
        // 2. Process Files
        for filePath in jobConfig.files {
            let fullPath = URL(fileURLWithPath: jobConfig.repoRoot).appendingPathComponent(filePath).path
            
            guard FileManager.default.fileExists(atPath: fullPath) else { continue }
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
            
            let contentHash = hashContent(content)
            
            // Check for existing chunks
            let existing = try await getExistingChunks(path: filePath, commit: jobConfig.commit, hash: contentHash)
            if !existing.isEmpty {
                chunksReused += existing.count
                continue
            }
            
            // Chunk text
            let chunks = await chunkText(content)
            
            for (index, chunk) in chunks.enumerated() {
                let chunkID = UUID().uuidString
                let chunkHash = hashContent(chunk)
                
                try await db.executeAsync("""
                    INSERT INTO document_chunks (
                        chunk_id, document_path, section_title, chunk_text,
                        chunk_hash, source_commit, chunk_index
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, parameters: [
                        .text(chunkID),
                        .text(filePath),
                        .text(""),
                        .text(chunk),
                        .text(chunkHash),
                        .text(jobConfig.commit),
                        .int(index)
                    ])
                
                chunksCreated += 1
                
                // Generate embeddings if requested
                if jobConfig.generateEmbeddings {
                    if let vector = try? await generateEmbedding(for: chunk, modelID: jobConfig.modelID) {
                        let embeddingID = UUID().uuidString
                        _ = encodeFloat32Vector(vector)
                        
                        // Metadata
                        try await db.executeAsync("""
                            INSERT INTO embeddings_metadata (
                                embedding_id, chunk_id, model_id, dimension_count
                            ) VALUES (?, ?, ?, ?)
                            """, parameters: [
                                .text(embeddingID),
                                .text(chunkID),
                                .text(jobConfig.modelID ?? "default"),
                                .int(vector.count)
                            ])
                        
                        // Vector (pgvector)
                        if await isVectorExtensionAvailable() {
                             // pgvector expects a string like '[1,2,3]' for vector type
                             let vectorString = "[\(vector.map { String($0) }.joined(separator: ","))]"
                             
                             try await db.executeAsync("""
                                INSERT INTO embeddings_vec (embedding_id, chunk_id, model_id, vector)
                                VALUES (?, ?, ?, ?::vector)
                                """, parameters: [
                                    .text(embeddingID),
                                    .text(chunkID),
                                    .text(jobConfig.modelID ?? "default"),
                                    .text(vectorString)
                                ])
                        }
                        
                        embeddingsCreated += 1
                    }
                }
            }
        }
        
        // 3. Finalize metadata
        let duration = Date().timeIntervalSince(startTime)
        let result = IndexingResult(
            chunksCreated: chunksCreated,
            chunksReused: chunksReused,
            embeddingsCreated: embeddingsCreated,
            duration: duration
        )
        
        let resultData = try JSONEncoder().encode(result)
        return [
            JobOutputPayload(
                data: resultData,
                mediaType: "application/json",
                kind: "indexing_result"
            )
        ]
    }
    
    // MARK: - Private Helpers

    private func ensureSchema() async throws {
        // Core chunks table
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS document_chunks (
                chunk_id UUID PRIMARY KEY,
                document_path TEXT NOT NULL,
                section_title TEXT,
                chunk_text TEXT NOT NULL,
                chunk_hash TEXT NOT NULL,
                source_commit TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                search_vector tsvector -- For PostgreSQL FTS
            );
            """)

        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_chunks_path ON document_chunks(document_path);")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_chunks_commit ON document_chunks(source_commit);")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_chunks_hash ON document_chunks(chunk_hash);")
        
        // GIN index for full-text search
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_chunks_search ON document_chunks USING GIN(search_vector);")

        // Trigger to update search_vector
        try await db.executeAsync("""
            CREATE OR REPLACE FUNCTION document_chunks_search_trigger() RETURNS trigger AS $$
            begin
              new.search_vector :=
                setweight(to_tsvector('english', coalesce(new.section_title, '')), 'A') ||
                setweight(to_tsvector('english', coalesce(new.chunk_text, '')), 'B');
              return new;
            end
            $$ LANGUAGE plpgsql;
            """)
            
        try await db.executeAsync("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tsvectorupdate') THEN
                    CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
                    ON document_chunks FOR EACH ROW EXECUTE FUNCTION document_chunks_search_trigger();
                END IF;
            END
            $$;
            """)

        // Metadata table
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS embeddings_metadata (
                embedding_id UUID PRIMARY KEY,
                chunk_id UUID NOT NULL REFERENCES document_chunks(chunk_id) ON DELETE CASCADE,
                model_id TEXT NOT NULL,
                dimension_count INTEGER NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                UNIQUE(chunk_id, model_id)
            );
            """)

        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_embeddings_meta_chunk ON embeddings_metadata(chunk_id);")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_embeddings_meta_model ON embeddings_metadata(model_id);")

        // Vector table (pgvector)
        if await isVectorExtensionAvailable() {
            try await db.executeAsync("CREATE EXTENSION IF NOT EXISTS vector;")
            try await db.executeAsync("""
                CREATE TABLE IF NOT EXISTS embeddings_vec (
                    embedding_id UUID PRIMARY KEY REFERENCES embeddings_metadata(embedding_id) ON DELETE CASCADE,
                    chunk_id UUID NOT NULL REFERENCES document_chunks(chunk_id) ON DELETE CASCADE,
                    model_id TEXT NOT NULL,
                    vector vector(384) -- pgvector type
                );
                """)
            try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_embeddings_vec_vector ON embeddings_vec USING hnsw (vector vector_cosine_ops);")
        }
    }

    private func isVectorExtensionAvailable() async -> Bool {
        guard let vectorDatabase else {
            return false
        }
        return await vectorDatabase.isVectorAvailable()
    }
    
    private func getExistingChunks(path: String, commit: String, hash: String) async throws -> [String] {
        let sql = "SELECT chunk_id FROM document_chunks WHERE document_path = ? AND source_commit = ? AND chunk_hash = ?"
        let rows = try await db.query(sql, parameters: [.text(path), .text(commit), .text(hash)])
        return rows.compactMap { $0.string(for: "chunk_id") }
    }
    
    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        return BLAKE3Digest.hex(of: data)
    }
    
    private func chunkText(_ text: String) async -> [String] {
        let config = TextChunkingConfig(targetChunkSize: 512, minChunkSize: 128, maxChunkSize: 1024)
        do {
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            let data = Data(text.utf8)
            try wrapper.processBytes(data)
            try wrapper.finalize()
            let chunkDatas = try await wrapper.extractChunks(from: data)
            return chunkDatas.compactMap { String(data: $0, encoding: .utf8) }
        } catch {
            return [text] // Fallback
        }
    }
    
    private func generateEmbedding(for text: String, modelID: String?) async throws -> [Float] {
        let mlWorker = MLWorker(engine: .mlx, mockMode: !useRealEmbeddings)
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("chunk-\(UUID().uuidString).txt")
        let outputDir = tempDir.appendingPathComponent("embedding-\(UUID().uuidString)", isDirectory: true)
        try text.write(to: tempFile, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "indexing",
            stepId: "embed",
            engine: .mlx, // Default to MLX for embeddings
            task: .embed,
            inputs: [MLArtifactRef(path: tempFile.path, hash: hashContent(text))],
            options: MLTaskOptions(seed: 42, outputDirectory: outputDir.path)
        )
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
            try? FileManager.default.removeItem(at: outputDir)
        }

        indexingLogger.debug("Generating indexing embedding modelID='\(modelID ?? "default", privacy: .public)' mockMode=\(ProcessInfo.processInfo.environment["ANIGMA_INDEX_USE_REAL_ML"] == "1" ? "false" : "true", privacy: .public)")
        let response = try await mlWorker.performTaskAsync(request)
        
        guard let output = response.outputs.first else {
             throw NSError(domain: "IndexingWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No embedding produced"])
        }

        return try loadEmbeddingVector(from: output.path)
    }
    
    private func encodeFloat32Vector(_ vector: [Float]) -> Data {
        var data = Data(capacity: vector.count * 4)
        vector.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func loadEmbeddingVector(from headerPath: String) throws -> [Float] {
        let headerURL = URL(fileURLWithPath: headerPath)
        let headerData = try Data(contentsOf: headerURL)
        let header = try JSONDecoder().decode(EmbeddingHeader.self, from: headerData)
        let dataURL = URL(fileURLWithPath: header.dataPath)
        let rawData = try Data(contentsOf: dataURL)
        return rawData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}

// Result models (mirrored from CLI)
public struct IndexingResult: Codable, Sendable {
    public let chunksCreated: Int
    public let chunksReused: Int
    public let embeddingsCreated: Int
    public let duration: TimeInterval
}
