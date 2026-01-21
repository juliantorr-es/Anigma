//
//  CLIIndexManager.swift
//  AnigmaCLIDatabase
//
//  Incremental indexing manager with chunking and embedding support.
//  Reuses chunks and embeddings for unchanged files at same commit.
//

import Foundation
import Crypto
import TextChunkingCapsule
import AnigmaNativeShims

/// Incremental indexing manager for code and documentation.
public actor CLIIndexManager {
    private let db: CLIDatabaseActor
    private let chunkSize: Int
    private let chunkOverlap: Int

    public init(
        database: CLIDatabaseActor,
        chunkSize: Int = 512,
        chunkOverlap: Int = 64
    ) {
        self.db = database
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
    }

    /// Index a repository at a specific commit.
    public func indexRepository(
        repoRoot: String,
        commit: String,
        files: [String]
    ) async throws -> IndexingResult {
        let startTime = Date()
        var chunksCreated = 0
        var chunksReused = 0

        for filePath in files {
            let fullPath = URL(fileURLWithPath: repoRoot).appendingPathComponent(filePath).path

            guard FileManager.default.fileExists(atPath: fullPath) else {
                continue
            }

            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
                continue
            }

            // Check if we already have chunks for this file at this commit
            let existingChunks = try await getExistingChunks(
                path: filePath,
                commit: commit,
                contentHash: hashContent(content)
            )

            if !existingChunks.isEmpty {
                chunksReused += existingChunks.count
                continue
            }

            // Create new chunks
            let chunks = await chunkText(content, documentPath: filePath)

            for (index, chunk) in chunks.enumerated() {
                let chunkID = UUID().uuidString
                let chunkHash = hashContent(chunk)

                _ = try await db.execute("""
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
                        .text(commit),
                        .int(index),
                        .double(Date().timeIntervalSince1970)
                    ])

                chunksCreated += 1
            }
        }

        // Update index metadata
        let metadataID = UUID().uuidString
        _ = try await db.execute("""
            INSERT OR REPLACE INTO index_metadata (
                metadata_id, repo_root, indexed_commit, chunk_count,
                embedding_count, indexed_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(metadataID),
                .text(repoRoot),
                .text(commit),
                .int(chunksCreated + chunksReused),
                .int(0),
                .double(Date().timeIntervalSince1970)
            ])

        let duration = Date().timeIntervalSince(startTime)

        return IndexingResult(
            chunksCreated: chunksCreated,
            chunksReused: chunksReused,
            embeddingsCreated: 0,
            duration: duration
        )
    }

    /// Generate embeddings for chunks that don't have them yet.
    public func generateEmbeddings(
        modelID: String,
        dimension: Int,
        embeddingProvider: @Sendable (String) async throws -> [Float]
    ) async throws -> Int {
        // Find chunks without embeddings for this model
        let sql = """
            SELECT c.chunk_id, c.chunk_text
            FROM document_chunks c
            LEFT JOIN embeddings e ON c.chunk_id = e.chunk_id AND e.model_id = ?
            WHERE e.embedding_id IS NULL
            LIMIT 100
            """

        let rows = try await db.query(sql, parameters: [.text(modelID)])
        var created = 0

        for row in rows {
            guard let chunkID = row["chunk_id"]?.asString,
                  let chunkText = row["chunk_text"]?.asString else {
                continue
            }

            // Generate embedding
            let vector = try await embeddingProvider(chunkText)

            guard vector.count == dimension else {
                logWarning("Embedding dimension mismatch: expected \(dimension), got \(vector.count)")
                continue
            }

            // Store as blob (float32 array)
            let vectorData = encodeFloat32Vector(vector)

            let embeddingID = UUID().uuidString
            _ = try await db.execute("""
                INSERT INTO embeddings (
                    embedding_id, chunk_id, model_id, dimension_count, vector, created_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """, parameters: [
                    .text(embeddingID),
                    .text(chunkID),
                    .text(modelID),
                    .int(dimension),
                    .blob(vectorData),
                    .double(Date().timeIntervalSince1970)
                ])

            created += 1
        }

        return created
    }

    /// Get indexing status for a repository.
    public func getIndexStatus(repoRoot: String) async throws -> CLIIndexStatus? {
        let sql = """
            SELECT indexed_commit, chunk_count, embedding_count, indexed_at
            FROM index_metadata
            WHERE repo_root = ?
            ORDER BY indexed_at DESC
            LIMIT 1
            """

        let rows = try await db.query(sql, parameters: [.text(repoRoot)])

        guard let row = rows.first else { return nil }

        return CLIIndexStatus(
            commit: row["indexed_commit"]?.asString ?? "",
            chunkCount: row["chunk_count"]?.asInt ?? 0,
            embeddingCount: row["embedding_count"]?.asInt ?? 0,
            indexedAt: Date(timeIntervalSince1970: row["indexed_at"]?.asDouble ?? 0)
        )
    }

    // MARK: - Private Helpers

    private func getExistingChunks(
        path: String,
        commit: String,
        contentHash: String
    ) async throws -> [String] {
        let sql = """
            SELECT chunk_id
            FROM document_chunks
            WHERE document_path = ?
              AND source_commit = ?
              AND chunk_hash = ?
            """

        let rows = try await db.query(sql, parameters: [
            .text(path),
            .text(commit),
            .text(contentHash)
        ])

        return rows.compactMap { $0["chunk_id"]?.asString }
    }

    private func chunkText(_ text: String, documentPath: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        // Convert to UTF-8 data for byte-level chunking
        let data = Data(text.utf8)
        
        // Compute average bytes per character for this text
        let avgBytesPerChar = max(1, data.count / text.count)
        
        // Convert character-based chunkSize to byte-based target size
        let targetBytes = chunkSize * avgBytesPerChar
        
        // Ensure reasonable bounds for chunk sizes
        let minBytes = max(64, targetBytes / 4)
        let maxBytes = min(targetBytes * 2, 16384)
        
        let config = TextChunkingConfig(
            targetChunkSize: targetBytes,
            minChunkSize: minBytes,
            maxChunkSize: maxBytes,
            windowSize: 48,
            determinismTier: 1
        )
        
        do {
            // Use one-shot chunking
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            try await wrapper.processBytes(data)
            try await wrapper.finalize()
            
            // Extract chunks as Data slices
            let chunkData = try await wrapper.extractChunks(from: data)
            
            // Convert Data back to String chunks
            var baseChunks: [String] = []
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    let trimmed = chunkString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        baseChunks.append(trimmed)
                    }
                } else {
                    // UTF-8 conversion failed, fall back to original line-based chunking
                    return fallbackChunkText(text, documentPath: documentPath)
                }
            }
            
            if baseChunks.isEmpty {
                return [text]
            }
            
            // Apply overlap if requested (chunkOverlap > 0)
            if chunkOverlap > 0 {
                return applyOverlap(to: baseChunks, overlapChars: chunkOverlap, originalText: text)
            }
            
            return baseChunks
            
        } catch {
            // Capsule failed, fall back to original line-based chunking
            return fallbackChunkText(text, documentPath: documentPath)
        }
    }
    
    /// Original line-based chunking method kept as fallback
    private func fallbackChunkText(_ text: String, documentPath: String) -> [String] {
        var chunks: [String] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        var currentChunk: [String] = []
        var currentSize = 0

        for line in lines {
            let lineSize = line.count + 1 // +1 for newline

            if currentSize + lineSize > chunkSize, !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: "\n"))

                // Keep overlap
                let overlapLines = min(chunkOverlap / 50, currentChunk.count)
                currentChunk = Array(currentChunk.suffix(overlapLines))
                currentSize = currentChunk.reduce(0) { $0 + $1.count + 1 }
            }

            currentChunk.append(String(line))
            currentSize += lineSize
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: "\n"))
        }

        return chunks.isEmpty ? [text] : chunks
    }
    
    /// Apply overlapping windows to base chunks
    private func applyOverlap(to baseChunks: [String], overlapChars: Int, originalText: String) -> [String] {
        guard baseChunks.count > 1 else { return baseChunks }
        
        var overlappingChunks: [String] = []
        let text = originalText as NSString
        
        // Find start positions of each base chunk in the original text
        var positions: [Int] = []
        var currentPos = 0
        for chunk in baseChunks {
            let range = text.range(of: chunk, options: [], range: NSRange(location: currentPos, length: text.length - currentPos))
            if range.location != NSNotFound {
                positions.append(range.location)
                currentPos = range.location + range.length
            } else {
                // Fallback: can't find positions, return base chunks without overlap
                return baseChunks
            }
        }
        positions.append(text.length) // Add end position for easier calculation
        
        // Create overlapping windows
        for i in 0..<baseChunks.count {
            let start = positions[i]
            let end = min(positions[i + 1] + overlapChars, text.length)
            if end > start {
                let chunkRange = NSRange(location: start, length: end - start)
                let chunk = text.substring(with: chunkRange)
                overlappingChunks.append(chunk)
            } else {
                overlappingChunks.append(baseChunks[i])
            }
        }
        
        return overlappingChunks
    }

    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func encodeFloat32Vector(_ vector: [Float]) -> Data {
        var data = Data(capacity: vector.count * MemoryLayout<Float>.size)
        vector.withUnsafeBytes { buffer in
            data.append(contentsOf: buffer)
        }
        return data
    }

    private func logWarning(_ message: String) {
        fputs("[CLIIndexManager] WARNING: \(message)\n", stderr)
    }
}

// MARK: - Supporting Types

public struct IndexingResult: Sendable {
    public let chunksCreated: Int
    public let chunksReused: Int
    public let embeddingsCreated: Int
    public let duration: TimeInterval
}

public struct CLIIndexStatus: Sendable {
    public let commit: String
    public let chunkCount: Int
    public let embeddingCount: Int
    public let indexedAt: Date
}
