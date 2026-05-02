//
//  ContractRuntimeTypes.swift
//  ContractsCore
//
//  Contract definition for ContractRuntimeTypes in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import Foundation

/// Envelope that carries a typed payload plus evidence, metrics, and the receipt for its creation.
public struct ArtifactEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let payload: Payload
    public let evidenceRefs: [EvidenceRef]
    public let metrics: ExecutionMetrics
    public let receipt: ContractReceipt

    public init(
        schemaVersion: Int,
        payload: Payload,
        evidenceRefs: [EvidenceRef],
        metrics: ExecutionMetrics,
        receipt: ContractReceipt
    ) {
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.evidenceRefs = evidenceRefs
        self.metrics = metrics
        self.receipt = receipt
    }

    /// Returns a copy of the envelope with a new receipt, keeping payload/evidence/metrics intact.
    public func withReceipt(_ updated: ContractReceipt) -> ArtifactEnvelope<Payload> {
        ArtifactEnvelope(
            schemaVersion: schemaVersion,
            payload: payload,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: updated
        )
    }
}

/// Byte-compatible payload wrapper for type-erased artifacts.
public struct AnyArtifactPayload: Codable, Sendable {
    public let typeName: String
    public let bytes: [UInt8]

    public init(typeName: String, bytes: [UInt8]) {
        self.typeName = typeName
        self.bytes = bytes
    }

    /// Initializes with raw binary data while capturing the type name.
    public init(typeName: String, data: Data) {
        self.init(typeName: typeName, bytes: [UInt8](data))
    }

    /// Returns a `Data` view of the stored bytes.
    public var data: Data {
        Data(bytes)
    }
}

/// Type-erased artifact envelope that keeps metadata while hiding payload decoding.
public struct AnyArtifactEnvelope: Codable, Sendable {
    public let schemaVersion: Int
    public let payload: AnyArtifactPayload
    public let evidenceRefs: [EvidenceRef]
    public let metrics: ExecutionMetrics
    public let receipt: ContractReceipt

    public init(
        schemaVersion: Int,
        payload: AnyArtifactPayload,
        evidenceRefs: [EvidenceRef],
        metrics: ExecutionMetrics,
        receipt: ContractReceipt
    ) {
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.evidenceRefs = evidenceRefs
        self.metrics = metrics
        self.receipt = receipt
    }

    /// Converts a strongly typed envelope into a type-erased form.
    public init<Payload: Codable>(
        from envelope: ArtifactEnvelope<Payload>,
        encoder: JSONEncoder? = nil
    ) throws {
        let encoder = encoder ?? Self.sharedEncoder
        let payloadData = try encoder.encode(envelope.payload)
        self.init(
            schemaVersion: envelope.schemaVersion,
            payload: AnyArtifactPayload(
                typeName: String(reflecting: Payload.self),
                data: payloadData
            ),
            evidenceRefs: envelope.evidenceRefs,
            metrics: envelope.metrics,
            receipt: envelope.receipt
        )
    }

    /// Decodes the stored payload as the requested type.
    public func decodePayload<Payload: Codable>(
        as type: Payload.Type,
        decoder: JSONDecoder? = nil
    ) throws -> Payload {
        let decoder = decoder ?? Self.sharedDecoder
        return try decoder.decode(Payload.self, from: payload.data)
    }

    /// Returns a copy of the envelope with a new receipt.
    public func withReceipt(_ updated: ContractReceipt) -> AnyArtifactEnvelope {
        AnyArtifactEnvelope(
            schemaVersion: schemaVersion,
            payload: payload,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: updated
        )
    }

    private static let sharedEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let sharedDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension ArtifactEnvelope {
    /// Converts this envelope into an `AnyArtifactEnvelope`.
    public func asAnyArtifactEnvelope(encoder: JSONEncoder? = nil) throws -> AnyArtifactEnvelope {
        try AnyArtifactEnvelope(from: self, encoder: encoder)
    }
}

/// Kind of evidence reference.
public enum EvidenceRefKind: String, Codable, Sendable, CaseIterable {
    case blob
    case span
}

/// Bounding box for spatial references.
public struct BoundingBoxRef: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Byte range for offsets within a blob or source artifact.
public struct ByteRangeRef: Hashable, Codable, Sendable {
    public let start: Int
    public let length: Int

    public init(start: Int, length: Int) {
        self.start = start
        self.length = length
    }
}

/// Stable pointer to evidence. Can point to blobs or spans within a source artifact.
public struct EvidenceRef: Hashable, Codable, Sendable {
    public let kind: EvidenceRefKind
    public let contentHash: String?
    public let sourceArtifactID: String?
    public let page: Int?
    public let boundingBox: BoundingBoxRef?
    public let byteRange: ByteRangeRef?
    public let note: String?

    public init(
        kind: EvidenceRefKind,
        contentHash: String? = nil,
        sourceArtifactID: String? = nil,
        page: Int? = nil,
        boundingBox: BoundingBoxRef? = nil,
        byteRange: ByteRangeRef? = nil,
        note: String? = nil
    ) {
        self.kind = kind
        self.contentHash = contentHash
        self.sourceArtifactID = sourceArtifactID
        self.page = page
        self.boundingBox = boundingBox
        self.byteRange = byteRange
        self.note = note
    }
}

/// Execution metrics captured for every contract run.
public struct ExecutionMetrics: Codable, Sendable {
    public let wallTimeMs: Int64
    public let cpuTimeMs: Int64?
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?
    public let toolCallCount: Int
    public let retryCount: Int
    public let executor: String
    public let cacheHit: Bool

    public init(
        wallTimeMs: Int64,
        cpuTimeMs: Int64? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        toolCallCount: Int = 0,
        retryCount: Int = 0,
        executor: String,
        cacheHit: Bool = false
    ) {
        self.wallTimeMs = wallTimeMs
        self.cpuTimeMs = cpuTimeMs
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.toolCallCount = toolCallCount
        self.retryCount = retryCount
        self.executor = executor
        self.cacheHit = cacheHit
    }
}

/// Terminal status for a contract run.
public enum ContractStatus: String, Codable, Sendable, CaseIterable {
    case satisfied
    case rejected
    case quarantined
    case failed
}

/// PlatformReceipt describing what was executed, with a provenance hash for tamper detection.
public struct ContractReceipt: Codable, Sendable {
    public let contractID: ContractID
    public let runID: String
    public let sessionID: String
    public let startedAt: Date
    public let endedAt: Date
    public let status: ContractStatus
    public let inputRefs: [String]
    public let outputRefs: [String]
    public let evidenceRefs: [EvidenceRef]
    public let metrics: ExecutionMetrics
    public let loggingRingHash: String?
    public let provenanceHash: String

    public init(
        contractID: ContractID,
        runID: String,
        sessionID: String,
        startedAt: Date,
        endedAt: Date,
        status: ContractStatus,
        inputRefs: [String],
        outputRefs: [String],
        evidenceRefs: [EvidenceRef],
        metrics: ExecutionMetrics,
        loggingRingHash: String? = nil,
        provenanceHash: String = ""
    ) {
        self.contractID = contractID
        self.runID = runID
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.inputRefs = inputRefs
        self.outputRefs = outputRefs
        self.evidenceRefs = evidenceRefs
        self.metrics = metrics
        self.loggingRingHash = loggingRingHash
        self.provenanceHash = provenanceHash
    }

    enum CodingKeys: String, CodingKey {
        case contractID
        case runID
        case sessionID
        case startedAt
        case endedAt
        case status
        case inputRefs
        case outputRefs
        case evidenceRefs
        case metrics
        case loggingRingHash
        case provenanceHash
    }

    /// Returns a copy with a freshly computed provenance hash using canonical encoding.
    public func withComputedProvenanceHash() -> ContractReceipt {
        let normalizedInputs = inputRefs.sorted()
        let normalizedOutputs = outputRefs.sorted()
        let normalizedEvidence = evidenceRefs.sorted(by: ContractReceipt.sortEvidence)

        let canonical = CanonicalReceipt(
            contractID: contractID,
            runID: runID,
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            status: status,
            inputRefs: normalizedInputs,
            outputRefs: normalizedOutputs,
            evidenceRefs: normalizedEvidence,
            metrics: metrics,
            loggingRingHash: loggingRingHash
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = (try? encoder.encode(canonical)) ?? Data()
        let hash = BLAKE3Digest.hex(of: data)

        return ContractReceipt(
            contractID: contractID,
            runID: runID,
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            status: status,
            inputRefs: normalizedInputs,
            outputRefs: normalizedOutputs,
            evidenceRefs: normalizedEvidence,
            metrics: metrics,
            loggingRingHash: loggingRingHash,
            provenanceHash: hash
        )
    }

    private static func sortEvidence(lhs: EvidenceRef, rhs: EvidenceRef) -> Bool {
        let lhsKey = [
            lhs.sourceArtifactID ?? "",
            lhs.contentHash ?? "",
            lhs.note ?? "",
            lhs.page.map(String.init) ?? ""
        ].joined(separator: "|")
        let rhsKey = [
            rhs.sourceArtifactID ?? "",
            rhs.contentHash ?? "",
            rhs.note ?? "",
            rhs.page.map(String.init) ?? ""
        ].joined(separator: "|")
        return lhsKey < rhsKey
    }

    /// Canonical view of the receipt used for hashing (excludes the hash itself).
    private struct CanonicalReceipt: Codable {
        let contractID: ContractID
        let runID: String
        let sessionID: String
        let startedAt: Date
        let endedAt: Date
        let status: ContractStatus
        let inputRefs: [String]
        let outputRefs: [String]
        let evidenceRefs: [EvidenceRef]
        let metrics: ExecutionMetrics
        let loggingRingHash: String?
    }

    /// Creates a minimal receipt for testing and placeholder scenarios.
    public static func placeholder(
        contractID: ContractID,
        runID: String,
        sessionID: String,
        status: ContractStatus,
        startedAt: Date,
        endedAt: Date,
        inputRefs: [String] = [],
        outputRefs: [String] = [],
        evidenceRefs: [EvidenceRef] = [],
        metrics: ExecutionMetrics,
        loggingRingHash: String? = nil
    ) -> ContractReceipt {
        ContractReceipt(
            contractID: contractID,
            runID: runID,
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            status: status,
            inputRefs: inputRefs,
            outputRefs: outputRefs,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            loggingRingHash: loggingRingHash,
            provenanceHash: ""
        )
    }
}

/// Opaque reference to a logging ring implementation supplied by higher-level modules.
public struct ContractLoggingRingReference: @unchecked Sendable {
    public let base: AnyObject

    public init(_ base: some AnyObject & Sendable) {
        self.base = base
    }
}

/// Budgets and trust context handed to contract executors.
public struct ContractContext: Sendable {
    public let contractID: ContractID
    public let runID: String
    public let sessionID: String
    public let trustTier: TrustTier
    public let securityZone: SecurityZone
    public let budgets: ContractBudgets
    public let auditLogger: AuditLogging?
    public let evidenceRecorder: EvidenceRecording?
    public let executorIdentity: String
    public let embeddingComputer: EmbeddingComputing?
    public let testRunner: TestCommandRunning?
    public let lane: HardwareLane
    public let loggingRing: ContractLoggingRingReference?

    public init(
        contractID: ContractID,
        runID: String,
        sessionID: String,
        trustTier: TrustTier,
        securityZone: SecurityZone,
        budgets: ContractBudgets,
        auditLogger: AuditLogging? = nil,
        evidenceRecorder: EvidenceRecording? = nil,
        executorIdentity: String,
        embeddingComputer: EmbeddingComputing? = nil,
        testRunner: TestCommandRunning? = nil,
        lane: HardwareLane = .control,
        loggingRing: ContractLoggingRingReference? = nil
    ) {
        self.contractID = contractID
        self.runID = runID
        self.sessionID = sessionID
        self.trustTier = trustTier
        self.securityZone = securityZone
        self.budgets = budgets
        self.auditLogger = auditLogger
        self.evidenceRecorder = evidenceRecorder
        self.executorIdentity = executorIdentity
        self.embeddingComputer = embeddingComputer
        self.testRunner = testRunner
        self.lane = lane
        self.loggingRing = loggingRing
    }

    public init<LoggingRingReference: AnyObject & Sendable>(
        contractID: ContractID,
        runID: String,
        sessionID: String,
        trustTier: TrustTier,
        securityZone: SecurityZone,
        budgets: ContractBudgets,
        auditLogger: AuditLogging? = nil,
        evidenceRecorder: EvidenceRecording? = nil,
        executorIdentity: String,
        embeddingComputer: EmbeddingComputing? = nil,
        testRunner: TestCommandRunning? = nil,
        lane: HardwareLane = .control,
        loggingRing: LoggingRingReference? = nil
    ) {
        self.init(
            contractID: contractID,
            runID: runID,
            sessionID: sessionID,
            trustTier: trustTier,
            securityZone: securityZone,
            budgets: budgets,
            auditLogger: auditLogger,
            evidenceRecorder: evidenceRecorder,
            executorIdentity: executorIdentity,
            embeddingComputer: embeddingComputer,
            testRunner: testRunner,
            lane: lane,
            loggingRing: loggingRing.map { ContractLoggingRingReference($0) }
        )
    }
}

/// Strict budgets for execution stop conditions.
public struct ContractBudgets: Sendable, Equatable, Codable {
    public let maxWallTime: TimeInterval?
    public let maxTokens: Int?
    public let maxToolCalls: Int?
    public let maxRetries: Int

    public init(
        maxWallTime: TimeInterval? = nil,
        maxTokens: Int? = nil,
        maxToolCalls: Int? = nil,
        maxRetries: Int = 0
    ) {
        self.maxWallTime = maxWallTime
        self.maxTokens = maxTokens
        self.maxToolCalls = maxToolCalls
        self.maxRetries = maxRetries
    }
}

/// Validation failures with machine-actionable codes.
public enum ContractValidationError: Error, LocalizedError, Sendable {
    case missingField(code: String, message: String)
    case invalidSchema(code: String, message: String)
    case missingEvidence(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingField(_, let message):
            return message
        case .invalidSchema(_, let message):
            return message
        case .missingEvidence(_, let message):
            return message
        }
    }

    /// Stable code for audit trails.
    public var code: String {
        switch self {
        case .missingField(let code, _): return code
        case .invalidSchema(let code, _): return code
        case .missingEvidence(let code, _): return code
        }
    }
}

/// Execution-level failures with explicit codes and reasons.
public enum ContractExecutionError: Error, LocalizedError, Sendable {
    case budgetExceeded(code: String, message: String)
    case deniedToolAccess(code: String, message: String)
    case timeout(code: String, message: String)
    case quarantined(code: String, message: String)
    case underlying(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .budgetExceeded(_, let message): return message
        case .deniedToolAccess(_, let message): return message
        case .timeout(_, let message): return message
        case .quarantined(_, let message): return message
        case .underlying(_, let message): return message
        }
    }

    /// Stable code for telemetry and receipts.
    public var code: String {
        switch self {
        case .budgetExceeded(let code, _): return code
        case .deniedToolAccess(let code, _): return code
        case .timeout(let code, _): return code
        case .quarantined(let code, _): return code
        case .underlying(let code, _): return code
        }
    }
}
