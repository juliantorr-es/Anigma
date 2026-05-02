//
//  LocalFilesystemConnectorAdapter.swift
//  AnigmaCorporate
//
//  Local filesystem connector ingestion adapter for personal data
//  Normalizes local files into DocumentTruth inputs for Contextum ingestion
//

import Foundation
import CryptoKit
import ContextumModule
import AnigmaSystemSpine
import UniformTypeIdentifiers

/// Local filesystem connector ingestion adapter
/// Converts local files into DocumentTruth inputs for Contextum ingestion
public struct LocalFilesystemConnectorAdapter: Sendable {
    public let adapterID = "connector-ingestion/local-filesystem"
    private let contextum: Contextum
    private let policyPosture: PolicyPosture
    
    public init(contextum: Contextum, policyPosture: PolicyPosture = .defaultLocal) {
        self.contextum = contextum
        self.policyPosture = policyPosture
    }
    
    /// Ingest a local file into Contextum with proper DocumentTruth structure
    public func ingestLocalFile(
        at url: URL,
        sourceType: ContextSourceComponent.SourceType = .document,
        consentScope: PermissionScope,
        metadata: [String: String] = [:]
    ) async throws -> DocumentTruthIngestReceipt {
        // Validate file access and consent
        guard policyPosture.isLocalOnly || policyPosture.isNetworkAllowed else {
            throw ConnectorIngestionError.policyViolation("Local filesystem ingestion disabled by policy")
        }
        
        guard consentScope.connectedSources.contains(where: { $0.hasPrefix("Local:") }) || 
              consentScope.inclusions.contains(where: { url.path.hasPrefix($0) }) else {
            throw ConnectorIngestionError.consentDenied("No consent for local file access at: \(url.path)")
        }
        
        // Read file content
        let fileContent: String
        do {
            fileContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConnectorIngestionError.fileAccessFailed("Failed to read file: \(error.localizedDescription)")
        }
        
        // Determine document format based on file extension
        let documentFormat: DocumentTruthSourceFormat
        let mimeType: String
        
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            documentFormat = .markdown
            mimeType = "text/markdown"
        case "html", "htm":
            documentFormat = .html
            mimeType = "text/html"
        case "pdf":
            documentFormat = .pdf
            mimeType = "application/pdf"
        case "txt", "text":
            documentFormat = .plainText
            mimeType = "text/plain"
        default:
            documentFormat = .plainText
            mimeType = "text/plain"
        }
        
        // Create DocumentTruth ingest input
        let ingestInput = DocumentTruthIngestInput(
            format: documentFormat,
            content: fileContent,
            pdfLayout: nil,  // Would be populated for PDF files
            mimeType: mimeType,
            canonicalRef: "local-file://\(url.path)",
            uri: url.absoluteString,
            title: url.lastPathComponent,
            metadata: metadata
        )
        
        // Create ContextSourceComponent for Contextum ingestion
        let sourceComponent = ContextSourceComponent(
            sourceId: UUID().uuidString,
            sourceType: sourceType,
            artifactHash: try await computeFileHash(url),
            receiptId: UUID().uuidString,
            timestamp: Date(),
            metadata: [
                "connector_adapter": adapterID,
                "source_path": url.path,
                "file_size": "\(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)",
                "mime_type": mimeType,
                "ingest_method": "local_filesystem",
                "consent_scope": consentScope.connectedSources.joined(separator: ",")
            ],
            uri: url.absoluteString,
            canonicalRef: "local-file://\(url.path)",
            currentHash: try await computeFileHash(url),
            mimeType: mimeType
        )
        
        // Ingest through Contextum pipeline
        let receipt = try await contextum.ingestDocumentTruth(
            source: sourceComponent,
            input: ingestInput
        )
        
        return receipt
    }
    
    /// Ingest multiple local files with batch processing
    public func ingestLocalFiles(
        at urls: [URL],
        consentScope: PermissionScope
    ) async throws -> [DocumentTruthIngestReceipt] {
        var receipts: [DocumentTruthIngestReceipt] = []
        
        for url in urls {
            do {
                let receipt = try await ingestLocalFile(at: url, consentScope: consentScope)
                receipts.append(receipt)
            } catch {
                // Log individual file failures but continue with others
                print("⚠️  Local file ingestion failed for \(url.lastPathComponent): \(error.localizedDescription)")
                continue
            }
        }
        
        return receipts
    }
    
    /// Compute SHA-256 hash of file for content addressing
    private func computeFileHash(_ url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Connector Ingestion Errors

public enum ConnectorIngestionError: Error, Sendable {
    case policyViolation(String)
    case consentDenied(String)
    case fileAccessFailed(String)
    case parsingFailed(String)
    case contextumIngestionFailed(String)
    case networkRequestFailed(String)
    
    public var localizedDescription: String {
        switch self {
        case .policyViolation(let message): return "Policy violation: \(message)"
        case .consentDenied(let message): return "Consent denied: \(message)"
        case .fileAccessFailed(let message): return "File access failed: \(message)"
        case .parsingFailed(let message): return "Parsing failed: \(message)"
        case .contextumIngestionFailed(let message): return "Contextum ingestion failed: \(message)"
        case .networkRequestFailed(let message): return "Network request failed: \(message)"
        }
    }
}

// MARK: - Default Policy Postures

public extension PolicyPosture {
    static var `defaultLocal`: PolicyPosture {
        PolicyPosture(
            isLocalOnly: true,
            isNetworkAllowed: false,
            retentionPolicy: "forever",
            allowDerivedArtifacts: true
        )
    }
    
    static var localWithNetworkFallback: PolicyPosture {
        PolicyPosture(
            isLocalOnly: false,
            isNetworkAllowed: true,
            retentionPolicy: "30days",
            allowDerivedArtifacts: true
        )
    }
}

// MARK: - Connector Ingestion Receipt

public struct ConnectorIngestionReceipt: Sendable {
    public let receiptID: String
    public let sourceID: String
    public let documentID: String
    public let chunkCount: Int
    public let timestamp: Date
    public let adapterID: String
    public let metadata: [String: String]
    
    public init(
        receiptID: String,
        sourceID: String,
        documentID: String,
        chunkCount: Int,
        timestamp: Date,
        adapterID: String,
        metadata: [String: String]
    ) {
        self.receiptID = receiptID
        self.sourceID = sourceID
        self.documentID = documentID
        self.chunkCount = chunkCount
        self.timestamp = timestamp
        self.adapterID = adapterID
        self.metadata = metadata
    }
}
