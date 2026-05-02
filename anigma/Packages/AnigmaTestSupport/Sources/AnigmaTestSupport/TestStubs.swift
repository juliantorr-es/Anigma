//
//  TestStubs.swift
//  AnigmaTestSupport
//
//  Hardened test stubs using canonical AnigmaContract types.
//  Bypassing the real governance rules is no longer permitted in tests.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore

// MARK: - Graph Semantic Version

/// Standard semantic versioning for graph components.
public struct GraphSemanticVersion: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

// MARK: - Pipeline Stubs

/// Hardened PipelineRunner for testing.
/// No longer a silent stub; now enforces contract execution errors.
public actor PipelineRunner {
    private let plan: PipelinePlan
    private let registry: ContractRegistry
    private var receipts: [ContractReceipt] = []
    
    public init(
        plan: PipelinePlan,
        registry: ContractRegistry,
        jobQueue: ContractJobQueue,
        receiptStore: ReceiptStore,
        artifactStore: PipelineArtifactStore,
        defaultBudgets: ContractBudgets = ContractBudgets(maxWallTime: 5, maxRetries: 0),
        trustTier: TrustTier = .silver,
        securityZone: SecurityZone = .restricted,
        executorIdentity: String = "pipeline-runner-test",
        embeddingComputer: EmbeddingComputing? = nil,
        testRunner: TestCommandRunning? = nil,
        grapheneEngine: GrapheneEngine = GrapheneEngine(),
        now: @escaping () -> Date = { Date() }
    ) async throws {
        self.plan = plan
        self.registry = registry
        self.receipts = []
    }
    
    public func runUntilIdle() async throws {
        throw ContractExecutionError.underlying(
            code: "test_runner_not_implemented", 
            message: "PipelineRunner.runUntilIdle() is a loud stub in TestSupport. Implement real logic or use a mock with explicit behavior."
        )
    }
    
    public func allReceipts() async -> [ContractReceipt] {
        receipts
    }
}

// MARK: - World / ECS Stubs

/// Stub world actor for testing.
public actor StubWorld {
    private var entities: [EntityId: [String: Any]] = [:]
    
    public init() {}
    
    public func addComponent<C: Component>(_ entity: EntityId, _ component: C) async {
        if entities[entity] == nil {
            entities[entity] = [:]
        }
        entities[entity]?["\(type(of: component))"] = component
    }
}

// MARK: - In-Memory Artifact Store

/// Hardened in-memory artifact store implementation using real ArtifactEnvelope.
public actor InMemoryPipelineArtifactStore: PipelineArtifactStore {
    private var store: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init() {}
    
    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>) async throws -> String {
        let id = UUID().uuidString
        store[id] = try encoder.encode(envelope)
        return id
    }
    
    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>, with id: String) async throws {
        store[id] = try encoder.encode(envelope)
    }
    
    public func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String {
        let id = preferredID ?? UUID().uuidString
        store[id] = data
        return id
    }
    
    public func load<Payload: Codable>(_ id: String, as type: Payload.Type) async throws -> ArtifactEnvelope<Payload> {
        guard let data = store[id] else {
            throw ContractExecutionError.underlying(code: "artifact_not_found", message: "ID: \(id)")
        }
        return try decoder.decode(ArtifactEnvelope<Payload>.self, from: data)
    }
    
    public func contains(_ id: String) async -> Bool {
        store[id] != nil
    }
    
    public func loadRaw(_ id: String) async throws -> (data: Data, typeName: String) {
        guard let data = store[id] else {
            throw ContractExecutionError.underlying(code: "artifact_not_found", message: "ID: \(id)")
        }
        return (data, "raw.test")
    }
    
    public func loadEnvelopeData(_ id: String) async throws -> Data {
        guard let data = store[id] else {
            throw ContractExecutionError.underlying(code: "artifact_not_found", message: "ID: \(id)")
        }
        return data
    }

    public func storeEnvelopeData(
        _ envelopeData: Data,
        schemaVersion: Int,
        contractID: String,
        sessionID: String,
        artifactKey: String,
        payloadData: Data,
        evidenceData: Data,
        metricsData: Data,
        receiptData: Data
    ) async throws {
        let id = "\(contractID):\(sessionID):\(artifactKey):\(schemaVersion)"
        store[id] = envelopeData
    }
}

// MARK: - Supporting Protocol Mocks

public protocol EmbeddingComputing: Sendable {}
public protocol TestCommandRunning: Sendable {}
public actor ContractJobQueue { public init(database: AnyObject) throws {} }
public actor ReceiptStore { 
    public init(database: AnyObject) throws {} 
    public func fetchReceipts(sessionID: String) async throws -> [ContractReceipt] { [] }
}

// MARK: - Graphene Engine Stub

public actor GrapheneEngine {
    public init() {}
    public func execute(
        graph: NodeGraph,
        inputs: [String: AnyPortValue] = [:],
        options: ExecutionOptions = .default
    ) async throws -> GraphExecutionResult {
        throw ContractExecutionError.underlying(code: "engine_not_implemented", message: "GrapheneEngine execution stubbed in test support.")
    }
}
