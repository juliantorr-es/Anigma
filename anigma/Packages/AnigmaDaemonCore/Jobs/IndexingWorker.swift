//
//  IndexingWorker.swift
//  AnigmaDaemonCore
//
//  Worker for repository indexing with FTS5 and vector support.
//

import Foundation
import AnigmaCore
import DatabaseCore
import MLWorkerCommon
import TextChunkingCapsule
import ContractsCore

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
    
    private let db: DatabaseActor
    private let mlWorker: MLWorker
    
    public init(database: DatabaseActor) {
        self.db = database
        self.mlWorker = MLWorker()
    }
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let jobConfig = try JSONDecoder().decode(IndexingJobConfig.self, from: config)
        
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
                        chunk_hash, source_commit, chunk_index, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, parameters: [
                        .text(chunkID),
                        .text(filePath),
                        .text(""),
                        .text(chunk),
                        .text(chunkHash),
                        .text(jobConfig.commit),
                        .int(index),
                        .double(Date().timeIntervalSince1970)
                    ])
                
                chunksCreated += 1
                
                // Generate embeddings if requested
                if jobConfig.generateEmbeddings {
                    if let vector = try? await generateEmbedding(for: chunk, modelID: jobConfig.modelID) {
                        let embeddingID = UUID().uuidString
                        let vectorData = encodeFloat32Vector(vector)
                        
                        // Metadata
                        try await db.executeAsync("""
                            INSERT INTO embeddings_metadata (
                                embedding_id, chunk_id, model_id, dimension_count, created_at
                            ) VALUES (?, ?, ?, ?, ?)
                            """, parameters: [
                                .text(embeddingID),
                                .text(chunkID),
                                .text(jobConfig.modelID ?? "default"),
                                .int(vector.count),
                                .double(Date().timeIntervalSince1970)
                            ])
                        
                        // Vector (assuming embeddings_vec exists)
                        if await db.isVectorAvailable() {
                             try await db.executeAsync("""
                                INSERT INTO embeddings_vec (embedding_id, chunk_id, model_id, vector)
                                VALUES (?, ?, ?, ?)
                                """, parameters: [
                                    .text(embeddingID),
                                    .text(chunkID),
                                    .text(jobConfig.modelID ?? "default"),
                                    .blob(vectorData)
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
    
    private func getExistingChunks(path: String, commit: String, hash: String) async throws -> [String] {
        let sql = "SELECT chunk_id FROM document_chunks WHERE document_path = ? AND source_commit = ? AND chunk_hash = ?"
        let rows = try await db.query(sql, parameters: [.text(path), .text(commit), .text(hash)])
        return rows.compactMap { $0.string(for: "chunk_id") }
    }
    
    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func chunkText(_ text: String) async -> [String] {
        let config = TextChunkingConfig(targetChunkSize: 512, minChunkSize: 128, maxChunkSize: 1024)
        do {
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            let data = Data(text.utf8)
            try await wrapper.processBytes(data)
            try await wrapper.finalize()
            let chunkDatas = try await wrapper.extractChunks(from: data)
            return chunkDatas.compactMap { String(data: $0, encoding: .utf8) }
        } catch {
            return [text] // Fallback
        }
    }
    
    private func generateEmbedding(for text: String, modelID: String?) async throws -> [Float] {
        // Use inProcessWorker to generate embedding
        // For simplicity, we create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("chunk-\(UUID().uuidString).txt")
        try text.write(to: tempFile, atomically: true, encoding: .utf8)
        
        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "indexing",
            stepId: "embed",
            engine: .mlx, // Default to MLX for embeddings
            task: .embed,
            inputs: [MLArtifactRef(path: tempFile.path, hash: hashContent(text))],
            options: MLTaskOptions()
        )
        
        let response = try await mlWorker.performTaskAsync(request)
        try? FileManager.default.removeItem(at: tempFile)
        
        guard let output = response.outputs.first else {
             throw NSError(domain: "IndexingWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No embedding produced"])
        }
        
        // Read the binary embedding file
        // In reality, we'd need to parse the EmbeddingHeader produced by MLWorker.swift
        // But for this prototype, let's assume we can retrieve it
        let data = try Data(contentsOf: URL(fileURLWithPath: output.path))
        // The first part is the JSON header, then the binary data.
        // We'll skip the header for now if we know its size, or look for the .bin file.
        // Actually MLWorker.swift line 303 writes header to .json and line 191 defines dataPath.
        
        let dataURL = URL(fileURLWithPath: output.path).deletingPathExtension().appendingPathExtension("bin")
        if FileManager.default.fileExists(atPath: dataURL.path) {
            let rawData = try Data(contentsOf: dataURL)
            return rawData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }
        
        throw NSError(domain: "IndexingWorker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Embedding data file not found"])
    }
    
    private func encodeFloat32Vector(_ vector: [Float]) -> Data {
        var data = Data(capacity: vector.count * 4)
        vector.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

// Result models (mirrored from CLI)
public struct IndexingResult: Codable, Sendable {
    public let chunksCreated: Int
    public let chunksReused: Int
    public let embeddingsCreated: Int
    public let duration: TimeInterval
}
