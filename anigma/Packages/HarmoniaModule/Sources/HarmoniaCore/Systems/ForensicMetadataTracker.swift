import HarmoniaWorkflowContracts

import ContractsCore

//
//  ForensicMetadataTracker.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import DatabaseCore
import ContractsCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit

/// Forensic document metadata tracking system
/// Captures complete chain-of-custody information for legal admissibility
public actor ForensicMetadataTracker {
    private let dbActor: any DatabaseCore.DatabaseExecutor

    public init(dbActor: any DatabaseCore.DatabaseExecutor) async throws {
        self.dbActor = dbActor
        try await createForensicSchema()
    }

    // MARK: - Document Ingestion with Forensic Metadata

    /// Record document acquisition with complete forensic metadata
    public func recordDocumentAcquisition(
        filePath: String,
        fileSize: Int64,
        acquisitionMethod: ForensicAcquisitionMethod,
        acquisitionTimestamp: Date = Date(),
        acquiringActor: String,
        actorIP: String? = nil,
        deviceContext: String? = nil,
        sourceSystem: String? = nil,
        transmissionMetadata: [String: Sendable]? = nil
    ) async throws -> String {
        let acquisitionId = UUID().uuidString.lowercased()

        // Calculate file hash
        let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let fileHash = blake3Hex(fileData)

        // Detect file type from magic bytes
        let fileType = detectFileType(fileData)

        // Extract filesystem metadata
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let fileSystemMetadata = extractFileSystemMetadata(fileAttributes)

        // Extract format-specific metadata
        let formatMetadata = try extractFormatSpecificMetadata(
            fileData: fileData,
            fileType: fileType,
            filePath: filePath
        )

        try await dbActor.execute("""
            INSERT INTO forensic_acquisitions (
                acquisition_id, file_path, file_size, file_hash, file_type,
                acquisition_method, acquisition_timestamp, acquiring_actor, actor_ip,
                device_context, source_system, transmission_metadata,
                filesystem_metadata, format_metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                dbp(acquisitionId),
                dbp(filePath),
                dbp(fileSize),
                dbp(fileHash),
                dbp(fileType.rawValue),
                dbp(acquisitionMethod.rawValue),
                dbp(Int(acquisitionTimestamp.timeIntervalSince1970)),
                dbp(acquiringActor),
                dbp(actorIP),
                dbp(deviceContext),
                dbp(sourceSystem),
                dbp(try JSONSerialization.data(withJSONObject: transmissionMetadata ?? [:], options: [])),
                dbp(try JSONSerialization.data(withJSONObject: fileSystemMetadata, options: [])),
                dbp(try JSONSerialization.data(withJSONObject: formatMetadata, options: []))
            ])

        // Create immutable original artifact
        try await createImmutableArtifact(
            acquisitionId: acquisitionId,
            filePath: filePath,
            fileData: fileData,
            fileHash: fileHash
        )
        
        return acquisitionId
    }
    
struct RecordTransformationConfiguration: Sendable {
    let sourceAcquisitionId: String
    let transformationType: String
    let transformingActor: String
    let transformationTool: String
    let toolVersion: String
    let inputHash: String
    let outputData: Data
    let outputPath: String
    let transformationParameters: [String: Sendable]?
    let purpose: String?
    
    init(
        sourceAcquisitionId: String,
        transformationType: String,
        transformingActor: String,
        transformationTool: String,
        toolVersion: String,
        inputHash: String,
        outputData: Data,
        outputPath: String,
        transformationParameters: [String: Sendable]? = nil,
        purpose: String? = nil
    ) {
        self.sourceAcquisitionId = sourceAcquisitionId
        self.transformationType = transformationType
        self.transformingActor = transformingActor
        self.transformationTool = transformationTool
        self.toolVersion = toolVersion
        self.inputHash = inputHash
        self.outputData = outputData
        self.outputPath = outputPath
        self.transformationParameters = transformationParameters
        self.purpose = purpose
    }
}

// Function signature would change to:
// func recordTransformation(config: RecordTransformationConfiguration) async throws -> String
        // Store transformed artifact
        // try await storeTransformedArtifact(
        //     transformationId: transformationId,
        //     outputPath: outputPath,
        //     outputData: outputData,
        //     outputHash: outputHash
        // )
        // 
        // // Record transformation event
        // try await dbActor.execute("""
        //     INSERT INTO forensic_transformations (
        //         transformation_id, source_acquisition_id, transformation_type,
        //         transforming_actor, transformation_tool, tool_version,
        //         input_hash, output_hash, output_path,
        //         transformation_timestamp, transformation_parameters, purpose
        //     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        //     """, parameters: [
        //         dbp(transformationId),
        //         dbp(sourceAcquisitionId),
        //         dbp(transformationType.rawValue),
        //         dbp(transformingActor),
        //         dbp(transformationTool),
        //         dbp(toolVersion),
        //         dbp(inputHash),
        //         dbp(outputHash),
        //         dbp(outputPath),
        //         dbp(timestamp),
        //         dbp(try JSONSerialization.data(withJSONObject: transformationParameters ?? [:], options: [])),
        //         dbp(purpose)
        //     ])
        // 
        // protocolVersion: String? = nil,
        // transmissionMetadata: [String: Sendable]? = nil
        // ) async throws -> String {
        //     let transmissionId = UUID().uuidString.lowercased()
        //     let timestamp = Int(Date().timeIntervalSince1970)
        // 
        //     try await dbActor.execute("""
        //         INSERT INTO forensic_transmissions (
        //             transmission_id, source_acquisition_id, transmission_type,
        //             transmitting_actor, recipient, transmission_method,
        //             protocol_version, transmission_timestamp, transmission_metadata
        //         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        //         """, parameters: [
        //             dbp(transmissionId),
        //             dbp(sourceAcquisitionId),
        //             dbp(transmissionType.rawValue),
        //             dbp(transmittingActor),
        //             dbp(recipient),
        //             dbp(transmissionMethod),
        //             dbp(protocolVersion),
        //             dbp(timestamp),
        //             dbp(try JSONSerialization.data(withJSONObject: transmissionMetadata ?? [:], options: []))
        //         ])
        // 
        //     return transmissionId
        // }

// In the function call:
// recordTransmission(config: RecordTransmissionConfiguration(
//     sourceAcquisitionId: value,
//     transmissionType: value,
//     transmittingActor: value,
//     recipient: value,
//     transmissionMethod: value,
//     protocolVersion: value,
//     transmissionMetadata: value
// ))

// In the SQL parameters array:
// parameters: [
//     dbp(transmissionId),
//     dbp(config.sourceAcquisitionId),
//     dbp(config.transmissionType.rawValue),
//     dbp(config.transmittingActor),
//     dbp(config.recipient),
//     dbp(config.transmissionMethod),
//     dbp(config.protocolVersion),
//     ...
// ]
        //         dbp(timestamp),
        //         dbp(try JSONSerialization.data(withJSONObject: transmissionMetadata ?? [:], options: []))
        //     ])
        // 
        //     return transmissionId
        // }

    // MARK: - Forensic Chain Queries

    /// Get complete forensic chain for a document
    public func getForensicChain(acquisitionId: String) async throws -> ForensicChain {
        let acquisition = try await getAcquisition(acquisitionId)
        let transformations = try await getTransformations(forAcquisition: acquisitionId)
        let transmissions = try await getTransmissions(forAcquisition: acquisitionId)

        return ForensicChain(
            acquisition: acquisition,
            transformations: transformations,
            transmissions: transmissions
        )
    }

    /// Generate forensic chain summary for legal proceedings
    public func generateChainSummary(acquisitionId: String) async throws -> ForensicChainSummary {
        let chain = try await getForensicChain(acquisitionId: acquisitionId)
        let hasUnaltered = try await hasUnalteredOriginal(acquisitionId: acquisitionId)

    return ForensicChainSummary(
        acquisitionId: acquisitionId,
        originalFileHash: chain.acquisition.fileHash,
        originalFileName: (chain.acquisition.filePath as NSString).lastPathComponent,
        acquisitionMethod: chain.acquisition.acquisitionMethod,
        acquisitionActor: chain.acquisition.acquiringActor,
        acquisitionTimestamp: chain.acquisition.acquisitionTimestamp,
        transformationCount: chain.transformations.count,
        transmissionCount: chain.transmissions.count,
        hasUnalteredOriginal: hasUnaltered,
        chainIntegrityScore: calculateChainIntegrityScore(chain)
    )
    }

    // MARK: - Private Implementation

    private func createForensicSchema() async throws {
        // Forensic acquisitions table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS forensic_acquisitions (
                acquisition_id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                file_hash TEXT NOT NULL,
                file_type TEXT NOT NULL,
                acquisition_method TEXT NOT NULL,
                acquisition_timestamp INTEGER NOT NULL,
                acquiring_actor TEXT NOT NULL,
                actor_ip TEXT,
                device_context TEXT,
                source_system TEXT,
                transmission_metadata TEXT,
                filesystem_metadata TEXT,
                format_metadata TEXT,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """)

        // Forensic transformations table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS forensic_transformations (
                transformation_id TEXT PRIMARY KEY,
                source_acquisition_id TEXT NOT NULL,
                transformation_type TEXT NOT NULL,
                transforming_actor TEXT NOT NULL,
                transformation_tool TEXT NOT NULL,
                tool_version TEXT NOT NULL,
                input_hash TEXT NOT NULL,
                output_hash TEXT NOT NULL,
                output_path TEXT NOT NULL,
                transformation_timestamp INTEGER NOT NULL,
                transformation_parameters TEXT,
                purpose TEXT,
                FOREIGN KEY (source_acquisition_id) REFERENCES forensic_acquisitions(acquisition_id)
            )
            """
        )

        // Forensic transmissions table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS forensic_transmissions (
                transmission_id TEXT PRIMARY KEY,
                source_acquisition_id TEXT NOT NULL,
                transmission_type TEXT NOT NULL,
                transmitting_actor TEXT NOT NULL,
                recipient TEXT NOT NULL,
                transmission_method TEXT NOT NULL,
                protocol_version TEXT,
                transmission_timestamp INTEGER NOT NULL,
                transmission_metadata TEXT,
                FOREIGN KEY (source_acquisition_id) REFERENCES forensic_acquisitions(acquisition_id)
            )
            """
        )

        // Immutable artifacts table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS immutable_artifacts (
                artifact_id TEXT PRIMARY KEY,
                acquisition_id TEXT NOT NULL,
                artifact_type TEXT NOT NULL,
                storage_path TEXT NOT NULL,
                artifact_hash TEXT NOT NULL,
                storage_timestamp INTEGER NOT NULL,
                FOREIGN KEY (acquisition_id) REFERENCES forensic_acquisitions(acquisition_id)
            )
            """
        )

        // Create indexes
        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_forensic_acquisitions_hash
            ON forensic_acquisitions(file_hash)
            """
        )

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_forensic_transformations_source
            ON forensic_transformations(source_acquisition_id)
            """
        )

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_forensic_transmissions_source
            ON forensic_transmissions(source_acquisition_id)
            """
        )
    }

    private func createImmutableArtifact(
        acquisitionId: String,
        filePath: String,
        fileData: Data,
        fileHash: String
    ) async throws {
        let artifactId = UUID().uuidString.lowercased()
        let storagePath = "/tmp/anigma-forensic-\(artifactId)-\(fileHash)"

        // Write immutable copy
        try fileData.write(to: URL(fileURLWithPath: storagePath))

        // Record artifact location
        try await dbActor.execute("""
            INSERT INTO immutable_artifacts (
                artifact_id, acquisition_id, artifact_type, storage_path,
                artifact_hash, storage_timestamp
            ) VALUES (?, ?, ?, ?, ?, ?)
            """, parameters: [
                dbp(artifactId),
                dbp(acquisitionId),
                dbp("original"),
                dbp(storagePath),
                dbp(fileHash),
                dbp(Int(Date().timeIntervalSince1970))
            ])
    }

    private func storeTransformedArtifact(
        transformationId: String,
        outputPath: String,
        outputData: Data,
        outputHash: String
    ) async throws {
        let artifactId = UUID().uuidString.lowercased()
        let storagePath = "/tmp/anigma-transformed-\(artifactId)-\(outputHash)"

        // Write transformed artifact
        try outputData.write(to: URL(fileURLWithPath: storagePath))

        // Record artifact location
        try await dbActor.execute("""
            INSERT INTO immutable_artifacts (
                artifact_id, transformation_id, artifact_type, storage_path,
                artifact_hash, storage_timestamp
            ) VALUES (?, ?, ?, ?, ?, ?)
            """, parameters: [
                dbp(artifactId),
                dbp(transformationId),
                dbp("transformed"),
                dbp(storagePath),
                dbp(outputHash),
                dbp(Int(Date().timeIntervalSince1970))
            ])
    }

    private func getAcquisition(_ acquisitionId: String) async throws -> ForensicAcquisition {
        let result = try await dbActor.query("""
            SELECT * FROM forensic_acquisitions WHERE acquisition_id = ?
            """, parameters: [dbp(acquisitionId)])

        guard let row = result.first else {
            throw ForensicError.acquisitionNotFound(acquisitionId)
        }

        return ForensicAcquisition(
            acquisitionId: acquisitionId,
            filePath: row.string(for: "file_path")!,
            fileSize: row.int64(for: "file_size")!,
            fileHash: row.string(for: "file_hash")!,
            fileType: ForensicFileType(rawValue: row.string(for: "file_type")!)!,
            acquisitionMethod: row.string(for: "acquisition_method")!,
            acquisitionTimestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "acquisition_timestamp")!)),
            acquiringActor: row.string(for: "acquiring_actor")!,
            actorIP: row.string(for: "actor_ip"),
            deviceContext: row.string(for: "device_context"),
            sourceSystem: row.string(for: "source_system"),
            transmissionMetadata: parseJSON(row.string(for: "transmission_metadata") ?? "{}"),
            fileSystemMetadata: parseJSON(row.string(for: "filesystem_metadata") ?? "{}"),
            formatMetadata: parseJSON(row.string(for: "format_metadata") ?? "{}")
        )
    }

    private func getTransformations(forAcquisition acquisitionId: String) async throws -> [ForensicTransformation] {
        let result = try await dbActor.query("""
            SELECT * FROM forensic_transformations
            WHERE source_acquisition_id = ?
            ORDER BY transformation_timestamp
            """, parameters: [dbp(acquisitionId)])

        return result.map { row in
            ForensicTransformation(
                transformationId: row.string(for: "transformation_id")!,
                sourceAcquisitionId: acquisitionId,
                transformationType: row.string(for: "transformation_type")!,
                transformingActor: row.string(for: "transforming_actor")!,
                transformationTool: row.string(for: "transformation_tool")!,
                toolVersion: row.string(for: "tool_version")!,
                inputHash: row.string(for: "input_hash")!,
                outputHash: row.string(for: "output_hash")!,
                outputPath: row.string(for: "output_path")!,
                transformationTimestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "transformation_timestamp")!)),
                transformationParameters: parseJSON(row.string(for: "transformation_parameters") ?? "{}"),
                purpose: row.string(for: "purpose")
            )
        }
    }

    private func getTransmissions(forAcquisition acquisitionId: String) async throws -> [ForensicTransmission] {
        let result = try await dbActor.query("""
            SELECT * FROM forensic_transmissions
            WHERE source_acquisition_id = ?
            ORDER BY transmission_timestamp
            """, parameters: [dbp(acquisitionId)])

        return result.map { row in
            ForensicTransmission(
                transmissionId: row.string(for: "transmission_id")!,
                sourceAcquisitionId: acquisitionId,
                transmissionType: row.string(for: "transmission_type")!,
                transmittingActor: row.string(for: "transmitting_actor")!,
                recipient: row.string(for: "recipient")!,
                transmissionMethod: row.string(for: "transmission_method")!,
                protocolVersion: row.string(for: "protocol_version"),
                transmissionTimestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "transmission_timestamp")!)),
                transmissionMetadata: parseJSON(row.string(for: "transmission_metadata") ?? "{}")
            )
        }
    }

    private func hasUnalteredOriginal(acquisitionId: String) async throws -> Bool {
        let result = try await dbActor.query(#"""
            SELECT COUNT(*) as count FROM immutable_artifacts
            WHERE acquisition_id = ? AND artifact_type = 'original'
            """#, parameters: [dbp(acquisitionId)])

        return (result.first?.int(for: "count") ?? 0) > 0
    }

    private func calculateChainIntegrityScore(_ chain: ForensicChain) -> Double {
        var score = 100.0

        // Deductions for missing metadata
        if chain.acquisition.actorIP == nil { score -= 5 }
        if chain.acquisition.deviceContext == nil { score -= 5 }
        if chain.acquisition.sourceSystem == nil { score -= 10 }

        // Deductions for transformation issues
        for transformation in chain.transformations {
            if transformation.purpose == nil { score -= 2 }
            if transformation.transformationParameters.isEmpty { score -= 1 }
        }

        return max(score, 0.0)
    }

    private func detectFileType(_ data: Data) -> ForensicFileType {
        guard data.count >= 8 else { return .unknown }

        // Check common file signatures
        let bytes = Array(data.prefix(16))

        // PDF
        if bytes.starts(with: [0x25, 0x50, 0x44, 0x46]) {
            return .pdf
        }

        // PNG
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return .png
        }

        // JPEG
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }

        // ZIP
        if bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]) || bytes.starts(with: [0x50, 0x4B, 0x05, 0x06]) {
            return .zip
        }

        return .unknown
    }

    private func extractFileSystemMetadata(_ attributes: [FileAttributeKey: Any]) -> [String: Sendable] {
        var metadata: [String: Sendable] = [:]

        if let size = attributes[.size] {
            metadata["fileSize"] = Int(size as! Int64)
        }

        if let creationDate = attributes[.creationDate] {
            metadata["creationDate"] = Int((creationDate as! Date).timeIntervalSince1970)
        }

        if let modificationDate = attributes[.modificationDate] {
            metadata["modificationDate"] = Int((modificationDate as! Date).timeIntervalSince1970)
        }

        if let posixPermissions = attributes[.posixPermissions] {
            metadata["permissions"] = Int(posixPermissions as! Int32)
        }

        return metadata
    }

    private func extractFormatSpecificMetadata(fileData: Data, fileType: ForensicFileType, filePath: String) throws -> [String: Sendable] {
        var metadata: [String: Sendable] = [:]

        metadata["detectedFormat"] = fileType.rawValue
        metadata["dataSize"] = fileData.count

        switch fileType {
        case .pdf:
            metadata = merge(metadata, try extractPDFMetadata(fileData))
        case .png:
            metadata = merge(metadata, try extractPNGMetadata(fileData))
        case .jpeg:
            metadata = merge(metadata, try extractJPEGMetadata(fileData))
        default:
            break
        }

        return metadata
    }

    private func extractPDFMetadata(_ data: Data) throws -> [String: Sendable] {
        // Simple PDF metadata extraction
        var metadata: [String: Sendable] = [:]

        let dataString = String(data: data, encoding: .isoLatin1) ?? ""

        // Extract PDF version
        if let versionRange = dataString.range(of: "%PDF-", options: .caseInsensitive) {
            let versionStart = versionRange.upperBound
            if let versionEnd = dataString[versionStart...].firstIndex(of: "\n") {
                let version = String(dataString[versionStart..<versionEnd]).trimmingCharacters(in: .whitespaces)
                metadata["pdfVersion"] = version
            }
        }

        return metadata
    }

    private func extractPNGMetadata(_ data: Data) throws -> [String: Sendable] {
        var metadata: [String: Sendable] = [:]

        guard data.count >= 8 else { return metadata }

        // PNG chunk parsing (simplified)
        var offset = 8 // Skip PNG signature

        while offset + 8 <= data.count {
            let chunkLength = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            let chunkType = String(data: data.subdata(in: offset + 4..<offset + 8), encoding: .ascii) ?? ""

            if chunkType == "IHDR" && offset + 8 + chunkLength <= data.count {
                let width = Int(data[offset + 8]) << 24 | Int(data[offset + 9]) << 16 | Int(data[offset + 10]) << 8 | Int(data[offset + 11])
                let height = Int(data[offset + 12]) << 24 | Int(data[offset + 13]) << 16 | Int(data[offset + 14]) << 8 | Int(data[offset + 15])
                metadata["width"] = width
                metadata["height"] = height
            }

            if chunkType == "tEXt" || chunkType == "iTXt" {
                // Text metadata chunk
                metadata["hasTextMetadata"] = true
            }

            offset += 8 + chunkLength + 4 // chunk header + data + CRC
            if offset >= data.count { break }
        }

        return metadata
    }

    private func extractJPEGMetadata(_ data: Data) throws -> [String: Sendable] {
        var metadata: [String: Sendable] = [:]

        guard data.count >= 4 else { return metadata }

        // Simple JPEG metadata extraction
        var offset = 2 // Skip SOI marker

        while offset + 4 <= data.count {
            let marker = data[offset]
            let marker2 = data[offset + 1]

            if marker == 0xFF && marker2 == 0xE0 { // APP0 marker
                let length = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
                if length > 4 && offset + 4 + length <= data.count {
                    let identifier = String(data: data.subdata(in: offset + 4..<offset + 8), encoding: .ascii) ?? ""
                    if identifier == "JFIF" {
                        metadata["jfifFormat"] = true
                    }
                }
            }

            if marker == 0xFF && (marker2 == 0xE1 || marker2 == 0xE2) { // APP1/APP2 marker
                metadata["hasExifOrXmp"] = true
            }

            if marker == 0xFF && marker2 == 0xDA { // SOS marker - start of scan
                break
            }

            // Move to next marker
            if offset + 4 <= data.count {
                let length = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
                offset += 2 + length
            } else {
                break
            }
        }

        return metadata
    }

    private func parseJSON(_ jsonString: String) -> [String: Sendable] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        var sendableJSON: [String: Sendable] = [:]
        for (key, value) in json {
            // Convert common JSON types to Sendable
            if let stringValue = value as? String {
                sendableJSON[key] = stringValue
            } else if let intValue = value as? Int {
                sendableJSON[key] = intValue
            } else if let doubleValue = value as? Double {
                sendableJSON[key] = doubleValue
            } else if let boolValue = value as? Bool {
                sendableJSON[key] = boolValue
            } else {
                // For complex types, convert to JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: value, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    sendableJSON[key] = jsonString
                } else {
                    sendableJSON[key] = NSNull()
                }
            }
        }
        return sendableJSON
    }

    private func merge(_ dict1: [String: Sendable], _ dict2: [String: Sendable]) -> [String: Sendable] {
        var merged = dict1
        for (key, value) in dict2 {
            merged[key] = value
        }
        return merged
    }

    private func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }
}

// MARK: - Supporting Types

public enum ForensicFileType: String, CaseIterable, Sendable {
    case pdf = "application/pdf"
    case png = "image/png"
    case jpeg = "image/jpeg"
    case zip = "application/zip"
    case text = "text/plain"
    case unknown = "application/octet-stream"
}

public enum ForensicAcquisitionMethod: String, CaseIterable, Sendable {
    case fileUpload = "file_upload"
    case emailAttachment = "email_attachment"
    case ftpTransfer = "ftp_transfer"
    case httpsTransfer = "https_transfer"
    case scannedDocument = "scanned_document"
    case faxTransmission = "fax_transmission"
    case apiImport = "api_import"
    case manualEntry = "manual_entry"
}

public enum ForensicTransformationType: String, CaseIterable, Sendable {
    case textExtraction = "text_extraction"
    case ocrProcessing = "ocr_processing"
    case formatConversion = "format_conversion"
    case compression = "compression"
    case decompression = "decompression"
    case encryption = "encryption"
    case decryption = "decryption"
    case watermarkRemoval = "watermark_removal"
    case metadataStripping = "metadata_stripping"
    case contentNormalization = "content_normalization"
}

public enum ForensicTransmissionType: String, CaseIterable, Sendable {
    case email = "email"
    case fax = "fax"
    case ftp = "ftp"
    case https = "https"
    case api = "api"
    case secureMessaging = "secure_messaging"
}

public struct ForensicAcquisition: Sendable {
    public let acquisitionId: String
    public let filePath: String
    public let fileSize: Int64
    public let fileHash: String
    public let fileType: ForensicFileType
    public let acquisitionMethod: String // Changed from enum to string
    public let acquisitionTimestamp: Date
    public let acquiringActor: String
    public let actorIP: String?
    public let deviceContext: String?
    public let sourceSystem: String?
    public let transmissionMetadata: [String: Sendable]
    public let fileSystemMetadata: [String: Sendable]
    public let formatMetadata: [String: Sendable]
}

public struct ForensicTransformation: Sendable {
    public let transformationId: String
    public let sourceAcquisitionId: String
    public let transformationType: String // Changed from enum to string
    public let transformingActor: String
    public let transformationTool: String
    public let toolVersion: String
    public let inputHash: String
    public let outputHash: String
    public let outputPath: String
    public let transformationTimestamp: Date
    public let transformationParameters: [String: Sendable]
    public let purpose: String?
}

public struct ForensicTransmission: Sendable {
    public let transmissionId: String
    public let sourceAcquisitionId: String
    public let transmissionType: String // Changed from enum to string
    public let transmittingActor: String
    public let recipient: String
    public let transmissionMethod: String
    public let protocolVersion: String?
    public let transmissionTimestamp: Date
    public let transmissionMetadata: [String: Sendable]
}

public struct ForensicChain: Sendable {
    public let acquisition: ForensicAcquisition
    public let transformations: [ForensicTransformation]
    public let transmissions: [ForensicTransmission]
}

public struct ForensicChainSummary: Sendable {
    public let acquisitionId: String
    public let originalFileHash: String
    public let originalFileName: String
    public let acquisitionMethod: String // Changed from enum to string
    public let acquisitionActor: String
    public let acquisitionTimestamp: Date
    public let transformationCount: Int
    public let transmissionCount: Int
    public let hasUnalteredOriginal: Bool
    public let chainIntegrityScore: Double
}

// MARK: - Error Types

enum ForensicError: Error, LocalizedError {
    case acquisitionNotFound(String)
    case transformationFailed(String)
    case metadataExtractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .acquisitionNotFound(let id):
            return "Acquisition not found: \(id)"
        case .transformationFailed(let reason):
            return "Transformation failed: \(reason)"
        case .metadataExtractionFailed(let reason):
            return "Metadata extraction failed: \(reason)"
        }
    }
}
