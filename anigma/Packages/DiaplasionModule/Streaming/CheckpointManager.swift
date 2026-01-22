//
//  CheckpointManager.swift
//  DiaplasionModule
//
//  Manages checkpoints for resumable document processing.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Manages checkpoints for resumable document processing operations.
public struct CheckpointManager: Sendable {
    
    // MARK: - Configuration
    
    /// Directory for storing checkpoints
    public let checkpointDirectory: URL
    
    /// Enable automatic checkpoint cleanup
    public let enableCleanup: Bool
    
    /// Maximum age for checkpoints before cleanup (in seconds)
    public let maxCheckpointAge: TimeInterval
    
    // MARK: - Initialization
    
    public init(
        checkpointDirectory: URL? = nil,
        enableCleanup: Bool = true,
        maxCheckpointAge: TimeInterval = 24 * 60 * 60 // 24 hours
    ) {
        self.checkpointDirectory = checkpointDirectory ?? DiaplasionConfiguration.getEffectiveCheckpointDirectory()
        self.enableCleanup = enableCleanup
        self.maxCheckpointAge = maxCheckpointAge
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: self.checkpointDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Checkpoint Operations
    
    /// Save a checkpoint for a processing operation.
    public func saveCheckpoint<T: Codable>(
        entityId: EntityID,
        operationType: String,
        data: T,
        metadata: [String: String] = [:]
    ) throws {
        let checkpoint = Checkpoint(
            entityId: entityId,
            operationType: operationType,
            timestamp: Date(),
            data: data,
            metadata: metadata
        )
        
        let checkpointFile = checkpointFileURL(for: entityId, operationType: operationType)
        let checkpointData = try JSONEncoder().encode(checkpoint)
        
        // Write to temporary file first, then move atomically
        let tempFile = checkpointFile.appendingPathExtension("tmp")
        try checkpointData.write(to: tempFile)
        _ = try FileManager.default.replaceItem(at: checkpointFile, withItemAt: tempFile, 
                                               backupItemName: nil, options: [], 
                                               resultingItemURL: nil)
        
        await Logger.shared.debug(
            "Saved checkpoint for entity \(entityId), operation: \(operationType)",
            category: "Diaplasion"
        )
    }
    
    /// Load a checkpoint for a processing operation.
    public func loadCheckpoint<T: Codable>(
        entityType: T.Type,
        entityId: EntityID,
        operationType: String
    ) throws -> Checkpoint<T>? {
        let checkpointFile = checkpointFileURL(for: entityId, operationType: operationType)
        
        guard FileManager.default.fileExists(atPath: checkpointFile.path) else {
            return nil
        }
        
        let checkpointData = try Data(contentsOf: checkpointFile)
        let checkpoint = try JSONDecoder().decode(Checkpoint<T>.self, from: checkpointData)
        
        await Logger.shared.debug(
            "Loaded checkpoint for entity \(entityId), operation: \(operationType)",
            category: "Diaplasion"
        )
        
        return checkpoint
    }
    
    /// Check if a checkpoint exists for an operation.
    public func hasCheckpoint(entityId: EntityID, operationType: String) -> Bool {
        let checkpointFile = checkpointFileURL(for: entityId, operationType: operationType)
        return FileManager.default.fileExists(atPath: checkpointFile.path)
    }
    
    /// Delete a checkpoint for an operation.
    public func deleteCheckpoint(entityId: EntityID, operationType: String) throws {
        let checkpointFile = checkpointFileURL(for: entityId, operationType: operationType)
        
        if FileManager.default.fileExists(atPath: checkpointFile.path) {
            try FileManager.default.removeItem(at: checkpointFile)
            
            await Logger.shared.debug(
                "Deleted checkpoint for entity \(entityId), operation: \(operationType)",
                category: "Diaplasion"
            )
        }
    }
    
    /// Delete all checkpoints for an entity.
    public func deleteAllCheckpoints(entityId: EntityID) throws {
        let entityCheckpoints = try findAllCheckpoints(for: entityId)
        
        for checkpointFile in entityCheckpoints {
            try FileManager.default.removeItem(at: checkpointFile)
        }
        
        await Logger.shared.debug(
            "Deleted all checkpoints for entity \(entityId)",
            category: "Diaplasion"
        )
    }
    
    /// Get list of available checkpoints for an entity.
    public func getAvailableCheckpoints(entityId: EntityID) throws -> [CheckpointInfo] {
        let entityCheckpoints = try findAllCheckpoints(for: entityId)
        var checkpointInfos: [CheckpointInfo] = []
        
        for checkpointFile in entityCheckpoints {
            do {
                let checkpointData = try Data(contentsOf: checkpointFile)
                if let checkpointInfo = try? JSONDecoder().decode(CheckpointInfoWrapper.self, from: checkpointData) {
                    checkpointInfos.append(checkpointInfo.info)
                }
            } catch {
                await Logger.shared.warning(
                    "Failed to read checkpoint info from \(checkpointFile.lastPathComponent): \(error)",
                    category: "Diaplasion"
                )
            }
        }
        
        return checkpointInfos.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Clean up old checkpoints.
    public func cleanupOldCheckpoints() throws {
        guard enableCleanup else { return }
        
        let cutoffDate = Date().addingTimeInterval(-maxCheckpointAge)
        let allCheckpoints = try findAllCheckpoints()
        
        var deletedCount = 0
        
        for checkpointFile in allCheckpoints {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: checkpointFile.path)
                if let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < cutoffDate {
                    try FileManager.default.removeItem(at: checkpointFile)
                    deletedCount += 1
                }
            } catch {
                await Logger.shared.warning(
                    "Failed to check/old checkpoint \(checkpointFile.lastPathComponent): \(error)",
                    category: "Diaplasion"
                )
            }
        }
        
        if deletedCount > 0 {
            await Logger.shared.info(
                "Cleaned up \(deletedCount) old checkpoints",
                category: "Diaplasion"
            )
        }
    }
    
    /// Get storage usage statistics.
    public func getStorageUsage() -> CheckpointStorageUsage {
        do {
            let allCheckpoints = try findAllCheckpoints()
            var totalSize: Int64 = 0
            var count = 0
            
            for checkpointFile in allCheckpoints {
                let attributes = try FileManager.default.attributesOfItem(atPath: checkpointFile.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
                count += 1
            }
            
            return CheckpointStorageUsage(
                totalCheckpoints: count,
                totalSizeBytes: totalSize,
                totalSizeMB: Double(totalSize) / (1024 * 1024),
                directoryPath: checkpointDirectory.path
            )
        } catch {
            await Logger.shared.error(
                "Failed to calculate checkpoint storage usage: \(error)",
                category: "Diaplasion"
            )
            return CheckpointStorageUsage(
                totalCheckpoints: 0,
                totalSizeBytes: 0,
                totalSizeMB: 0,
                directoryPath: checkpointDirectory.path
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Generate checkpoint file URL for entity and operation.
    private func checkpointFileURL(for entityId: EntityID, operationType: String) -> URL {
        let filename = "\(entityId)_\(operationType).json"
        return checkpointDirectory.appendingPathComponent(filename)
    }
    
    /// Find all checkpoint files for an entity.
    private func findAllCheckpoints(for entityId: EntityID) throws -> [URL] {
        let allCheckpoints = try findAllCheckpoints()
        let entityPrefix = "\(entityId)_"
        
        return allCheckpoints.filter { url in
            url.lastPathComponent.hasPrefix(entityPrefix)
        }
    }
    
    /// Find all checkpoint files in the directory.
    private func findAllCheckpoints() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: checkpointDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        return contents.filter { url in
            url.pathExtension == "json"
        }
    }
}

// MARK: - Supporting Types

/// A checkpoint containing processing state.
public struct Checkpoint<T: Codable>: Codable {
    public let entityId: EntityID
    public let operationType: String
    public let timestamp: Date
    public let data: T
    public let metadata: [String: String]
    
    public init(
        entityId: EntityID,
        operationType: String,
        timestamp: Date,
        data: T,
        metadata: [String: String]
    ) {
        self.entityId = entityId
        self.operationType = operationType
        self.timestamp = timestamp
        self.data = data
        self.metadata = metadata
    }
}

/// Information about a checkpoint (without the data).
public struct CheckpointInfo: Codable, Sendable {
    public let entityId: EntityID
    public let operationType: String
    public let timestamp: Date
    public let metadata: [String: String]
    
    public init(
        entityId: EntityID,
        operationType: String,
        timestamp: Date,
        metadata: [String: String]
    ) {
        self.entityId = entityId
        self.operationType = operationType
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Wrapper for extracting just the info from a checkpoint.
private struct CheckpointInfoWrapper<T: Codable>: Codable {
    let info: CheckpointInfo
    
    init(from checkpoint: Checkpoint<T>) {
        self.info = CheckpointInfo(
            entityId: checkpoint.entityId,
            operationType: checkpoint.operationType,
            timestamp: checkpoint.timestamp,
            metadata: checkpoint.metadata
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case entityId
        case operationType
        case timestamp
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.info = CheckpointInfo(
            entityId: try container.decode(EntityID.self, forKey: .entityId),
            operationType: try container.decode(String.self, forKey: .operationType),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            metadata: try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(info.entityId, forKey: .entityId)
        try container.encode(info.operationType, forKey: .operationType)
        try container.encode(info.timestamp, forKey: .timestamp)
        try container.encode(info.metadata, forKey: .metadata)
    }
}

/// Storage usage statistics for checkpoints.
public struct CheckpointStorageUsage: Sendable {
    public let totalCheckpoints: Int
    public let totalSizeBytes: Int64
    public let totalSizeMB: Double
    public let directoryPath: String
    
    public init(
        totalCheckpoints: Int,
        totalSizeBytes: Int64,
        totalSizeMB: Double,
        directoryPath: String
    ) {
        self.totalCheckpoints = totalCheckpoints
        self.totalSizeBytes = totalSizeBytes
        self.totalSizeMB = totalSizeMB
        self.directoryPath = directoryPath
    }
}

/// Checkpoint data for OCR processing.
public struct OCRCheckpoint: Codable {
    public let processedPages: [Int]
    public let pageResults: [Int: PageOCRResult]
    public let totalPages: Int
    public let processingState: OCRProcessingState
    
    public init(
        processedPages: [Int],
        pageResults: [Int: PageOCRResult],
        totalPages: Int,
        processingState: OCRProcessingState
    ) {
        self.processedPages = processedPages
        self.pageResults = pageResults
        self.totalPages = totalPages
        self.processingState = processingState
    }
}

/// OCR processing states.
public enum OCRProcessingState: String, Codable, Sendable {
    case notStarted = "not_started"
    case processing = "processing"
    case pageProcessing = "page_processing"
    case completed = "completed"
    case failed = "failed"
}

/// Checkpoint data for export operations.
public struct ExportCheckpoint: Codable {
    public let processedChunks: [Int]
    public let totalChunks: Int
    public let outputState: ExportState
    public let temporaryFiles: [String]
    
    public init(
        processedChunks: [Int],
        totalChunks: Int,
        outputState: ExportState,
        temporaryFiles: [String]
    ) {
        self.processedChunks = processedChunks
        self.totalChunks = totalChunks
        self.outputState = outputState
        self.temporaryFiles = temporaryFiles
    }
}

/// Export processing states.
public enum ExportState: String, Codable, Sendable {
    case notStarted = "not_started"
    case initializing = "initializing"
    case processing = "processing"
    case finalizing = "finalizing"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - System Integration

/// System that manages checkpoint operations.
public struct CheckpointManagementSystem: System {
    public var name: String { "CheckpointManagement" }
    
    private let checkpointManager: CheckpointManager
    
    public init(checkpointManager: CheckpointManager = CheckpointManager()) {
        self.checkpointManager = checkpointManager
    }
    
    public func update(world: World) async {
        // Periodic cleanup of old checkpoints
        let lastCleanupKey = "lastCheckpointCleanup"
        let now = Date()
        
        // Get last cleanup time from world metadata or use default
        let lastCleanupTime = await world.getMetadata(lastCleanupKey) as Date? ?? Date.distantPast
        
        if now.timeIntervalSince(lastCleanupTime) >= 3600 { // Every hour
            do {
                try checkpointManager.cleanupOldCheckpoints()
                await world.setMetadata(lastCleanupKey, value: now)
            } catch {
                await Logger.shared.error(
                    "Checkpoint cleanup failed: \(error)",
                    category: "Diaplasion"
                )
            }
        }
        
        // Handle checkpoint operations from components
        let checkpointEntities = await world.query(CheckpointOperationComponent.self)
        
        for (entity, operation) in checkpointEntities {
            do {
                try handleCheckpointOperation(operation, for: entity)
            } catch {
                await Logger.shared.error(
                    "Checkpoint operation failed for entity \(entity): \(error)",
                    category: "Diaplasion"
                )
            }
            
            // Remove operation component after processing
            await world.removeComponent(entity, CheckpointOperationComponent.self)
        }
    }
    
    private func handleCheckpointOperation(_ operation: CheckpointOperationComponent, for entity: EntityID) throws {
        switch operation.action {
        case .save(let operationType, let data, let metadata):
            try checkpointManager.saveCheckpoint(
                entityId: entity,
                operationType: operationType,
                data: data,
                metadata: metadata
            )
            
        case .load(let entityType, let operationType, let continuation):
            if let checkpoint = try checkpointManager.loadCheckpoint(
                entityType: entityType,
                entityId: entity,
                operationType: operationType
            ) {
                continuation(.success(checkpoint))
            } else {
                continuation(.failure(CheckpointError.notFound))
            }
            
        case .delete(let operationType):
            try checkpointManager.deleteCheckpoint(
                entityId: entity,
                operationType: operationType
            )
            
        case .deleteAll:
            try checkpointManager.deleteAllCheckpoints(entityId: entity)
        }
    }
}

/// Component for triggering checkpoint operations.
public struct CheckpointOperationComponent: Component {
    public let action: CheckpointAction
    
    public init(action: CheckpointAction) {
        self.action = action
    }
}

/// Checkpoint operations.
public enum CheckpointAction: Sendable {
    case save(operationType: String, data: Any, metadata: [String: String])
    case load(entityType: Any.Type, operationType: String, continuation: @Sendable (Result<Any, Error>) -> Void)
    case delete(operationType: String)
    case deleteAll
}

/// Checkpoint-specific errors.
public enum CheckpointError: LocalizedError {
    case notFound
    case corrupted
    case storageError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Checkpoint not found"
        case .corrupted:
            return "Checkpoint data is corrupted"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}