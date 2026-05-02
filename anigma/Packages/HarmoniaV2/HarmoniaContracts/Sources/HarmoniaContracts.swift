// HarmoniaContracts - Public DTOs and Protocols
// Lightweight contracts module with minimal dependencies for downstream consumers

import Foundation

// MARK: - Public DTOs

/// Project record DTO
public struct ProjectRecord: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let createdAt: Date
    public let embeddingModel: String
    
    public init(id: String, name: String, createdAt: Date, embeddingModel: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.embeddingModel = embeddingModel
    }
}

/// Application status DTO
public struct AppStatus: Sendable {
    public let operatingMode: OperatingMode
    public let modeSource: ModeSource
    public let killSwitchActive: Bool
    public let killSwitchReason: String?
    public let lastDenial: DenialInfo?
    
    public init(
        operatingMode: OperatingMode,
        modeSource: ModeSource,
        killSwitchActive: Bool,
        killSwitchReason: String?,
        lastDenial: DenialInfo? = nil
    ) {
        self.operatingMode = operatingMode
        self.modeSource = modeSource
        self.killSwitchActive = killSwitchActive
        self.killSwitchReason = killSwitchReason
        self.lastDenial = lastDenial
    }
}

/// Denial information DTO
public struct DenialInfo: Sendable {
    public let violationId: UUID
    public let summary: String
    public let failedChecks: [String]
    public let timestamp: Date
    
    public init(violationId: UUID, summary: String, failedChecks: [String], timestamp: Date) {
        self.violationId = violationId
        self.summary = summary
        self.failedChecks = failedChecks
        self.timestamp = timestamp
    }
}

/// Indexing progress DTO
public struct IndexProgress: Sendable {
    public let phase: String // scanning, indexing, complete, cancelled, denied
    public let filesProcessed: Int
    public let totalFiles: Int
    public let chunksWritten: Int
    public let currentFile: String?
    public let isComplete: Bool
    public let error: String?
    /// Structured governance violation if the operation was denied
    public let violation: GovernanceViolation?
    
    public init(
        phase: String,
        filesProcessed: Int,
        totalFiles: Int,
        chunksWritten: Int,
        currentFile: String?,
        isComplete: Bool,
        error: String? = nil,
        violation: GovernanceViolation? = nil
    ) {
        self.phase = phase
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.chunksWritten = chunksWritten
        self.currentFile = currentFile
        self.isComplete = isComplete
        self.error = error
        self.violation = violation
    }
    
    public static func scanning(_ current: Int) -> IndexProgress {
        IndexProgress(phase: "Scanning...", filesProcessed: current, totalFiles: 0, chunksWritten: 0, currentFile: nil, isComplete: false)
    }
    
    public static func processing(_ current: Int, of total: Int, chunks: Int, file: String) -> IndexProgress {
        IndexProgress(phase: "Indexing", filesProcessed: current, totalFiles: total, chunksWritten: chunks, currentFile: file, isComplete: false)
    }
    
    public static func complete(total: Int, chunks: Int) -> IndexProgress {
        IndexProgress(phase: "Complete", filesProcessed: total, totalFiles: total, chunksWritten: chunks, currentFile: nil, isComplete: true)
    }
    
    public static func failed(_ error: String, processed: Int, total: Int, chunks: Int, violation: GovernanceViolation? = nil) -> IndexProgress {
        IndexProgress(phase: "Failed", filesProcessed: processed, totalFiles: total, chunksWritten: chunks, currentFile: nil, isComplete: true, error: error, violation: violation)
    }
}

/// Recall options DTO
public struct RecallOptions: Sendable {
    public let topK: Int
    public let scanLimit: Int?
    public let threshold: Float?
    public let hybrid: Bool
    public let explain: Bool
    
    public init(topK: Int = 10, scanLimit: Int? = 1000, threshold: Float? = nil, hybrid: Bool = true, explain: Bool = false) {
        self.topK = topK
        self.scanLimit = scanLimit
        self.threshold = threshold
        self.hybrid = hybrid
        self.explain = explain
    }
}

/// Recall result DTO
public struct RecallResult: Sendable {
    public let query: String
    public let projectId: String
    public let results: [RecallItem]
    public let stats: RecallStats
    
    public init(query: String, projectId: String, results: [RecallItem], stats: RecallStats) {
        self.query = query
        self.projectId = projectId
        self.results = results
        self.stats = stats
    }
}

/// Recall item DTO
public struct RecallItem: Sendable, Identifiable {
    public let id: String
    public let content: String
    public let similarity: Float
    public let rank: Int
    public let vectorRank: Int?
    public let ftsRank: Float?
    public let rrfScore: Float?
    public let metadata: [String: String]
    
    public init(id: String, content: String, similarity: Float, rank: Int, vectorRank: Int? = nil, ftsRank: Float? = nil, rrfScore: Float? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.content = content
        self.similarity = similarity
        self.rank = rank
        self.vectorRank = vectorRank
        self.ftsRank = ftsRank
        self.rrfScore = rrfScore
        self.metadata = metadata
    }
}

/// Recall statistics DTO
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

// MARK: - Supporting Types

/// Operating mode enum
public enum OperatingMode: String, Sendable, CaseIterable {
    case normal
    case restricted
    case offline
    case maintenance
}

/// Mode source enum
public enum ModeSource: String, Sendable, CaseIterable {
    case `defaultMode`
    case project
    case global
    case overrideMode
}

/// Governance violation DTO (simplified for contracts)
public struct GovernanceViolation: Sendable {
    public let id: UUID
    public let summaryMessage: String
    public let failedChecks: [GovernanceCheckFailure]
    public let timestamp: Date
    
    public init(id: UUID, summaryMessage: String, failedChecks: [GovernanceCheckFailure], timestamp: Date) {
        self.id = id
        self.summaryMessage = summaryMessage
        self.failedChecks = failedChecks
        self.timestamp = timestamp
    }
}

/// Governance check failure DTO
public struct GovernanceCheckFailure: Sendable {
    public let checkId: String
    public let checkName: String
    public let reason: String
    
    public init(checkId: String, checkName: String, reason: String) {
        self.checkId = checkId
        self.checkName = checkName
        self.reason = reason
    }
}

public enum HarmoniaRuntimeAction: String, Sendable, CaseIterable, Codable {
    case queryExecution
    case conductorExecution
    case toolExecution
    case memoryAccess
    case receiptGeneration
    case eventEmission
}

public enum HarmoniaAuthorityStage: String, Sendable, CaseIterable, Codable {
    case evaluate
    case submit
    case receipt
    case audit
}

public struct HarmoniaAuthorityMatrixEntry: Sendable, Codable, Equatable {
    public let action: HarmoniaRuntimeAction
    public let stage: HarmoniaAuthorityStage
    public let authority: String
    public let reasonCodes: [String]
    public let failClosed: Bool

    public init(
        action: HarmoniaRuntimeAction,
        stage: HarmoniaAuthorityStage,
        authority: String,
        reasonCodes: [String],
        failClosed: Bool = true
    ) {
        self.action = action
        self.stage = stage
        self.authority = authority
        self.reasonCodes = reasonCodes
        self.failClosed = failClosed
    }
}

public enum HarmoniaAuthorityMatrix {
    public static let entries: [HarmoniaAuthorityMatrixEntry] = [
        .init(action: .queryExecution, stage: .evaluate, authority: "Policy Context Evaluator", reasonCodes: ["allowed", "untrusted", "invalidFormat", "unsupportedQueryType", "invalidPolicyContext"]),
        .init(action: .queryExecution, stage: .submit, authority: "Query Policy Gate", reasonCodes: ["approved", "denied", "rateLimited", "quotaExceeded", "insufficientPermissions", "dataAccessViolation"]),
        .init(action: .queryExecution, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure", "integrityViolation", "signatureInvalid"]),
        .init(action: .queryExecution, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure", "policyDenied"]),
        .init(action: .conductorExecution, stage: .evaluate, authority: "Orchestration Evaluator", reasonCodes: ["allowed", "untrusted", "invalidFormat", "integrationPending", "policyDenied"]),
        .init(action: .conductorExecution, stage: .submit, authority: "Conductor Policy Gate", reasonCodes: ["approved", "denied", "backendFailure", "laneUnavailable"]),
        .init(action: .conductorExecution, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure", "integrityViolation"]),
        .init(action: .conductorExecution, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure", "policyDenied"]),
        .init(action: .toolExecution, stage: .evaluate, authority: "Tool Access Evaluator", reasonCodes: ["allowed", "untrusted", "invalidFormat", "unsupportedTool", "invalidPolicyContext"]),
        .init(action: .toolExecution, stage: .submit, authority: "Tool Policy Gate", reasonCodes: ["approved", "denied", "rateLimited", "quotaExceeded", "insufficientPermissions", "dataAccessViolation"]),
        .init(action: .toolExecution, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure", "integrityViolation", "signatureInvalid"]),
        .init(action: .toolExecution, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure", "policyDenied"]),
        .init(action: .memoryAccess, stage: .evaluate, authority: "Memory Access Evaluator", reasonCodes: ["allowed", "untrusted", "invalidFormat", "policyDenied"]),
        .init(action: .memoryAccess, stage: .submit, authority: "Memory Policy Gate", reasonCodes: ["approved", "denied", "quotaExceeded", "insufficientPermissions"]),
        .init(action: .memoryAccess, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure"]),
        .init(action: .memoryAccess, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure"]),
        .init(action: .receiptGeneration, stage: .evaluate, authority: "Receipt Evaluator", reasonCodes: ["allowed", "invalidFormat", "policyDenied"]),
        .init(action: .receiptGeneration, stage: .submit, authority: "Receipt Policy Gate", reasonCodes: ["approved", "denied", "integrityViolation", "signatureInvalid"]),
        .init(action: .receiptGeneration, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure", "integrityViolation"]),
        .init(action: .receiptGeneration, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure"]),
        .init(action: .eventEmission, stage: .evaluate, authority: "Event Evaluator", reasonCodes: ["allowed", "invalidFormat", "policyDenied"]),
        .init(action: .eventEmission, stage: .submit, authority: "Event Policy Gate", reasonCodes: ["approved", "denied", "rateLimited", "backendFailure"]),
        .init(action: .eventEmission, stage: .receipt, authority: "ReceiptSpine Validator", reasonCodes: ["success", "notConfigured", "backendFailure"]),
        .init(action: .eventEmission, stage: .audit, authority: "Telemetry System", reasonCodes: ["success", "notConfigured", "backendFailure"]),
    ]

    public static func entry(action: HarmoniaRuntimeAction, stage: HarmoniaAuthorityStage) -> HarmoniaAuthorityMatrixEntry {
        guard let entry = entries.first(where: { $0.action == action && $0.stage == stage }) else {
            preconditionFailure("Missing authority matrix entry for \(action.rawValue) / \(stage.rawValue)")
        }
        return entry
    }
}

// Note: HarmoniaAppClient protocol has been moved to HarmoniaV2Surface
// because it depends on StoredMemoryRecord from HarmoniaV2Core
// This keeps the contracts module truly lightweight with no dependencies

// MARK: - Additional Supporting Types

// Principal is defined in AnigmaCore.RuntimeTypes
// Import it from there instead of redefining here
// Note: StoredMemoryRecord and SimilarMemoryResult are defined in HarmoniaV2Core
// and should be imported from there, not redefined here

// MARK: - HarmoniaClient Namespace

public enum HarmoniaClient {
    public struct VaultStatusResponse: Sendable {
        public let isHealthy: Bool
        public let receiptCount: Int
        public let diskUsage: String
        public let headHash: String
        public let lastVerifiedAt: Date?

        public init(isHealthy: Bool, receiptCount: Int, diskUsage: String, headHash: String, lastVerifiedAt: Date?) {
            self.isHealthy = isHealthy
            self.receiptCount = receiptCount
            self.diskUsage = diskUsage
            self.headHash = headHash
            self.lastVerifiedAt = lastVerifiedAt
        }
    }

    public struct VaultVerifyResponse: Sendable {
        public let success: Bool
        public let message: String

        public init(success: Bool, message: String) {
            self.success = success
            self.message = message
        }
    }

    public struct VaultGCResponse: Sendable {
        public let success: Bool
        public let deletedCount: Int
        public let reclaimedSpace: String

        public init(success: Bool, deletedCount: Int, reclaimedSpace: String) {
            self.success = success
            self.deletedCount = deletedCount
            self.reclaimedSpace = reclaimedSpace
        }
    }
}

// MARK: - Harmonia Errors

public enum HarmoniaError: Error, LocalizedError, Sendable {
    case notImplemented(String)
    case internalError(String)
    case vaultError(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .internalError(let msg): return "Internal error: \(msg)"
        case .vaultError(let msg): return "Vault error: \(msg)"
        }
    }
}
