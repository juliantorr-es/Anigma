//
//  ForensicMetadataTracker.swift
//  CathedralModule
//
//  Document lifecycle tracking with chain-of-custody evidence
//

import Foundation
import ContractsCore

// MARK: - Forensic Metadata Tracker

/// Tracks document lifecycle with complete chain-of-custody
public actor ForensicMetadataTracker {
    private var documentMetadata: [String: DocumentMetadata] = [:]
    private let evidenceSubstrate: EvidenceSubstrate
    private let persistence: CathedralDatabasePersistence?

    public init(evidenceSubstrate: EvidenceSubstrate, persistence: CathedralDatabasePersistence? = nil) {
        self.evidenceSubstrate = evidenceSubstrate
        self.persistence = persistence
    }

    // MARK: - Document Acquisition

    /// Record document acquisition with complete metadata
    public func recordAcquisition(
        documentId: String,
        filePath: String,
        sessionId: String,
        agentId: String,
        sourceMetadata: [String: String] = [:]
    ) async throws {
        let acquisitionTime = Date()

        let metadata = DocumentMetadata(
            documentId: documentId,
            filePath: filePath,
            acquisitionTime: acquisitionTime,
            sourceMetadata: sourceMetadata,
            transformations: [],
            currentState: .acquired
        )

        documentMetadata[documentId] = metadata

        // Persist to database
        if let persistence = persistence {
            try await persistence.persistDocumentMetadata(metadata)
        }

        // Record as evidence
        let evidence = Evidence(
            type: .documentAcquisition,
            sessionId: sessionId,
            agentId: agentId,
            contentHash: documentId.blake3Hash,
            metadata: EvidenceMetadata(
                source: "ForensicMetadataTracker",
                operation: "recordAcquisition",
                parameters: [
                    "documentId": documentId,
                    "filePath": filePath,
                    "acquisitionTime": ISO8601DateFormatter().string(from: acquisitionTime)
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(evidence)
    }

    // MARK: - Document Transformation

    /// Record document transformation step
    public func recordTransformation(
        documentId: String,
        transformation: DocumentTransformation,
        sessionId: String,
        agentId: String
    ) async throws {
        guard var metadata = documentMetadata[documentId] else {
            throw CathedralError.invalidEvidenceFormat("Document \(documentId) not found")
        }

        metadata.transformations.append(transformation)
        metadata.currentState = .transformed
        documentMetadata[documentId] = metadata

        // Persist to database
        if let persistence = persistence {
            try await persistence.persistTransformation(
                documentId: documentId,
                transformation: transformation
            )
        }

        // Record as evidence
        let evidence = Evidence(
            type: .documentTransformation,
            sessionId: sessionId,
            agentId: agentId,
            contentHash: transformation.id.blake3Hash,
            metadata: EvidenceMetadata(
                source: "ForensicMetadataTracker",
                operation: "recordTransformation",
                parameters: [
                    "documentId": documentId,
                    "transformationType": transformation.type,
                    "toolName": transformation.toolName,
                    "toolVersion": transformation.toolVersion
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(evidence)
    }

    // MARK: - Metadata Retrieval

    /// Get complete document metadata with chain-of-custody
    public func getDocumentMetadata(documentId: String) async -> DocumentMetadata? {
        // Check in-memory first
        if let metadata = documentMetadata[documentId] {
            return metadata
        }

        // Fall back to database
        if let persistence = persistence {
            return try? await persistence.getDocumentMetadata(documentId: documentId)
        }

        return nil
    }

    /// Get all documents in session
    public func getSessionDocuments(sessionId: String) async -> [DocumentMetadata] {
        return Array(documentMetadata.values)
    }
}

// MARK: - Document Metadata

public struct DocumentMetadata: Sendable, Codable {
    public let documentId: String
    public let filePath: String
    public let acquisitionTime: Date
    public let sourceMetadata: [String: String]
    public var transformations: [DocumentTransformation]
    public var currentState: DocumentState

    public init(
        documentId: String,
        filePath: String,
        acquisitionTime: Date,
        sourceMetadata: [String: String],
        transformations: [DocumentTransformation],
        currentState: DocumentState
    ) {
        self.documentId = documentId
        self.filePath = filePath
        self.acquisitionTime = acquisitionTime
        self.sourceMetadata = sourceMetadata
        self.transformations = transformations
        self.currentState = currentState
    }
}

public enum DocumentState: String, Sendable, Codable {
    case acquired = "acquired"
    case transformed = "transformed"
    case indexed = "indexed"
    case archived = "archived"
}

// MARK: - Document Transformation

public struct DocumentTransformation: Sendable, Codable {
    public let id: String
    public let type: String
    public let toolName: String
    public let toolVersion: String
    public let timestamp: Date
    public let inputHash: String
    public let outputHash: String
    public let parameters: [String: String]

    public init(
        id: String = UUID().uuidString,
        type: String,
        toolName: String,
        toolVersion: String,
        timestamp: Date = Date(),
        inputHash: String,
        outputHash: String,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.toolName = toolName
        self.toolVersion = toolVersion
        self.timestamp = timestamp
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.parameters = parameters
    }
}
