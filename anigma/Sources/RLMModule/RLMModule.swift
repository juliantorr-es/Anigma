import Foundation
import AnigmaCore
import DatabaseCore
import CapsuleCore
import CapabilityCore
import ContextumModule
import ArtifactStoreModule
import HarmoniaV2Surface
import OSLog

private let rlmLogger = Logger(subsystem: "com.anigma.rlm", category: "module")

/// Runtime Loop Manager (RLM) module for implementing the Anigma-style
/// "recursive language model" pattern where Swift governs and capsules compute.
///
/// ## Overview
///
/// The RLM module provides a governed environment for models to interact with
/// context through auditable operations. It implements the vision:
/// - "Context as environment" - structured store with stable IDs and indexes
/// - "Swift governs, capsules compute" - governance layer over native operations
/// - "Evidence substrate" - every operation produces verifiable receipts
///
/// ## Key Components
///
/// 1. **RLMGovernor** - Manages runtime loops with budgets, policies, scheduling
/// 2. **ContextEnvironment** - Structured store of sources with span references
/// 3. **RLMCapability** - Tool interface for environment operations
/// 4. **Integration** with existing capsules for indexing, retrieval, aggregation
///
/// ## Usage
///
/// ```swift
/// // Initialize RLM module
/// let rlm = try await RLMModule(
///     database: contextumDatabase,
///     artifactStore: artifactStore
/// )
///
/// // Create a governor for a runtime loop
/// let governor = try await rlm.createGovernor(
///     policy: .default,
///     budgets: .conservative
/// )
///
/// // Execute a planning loop
/// let result = try await governor.executePlanningLoop(
///     userRequest: "Analyze this document",
///     plannerModel: plannerModel,
///     workerModel: workerModel
/// )
/// ```
public struct RLMModule: Sendable {
    private let database: ContextumDatabase
    private let artifactAuthority: any ArtifactAuthority
    private let embeddingComputing: (any EmbeddingComputing)?
    
    /// Create an RLM module with the given dependencies.
    /// - Parameters:
    ///   - database: Contextum database for context storage
    ///   - artifactAuthority: Artifact authority for content-addressed storage
    ///   - embeddingComputing: Optional embedding computing provider
    public init(
        database: ContextumDatabase,
        artifactAuthority: any ArtifactAuthority,
        embeddingComputing: (any EmbeddingComputing)? = nil
    ) async throws {
        self.database = database
        self.artifactAuthority = artifactAuthority
        self.embeddingComputing = embeddingComputing
    }
    
    /// Create a new RLM governor with the given policy and budgets.
    /// - Parameters:
    ///   - policy: Governance policy for tool access and permissions
    ///   - budgets: Resource budgets for the runtime loop
    ///   - environment: Optional pre-existing context environment
    ///   - evidenceAuthority: Evidence authority for recording operations
    ///   - capsules: Dictionary of capsule wrappers for accelerated operations
    /// - Returns: Configured RLM governor ready for execution
    public func createGovernor(
        policy: RLMGovernancePolicy = .default,
        budgets: RLMResourceBudgets = .default,
        environment: ContextEnvironment? = nil,
        evidenceAuthority: (any EvidenceAuthority)? = nil,
        capsules: [String: Any] = [:]
    ) async throws -> RLMGovernor {
        let env: ContextEnvironment
        if let environment {
            env = environment
        } else {
            env = ContextEnvironment(
                contextumDatabase: database,
                artifactAuthority: artifactAuthority,
                evidenceAuthority: evidenceAuthority,
                embeddingComputing: embeddingComputing,
                capsules: capsules
            )
        }
        
        return RLMGovernor(
            policy: policy,
            budgets: budgets,
            environment: env,
            evidenceAuthority: evidenceAuthority
        )
    }
    
    /// Register RLM capability with the capability registry.
    /// - Parameters:
    ///   - registry: Capability registry to register with
    ///   - evidenceAuthority: Evidence authority for recording operations
    ///   - capsules: Dictionary of capsule wrappers for accelerated operations
    public func registerCapability(
        with registry: CapabilityRegistry,
        evidenceAuthority: (any EvidenceAuthority)? = nil,
        capsules: [String: Any] = [:]
    ) async throws {
        // Create environment
        let environment = ContextEnvironment(
            contextumDatabase: database,
            artifactAuthority: artifactAuthority,
            evidenceAuthority: evidenceAuthority,
            embeddingComputing: embeddingComputing,
            capsules: capsules
        )
        
        // Create capability provider
        let provider = RLMCapabilityProvider(
            environment: environment
        )
        
        // Register with capability registry
        await registry.register(provider: provider)
        rlmLogger.info("RLMCapability registered with ID: \(CapabilityIds.rlm, privacy: .public)")
    }
}
