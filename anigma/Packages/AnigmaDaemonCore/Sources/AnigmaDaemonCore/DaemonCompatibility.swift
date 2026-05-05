import Foundation
import Darwin
import CathedralModule
import DatabaseCore
import AnigmaPrimitives
import struct ContextumModule.EmbeddingComputeResult
import protocol ContextumModule.EmbeddingComputing
import struct ContextumModule.ModelRegistryEntry
import protocol ContextumModule.ModelRegistryProtocol
import class ModelRegistry.ModelRegistryStore
import VectorumModule
import OSLog

private let httpTransportLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "HTTPTransport")

actor APIKeyManager {
    private let database: any DatabaseExecutor
    private let tokenManager: CapabilityTokenManager

    init(database: any DatabaseExecutor, tokenManager: CapabilityTokenManager) {
        self.database = database
        self.tokenManager = tokenManager
    }

    func initializeStorage() async throws {
        _ = try await database.query("SELECT 1")
    }

    func exchangeForKeyToken(_ apiKey: String, clientName: String) async throws -> CapabilityToken {
        let scopes = ["system.read", "job.submit", "job.read", "vault.read", "vault.write"]
        return await tokenManager.mintToken(clientName: "\(clientName):\(apiKey.prefix(8))", requestedScopes: scopes)
    }
}

// HTTP Server moved to Services/HTTPServer.swift

// MARK: - JobEventHub
    func publish() async {}
}

actor SignalManager {
    func cleanup() async {}
}

struct ResourceThresholds: Sendable {
    let maxMemoryMB: Int
    let maxCPUPercent: Double
    let maxDiskUsagePercent: Double
}

struct ResourceMonitorEvent: Sendable {
    let kind: String
    let message: String
}

actor ResourceMonitor {
    private let thresholds: ResourceThresholds
    private var handler: (@Sendable (ResourceMonitorEvent) async -> Void)?

    init(thresholds: ResourceThresholds) {
        self.thresholds = thresholds
    }

    func registerEventHandler(_ handler: @escaping @Sendable (ResourceMonitorEvent) async -> Void) async {
        self.handler = handler
        _ = thresholds
    }

    func startMonitoring() async {}

    func stopMonitoring() async {}
}

// MARK: - PlanCompiler Shim

public struct EvidenceDigest: Sendable, Codable {
    public let hash: String
    public let dependencies: [String]
    
    public init(hash: String = "", dependencies: [String] = []) {
        self.hash = hash
        self.dependencies = dependencies
    }
}

public struct PlanStep: Sendable, Codable {
    public let id: String
    public let operation: String
    
    public init(id: String = UUID().uuidString, operation: String = "") {
        self.id = id
        self.operation = operation
    }
}

public enum PlanStatus: String, CaseIterable, Sendable, Codable {
    case blocked = "blocked"
    case approved = "approved"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
}

public enum PlanReason: String, Sendable, Codable {
    case pending = "pending"
    case evidenceValidated = "evidence_validated"
}

public struct SimplePlan: Sendable, Codable {
    public let id: String
    public let operationType: String
    public let priority: String
    public let evidenceDigest: EvidenceDigest
    public let steps: [PlanStep]
    
    public init(
        id: String = UUID().uuidString,
        operationType: String,
        priority: String,
        evidenceDigest: EvidenceDigest = EvidenceDigest(),
        steps: [PlanStep] = []
    ) {
        self.id = id
        self.operationType = operationType
        self.priority = priority
        self.evidenceDigest = evidenceDigest
        self.steps = steps
    }
}

actor PlanCompiler {
    init(dbActor: any DatabaseCore.DatabaseExecutor, evidenceSubstrate: EvidenceSubstrate) {
        _ = dbActor
        _ = evidenceSubstrate
    }
    
    public func generatePlan(request: any Sendable) async throws -> SimplePlan {
        return SimplePlan(
            operationType: "unknown",
            priority: "medium"
        )
    }
    
    // For compatibility with code expecting generateEvidenceProducedPlan
    public func generateEvidenceProducedPlan(request: any Sendable) async throws -> SimplePlan {
        return SimplePlan(
            operationType: "unknown",
            priority: "medium"
        )
    }
}

// MARK: - PlanRequest Shim

public struct PlanRequest: Sendable {
    public let sessionId: String?
    public let operationType: String
    public let parameters: [String: String]
    public let priority: Priority
    
    public enum Priority: String, CaseIterable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    public init(
        sessionId: String? = nil,
        operationType: String,
        parameters: [String: String] = [:],
        priority: Priority
    ) {
        self.sessionId = sessionId
        self.operationType = operationType
        self.parameters = parameters
        self.priority = priority
    }
}

public struct ConcreteEmbeddingComputing {
    public let base: DeterministicEmbeddingComputer

    public init(base: DeterministicEmbeddingComputer) {
        self.base = base
    }
}

extension ConcreteEmbeddingComputing: EmbeddingComputing {
    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> EmbeddingComputeResult {
        let result = try await base.computeEmbeddings(
            modelID: modelID,
            modelVersion: modelVersion,
            inputs: inputs,
            normalize: normalize
        )
        return EmbeddingComputeResult(
            vectors: result.vectors,
            dimension: result.dimension,
            inputHashes: result.inputHashes
        )
    }
}

public actor ConcreteModelRegistry {
    private let registry: ModelRegistryStore

    public init(registry: ModelRegistryStore) {
        self.registry = registry
    }

    public func find(id: String) async throws -> ModelRegistryEntry? {
        guard let entry = try await registry.find(id: id) else {
            return nil
        }
        return ModelRegistryEntry(id: entry.id, spec: entry.spec)
    }

    public func recordUsage(_ id: String) async throws {
        try await registry.recordUsage(id)
    }
}

extension ConcreteModelRegistry: ModelRegistryProtocol {}

// HTTP types moved to Services/HTTPServer.swift

// MARK: - Missing Service Shims (Phase 4 Implementation)

public struct EvidenceViolation: Sendable, Codable {
    public let type: String
    public let message: String
    public let severity: String
    
    public init(type: String = "", message: String = "", severity: String = "") {
        self.type = type
        self.message = message
        self.severity = severity
    }
}

public struct PlanVerificationResult: Sendable, Codable {
    public let isValid: Bool
    public let violations: [EvidenceViolation]
    public let dependencyCount: Int
    public let error: AnigmaErrorStatus?
    
    public init(isValid: Bool = true, violations: [EvidenceViolation] = [], dependencyCount: Int = 0, error: AnigmaErrorStatus? = nil) {
        self.isValid = isValid
        self.violations = violations
        self.dependencyCount = dependencyCount
        self.error = error
    }
}

public struct LeaseInfo: Sendable, Codable {
    public let leaseId: String
    public let expiresAt: Date
    public let resource: String
    
    public init(leaseId: String = "", expiresAt: Date = Date(), resource: String = "") {
        self.leaseId = leaseId
        self.expiresAt = expiresAt
        self.resource = resource
    }
}

public struct LeaseVerificationResult: Sendable {
    public let isValid: Bool
    public let reason: String
    
    public init(isValid: Bool, reason: String = "") {
        self.isValid = isValid
        self.reason = reason
    }
}

public actor PlanVerifier {
    public init() {}
    
    public func verifyPlan(planId: String) async throws -> PlanVerificationResult {
        return PlanVerificationResult(
            isValid: true,
            violations: [],
            dependencyCount: 0,
            error: nil
        )
    }
}

public actor LeaseManager {
    public init() {}
    
    public func acquireLease(resource: String, duration: TimeInterval) async throws -> LeaseInfo {
        return LeaseInfo(
            leaseId: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(duration),
            resource: resource
        )
    }
    
    public func releaseLease(leaseId: String) async throws {}
    
    public func verifyLease(planId: String, context: DaemonRequestContext? = nil) async throws -> LeaseVerificationResult {
        return LeaseVerificationResult(isValid: true, reason: "")
    }
}

public actor ContextumCoordinator {
    public init() {}
    
    public func transformDocument(request: AnigmaWebDocumentTransformRequest) async throws -> String {
        return "transformed"
    }
}

// MARK: - EvidenceSubstrate Extension

extension EvidenceSubstrate {
    public func bindOutputsToEvidence(planId: String, outputs: [String: Any]) async throws -> String {
        return "bound"
    }
}

// MARK: - CathedralFacade Extension  
extension CathedralFacade {
    public func generate(prompt: String, options: [String: Any] = [:]) async throws -> String {
        return "generated"
    }
    
    public func generateComplianceReport(planId: String) async throws -> String {
        return "report"
    }
}

// MARK: - Request Type Extensions

extension AnigmaWebGenerateRequest {
    public var options: [String: Any] {
        var opts: [String: Any] = [:]
        if let maxTokens = self.maxTokens {
            opts["maxTokens"] = maxTokens
        }
        return opts
    }
}

extension AnigmaWebDocumentTransformRequest {
    public var options: [String: Any] {
        return [:]
    }
}
