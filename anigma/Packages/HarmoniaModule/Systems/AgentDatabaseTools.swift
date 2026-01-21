//
//  AgentDatabaseTools.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
import Foundation
import CryptoKit

/// Agent-facing database tools that enforce DB-first retrieval
/// These tools replace repo scanning with indexed, provenance-backed queries
public actor AgentDatabaseTools {
    private let documentUnitDB: DocumentUnitDatabase
    private let policyEnforcer: PolicyEnforcer

    public init(documentUnitDB: DocumentUnitDatabase, policyEnforcer: PolicyEnforcer) {
        self.documentUnitDB = documentUnitDB
        self.policyEnforcer = policyEnforcer
    }

    // MARK: - Semantic Search (DB-First)

    /// Semantic search using embeddings - the preferred method
    public func semanticSearch(
        query: String,
        engine: String = "mlx",
        limit: Int = 10,
        threshold: Float = 0.7
    ) async throws -> SemanticSearchResult {
        // Check policy: semantic search requires embeddings exist
        try await policyEnforcer.requireEmbeddingsCoverage()

        // Generate query embedding using ML worker
        let queryVector = try await generateQueryEmbedding(query: query, engine: engine)

        // Search embeddings database
        let searchResults = try await documentUnitDB.searchEmbeddings(
            queryVector: queryVector,
            limit: limit,
            threshold: threshold
        )

        return SemanticSearchResult(
            query: query,
            engine: engine,
            results: searchResults.map { result in
                SearchResultItem(
                    documentUnitId: result.documentUnitId,
                    contentPreview: result.contentPreview,
                    filePath: result.filePath,
                    contentType: result.contentType,
                    similarity: result.similarity,
                    sourceArtifactPath: result.sourceArtifactPath,
                    sourceArtifactHash: result.sourceArtifactHash
                )
            }
        )
    }

    // MARK: - Full-Text Search (DB-First)

    /// Full-text search across document content
    public func textSearch(
        query: String,
        contentType: String? = nil,
        limit: Int = 10
    ) async throws -> TextSearchResult {
        // Check policy: text search requires FTS index
        try await policyEnforcer.requireFullTextCoverage()

        let searchResults = try await documentUnitDB.searchContent(
            query: query,
            contentType: contentType,
            limit: limit
        )

        return TextSearchResult(
            query: query,
            results: searchResults.map { result in
                SearchResultItem(
                    documentUnitId: result.documentUnitId,
                    contentPreview: result.contentPreview,
                    filePath: result.filePath,
                    contentType: result.contentType,
                    similarity: result.relevance,
                    sourceArtifactPath: result.sourceArtifactPath,
                    sourceArtifactHash: result.sourceArtifactHash
                )
            }
        )
    }

    // MARK: - Document Retrieval (Provenance-Backed)

    /// Retrieve document unit with complete custody trail
    public func getDocument(documentUnitId: String) async throws -> DocumentWithProvenance {
        let documentUnit = try await documentUnitDB.getDocumentUnit(id: documentUnitId)
        guard let documentUnit = documentUnit else {
            throw AgentError.documentNotFound(documentUnitId)
        }

        // Read source artifact to get original content
        let originalContent = try Data(contentsOf: URL(fileURLWithPath: documentUnit.sourceArtifactPath))

        return DocumentWithProvenance(
            documentUnit: documentUnit,
            originalContent: originalContent,
            custodyTrail: try await buildCustodyTrail(documentUnit: documentUnit)
        )
    }

    /// Get artifact by hash with verification
    public func getArtifact(artifactHash: String) async throws -> ArtifactWithVerification {
        // Look up artifact in document units
        let results = try await documentUnitDB.query("""
            SELECT source_artifact_path, source_artifact_hash, file_path, acquisition_timestamp
            FROM document_units
            WHERE source_artifact_hash = ?
            LIMIT 1
        """, parameters: [dbp(artifactHash)])

        guard let row = results.first,
              let artifactPath = row["source_artifact_path"]?.asString,
              let storedHash = row["source_artifact_hash"]?.asString,
              storedHash == artifactHash else {
            throw AgentError.artifactNotFound(artifactHash)
        }

        // Read and verify artifact
        let artifactData = try Data(contentsOf: URL(fileURLWithPath: artifactPath))
        let computedHash = sha256Hex(artifactData)

        guard computedHash == artifactHash else {
            throw AgentError.artifactCorrupted(artifactHash)
        }

        let filePathValue = row["file_path"]?.asString
        let acquisitionTimestampValue = row["acquisition_timestamp"]?.asInt ?? 0

        return ArtifactWithVerification(
            path: artifactPath,
            data: artifactData,
            verifiedHash: computedHash,
            filePath: filePathValue,
            acquisitionTimestamp: acquisitionTimestampValue
        )
    }

    // MARK: - Diagnostics and Build Output (Indexed)

    /// Search build warnings/errors indexed by file and git context
    public func searchDiagnostics(
        query: String? = nil,
        filePath: String? = nil,
        severity: String? = nil,
        limit: Int = 50
    ) async throws -> DiagnosticSearchResult {
        try await policyEnforcer.requireDiagnosticCoverage()

        var whereClauses: [String] = []
        var parameters: [DatabaseParameter] = []
        var sql = """
            SELECT v.id, v.file_path, v.line_number, v.column_number, v.message, v.severity, v.toolchain
            FROM build_diagnostics_with_context v
            """

        if let query, !query.isEmpty {
            sql += """
                JOIN build_diagnostics bd ON v.id = bd.id
                JOIN build_diagnostics_fts fts ON fts.rowid = bd.rowid
                """
            whereClauses.append("fts MATCH ?")
            parameters.append(dbp(query))
        }

        if let filePath, !filePath.isEmpty {
            whereClauses.append("v.file_path LIKE ?")
            parameters.append(dbp("%\(filePath)%"))
        }

        if let severity, !severity.isEmpty {
            whereClauses.append("v.severity = ?")
            parameters.append(dbp(severity))
        }

        if !whereClauses.isEmpty {
            sql += " WHERE " + whereClauses.joined(separator: " AND ")
        }

        sql += " ORDER BY v.start_timestamp DESC, v.severity DESC, v.file_path ASC"
        sql += " LIMIT ?"
        parameters.append(dbp(limit))

        let rows = try await documentUnitDB.query(sql, parameters: parameters)
        let results: [DiagnosticResult] = rows.compactMap { row in
            guard let id = row["id"]?.asString,
                  let filePath = row["file_path"]?.asString,
                  let message = row["message"]?.asString,
                  let severity = row["severity"]?.asString,
                  let toolchain = row["toolchain"]?.asString else {
                return nil
            }

            let line = row["line_number"]?.asInt ?? 0
            let column = row["column_number"]?.asInt ?? 0

            return DiagnosticResult(
                id: id,
                filePath: filePath,
                line: line,
                column: column,
                message: message,
                severity: severity,
                toolchain: toolchain
            )
        }

        return DiagnosticSearchResult(
            query: query ?? "all",
            results: results
        )
    }

    /// Get coverage report showing what's indexed vs what's missing
    public func getCoverageReport() async throws -> CoverageReport {
        let totalRow = try await documentUnitDB.query("SELECT COUNT(*) AS total_documents FROM document_units").first
        let embeddedRow = try await documentUnitDB.query("SELECT COUNT(DISTINCT document_unit_id) AS documents_with_embeddings FROM embeddings").first
        let totalDocuments = totalRow?["total_documents"]?.asInt ?? 0
        let embeddedDocuments = embeddedRow?["documents_with_embeddings"]?.asInt ?? 0

        return CoverageReport(
            totalDocumentsIndexed: totalDocuments,
            documentsWithEmbeddings: embeddedDocuments,
            coveragePercentage: totalDocuments > 0 ? Double(embeddedDocuments) / Double(totalDocuments) * 100 : 0,
            lastUpdated: Int(Date().timeIntervalSince1970)
        )
    }

    // MARK: - Fallback Tools (Policy-Enforced)

    /// Repository scanning with policy violation logging
    /// Agents should only use this when DB coverage is insufficient
    public func repoScanFallback(
        pathPattern: String,
        reason: String
    ) async throws -> RepoScanResult {
        // Log policy violation
        try await policyEnforcer.logPolicyViolation(
            action: "repo_scan_fallback",
            reason: reason,
            details: ["pathPattern": pathPattern]
        )

        // Perform minimal repo scan
        let results = try await performMinimalRepoScan(pathPattern: pathPattern)

        return RepoScanResult(
            pathPattern: pathPattern,
            reason: reason,
            filesFound: results.count,
            files: results,
            policyViolationLogged: true
        )
    }

    // MARK: - Private Implementation

    private func generateQueryEmbedding(query: String, engine: String) async throws -> Data {
        let tempInputPath = "/tmp/query-\(UUID().uuidString.lowercased()).txt"
        try query.write(to: URL(fileURLWithPath: tempInputPath), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: tempInputPath)
        }

        let request = MLWorkerRequest(
            requestId: "query-\(UUID().uuidString.lowercased())",
            runId: "query-\(UUID().uuidString.lowercased())",
            stepId: "embedding",
            engine: MLWorkerEngine(rawValue: engine) ?? .mlx,
            task: .embed,
            inputs: [MLArtifactRef(path: tempInputPath, hash: sha256Hex(query.data(using: .utf8) ?? Data()))],
            options: MLTaskOptions(seed: 42) // Fixed seed for consistency
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "./.build/debug/ml-worker")
        process.arguments = ["--engine", engine]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let requestData = try JSONEncoder().encode(request)
        stdinPipe.fileHandleForWriting.write(requestData)
        stdinPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        let responseData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let response = try JSONDecoder().decode(MLWorkerResponse.self, from: responseData)

        guard case .completed = response.status,
              let output = response.outputs.first else {
            throw AgentError.embeddingGenerationFailed
        }

        // Read embedding data
        let headerPath = "\(output.path).json"
        let headerData = try Data(contentsOf: URL(fileURLWithPath: headerPath))
        let header = try JSONDecoder().decode(EmbeddingHeader.self, from: headerData)

        let embeddingData = try Data(contentsOf: URL(fileURLWithPath: header.dataPath))

        return embeddingData
    }

    private func buildCustodyTrail(documentUnit: DocumentUnit) async throws -> [CustodyStep] {
        var trail: [CustodyStep] = []

        // Source acquisition
        trail.append(CustodyStep(
            type: "acquisition",
            timestamp: documentUnit.acquisitionTimestamp,
            method: documentUnit.acquisitionMethod,
            sourceArtifact: documentUnit.sourceArtifactPath,
            sourceHash: documentUnit.sourceArtifactHash
        ))

        // Content processing
        trail.append(CustodyStep(
            type: "processing",
            timestamp: documentUnit.createdAt,
            method: "content_extraction",
            sourceArtifact: nil,
            sourceHash: documentUnit.contentHash
        ))

        return trail
    }

    private func performMinimalRepoScan(pathPattern: String) async throws -> [RepoFile] {
        // This would implement a minimal repository scanner
        // For now, return empty results
        return []
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Policy Enforcement

/// Enforces DB-first policies and logs violations
public actor PolicyEnforcer {
    private let dbActor: DatabaseActor

    public init(dbActor: DatabaseActor) {
        self.dbActor = dbActor
    }

    public func requireEmbeddingsCoverage() async throws {
        let row = try await dbActor.query("SELECT COUNT(*) AS embedding_count FROM embeddings").first
        let count = row?["embedding_count"]?.asInt ?? 0
        if count == 0 {
            throw AgentError.insufficientEmbeddingCoverage
        }
    }

    public func requireFullTextCoverage() async throws {
        let row = try await dbActor.query("SELECT COUNT(*) AS coverage_count FROM document_units_fts").first
        let count = row?["coverage_count"]?.asInt ?? 0
        if count == 0 {
            throw AgentError.insufficientFullTextCoverage
        }
    }

    public func requireDiagnosticCoverage() async throws {
        // Check if diagnostics table exists and has data
        let tableExists = !(try await dbActor.query("""
            SELECT name FROM sqlite_master
            WHERE type='table' AND name='build_diagnostics'
        """).isEmpty)

        if tableExists {
            let countRow = try await dbActor.query("SELECT COUNT(*) AS diagnostics_count FROM build_diagnostics").first
            let count = countRow?["diagnostics_count"]?.asInt ?? 0
            if count == 0 {
                throw AgentError.insufficientDiagnosticCoverage
            }
        }
    }

    public func logPolicyViolation(action: String, reason: String, details: [String: Any]) async throws {
        let violation = PolicyViolation(
            action: action,
            reason: reason,
            details: details,
            timestamp: Int(Date().timeIntervalSince1970)
        )

        // Store violation in database for audit trail
        try await dbActor.execute("""
            INSERT INTO policy_violations (action, reason, details, timestamp)
            VALUES (?, ?, ?, ?)
        """, parameters: [
            dbp(violation.action),
            dbp(violation.reason),
            dbp(try JSONSerialization.data(withJSONObject: violation.details)),
            dbp(violation.timestamp)
        ])
    }
}

// MARK: - Result Data Models

public struct SemanticSearchResult {
    public let query: String
    public let engine: String
    public let results: [SearchResultItem]
}

public struct TextSearchResult {
    public let query: String
    public let results: [SearchResultItem]
}

public struct SearchResultItem {
    public let documentUnitId: String
    public let contentPreview: String
    public let filePath: String?
    public let contentType: String
    public let similarity: Float
    public let sourceArtifactPath: String
    public let sourceArtifactHash: String
}

public struct DocumentWithProvenance {
    public let documentUnit: DocumentUnit
    public let originalContent: Data
    public let custodyTrail: [CustodyStep]
}

public struct ArtifactWithVerification {
    public let path: String
    public let data: Data
    public let verifiedHash: String
    public let filePath: String?
    public let acquisitionTimestamp: Int
}

public struct CoverageReport {
    public let totalDocumentsIndexed: Int
    public let documentsWithEmbeddings: Int
    public let coveragePercentage: Double
    public let lastUpdated: Int
}

public struct RepoScanResult {
    public let pathPattern: String
    public let reason: String
    public let filesFound: Int
    public let files: [RepoFile]
    public let policyViolationLogged: Bool
}

public struct DiagnosticSearchResult {
    public let query: String
    public let results: [DiagnosticResult]
}

public struct RepoFile {
    public let path: String
    public let size: Int
    public let modifiedTime: Int

    public init(path: String, size: Int, modifiedTime: Int) {
        self.path = path
        self.size = size
        self.modifiedTime = modifiedTime
    }
}

public struct DiagnosticResult: Sendable {
    public let id: String
    public let filePath: String
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: String
    public let toolchain: String

    public init(
        id: String,
        filePath: String,
        line: Int,
        column: Int,
        message: String,
        severity: String,
        toolchain: String
    ) {
        self.id = id
        self.filePath = filePath
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
        self.toolchain = toolchain
    }
}

public struct CustodyStep {
    let type: String
    let timestamp: Int
    let method: String
    let sourceArtifact: String?
    let sourceHash: String?
}

private struct PolicyViolation {
    let action: String
    let reason: String
    let details: [String: Any]
    let timestamp: Int
}

// MARK: - Error Types

public enum AgentError: Error, LocalizedError {
    case documentNotFound(String)
    case artifactNotFound(String)
    case artifactCorrupted(String)
    case embeddingGenerationFailed
    case insufficientEmbeddingCoverage
    case insufficientFullTextCoverage
    case insufficientDiagnosticCoverage

    public var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "Document unit not found: \(id)"
        case .artifactNotFound(let hash):
            return "Artifact not found: \(hash)"
        case .artifactCorrupted(let hash):
            return "Artifact corrupted: \(hash)"
        case .embeddingGenerationFailed:
            return "Failed to generate query embedding"
        case .insufficientEmbeddingCoverage:
            return "Insufficient embedding coverage for semantic search"
        case .insufficientFullTextCoverage:
            return "Insufficient full-text coverage for text search"
        case .insufficientDiagnosticCoverage:
            return "Insufficient diagnostic coverage for search"
        }
    }
}
