//
//  BackendReadinessContracts.swift
//  AnigmaCore
//
//  Portable backend readiness contracts for PlatformRuntime governance.
//  Part of td-358315: Define backend readiness gates.
//

import Foundation

// MARK: - Backend Identification

/// Unique identifier for a backend instance
public struct BackendId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = UUID().uuidString
    }
    
    public var description: String {
        "Backend(\\{rawValue.prefix(8)})"
    }
}

/// Classification of backend types
public enum BackendKind: String, Codable, Sendable, CaseIterable {
    case database
    case inference
    case renderer
    case mlWorker
    case cliTool
    case cloudProvider
    case mediaProcessor
    case custom
}

// MARK: - Backend Lifecycle States

/// Lifecycle states for backend management
public enum BackendLifecycleState: String, Codable, Sendable, CaseIterable {
    /// Backend has been constructed but not initialized
    case uninitialized
    
    /// Backend is initializing (async setup, resource allocation)
    case initializing
    
    /// Backend is active and ready for operations
    case active
    
    /// Backend is draining (no new operations, completing existing)
    case draining
    
    /// Backend has been terminated
    case terminated
}

// MARK: - Backend Readiness States

/// Readiness states for backend execution
public enum BackendReadinessState: String, Codable, Sendable, CaseIterable {
    /// Backend is not registered with PlatformRuntime
    case unregistered
    
    /// Backend is registered but not yet ready
    case registered
    
    /// Backend is initializing (async readiness checks)
    case initializing
    
    /// Backend is ready for execution
    case ready
    
    /// Backend is degraded (limited functionality)
    case degraded
    
    /// Backend is temporarily unavailable
    case unavailable
    
    /// Backend has failed
    case failed
    
    /// Backend is draining (no new operations)
    case draining
    
    /// Backend is shutting down
    case shuttingDown
}

// MARK: - Contract Compatibility

/// Compatibility between requested and available contracts
public enum ContractCompatibility: String, Codable, Sendable, CaseIterable {
    /// Contract versions are compatible
    case compatible
    
    /// Contract versions are incompatible
    case incompatible
    
    /// Compatible but using older contract version
    case downgraded
    
    /// Compatible but using newer contract version
    case upgraded
}

// MARK: - Retry Policies

/// Strategy for retrying failed operations
public enum BackoffStrategy: String, Codable, Sendable, CaseIterable {
    /// No retry attempts
    case none
    
    /// Linear backoff (fixed delay between attempts)
    case linear
    
    /// Exponential backoff (increasing delay)
    case exponential
    
    /// Custom backoff strategy
    case custom
}

/// Policy for retrying backend operations
public struct BackendRetryPolicy: Codable, Sendable {
    /// Maximum number of retry attempts (0 = no retries)
    public let maxAttempts: Int
    
    /// Backoff strategy for retries
    public let backoffStrategy: BackoffStrategy
    
    /// Maximum timeout for retry attempts
    public let timeout: TimeInterval
    
    /// Custom backoff parameters (if applicable)
    public let customBackoff: [String: Double]?
    
    public init(
        maxAttempts: Int = 0,
        backoffStrategy: BackoffStrategy = .none,
        timeout: TimeInterval = 30.0,
        customBackoff: [String: Double]? = nil
    ) {
        self.maxAttempts = maxAttempts
        self.backoffStrategy = backoffStrategy
        self.timeout = timeout
        self.customBackoff = customBackoff
    }
}

// MARK: - Fallback Policies

/// Strategy for fallback when backend is unavailable
public enum FallbackStrategy: String, Codable, Sendable, CaseIterable {
    /// No fallback (fail fast)
    case none
    
    /// Fallback to default backend
    case defaultBackend
    
    /// Fallback to specific backend ID
    case specificBackend
    
    /// Degrade functionality (return partial results)
    case degrade
}

/// Policy for backend fallback
public struct FallbackPolicy: Codable, Sendable {
    /// Fallback strategy
    public let strategy: FallbackStrategy
    
    /// Specific backend ID for fallback (if applicable)
    public let fallbackBackendId: BackendId?
    
    /// Maximum degradation level allowed
    public let maxDegradation: Int?
    
    public init(
        strategy: FallbackStrategy = .none,
        fallbackBackendId: BackendId? = nil,
        maxDegradation: Int? = nil
    ) {
        self.strategy = strategy
        self.fallbackBackendId = fallbackBackendId
        self.maxDegradation = maxDegradation
    }
}

// MARK: - Backend Capability Contract

/// Contract defining backend capabilities and requirements
public struct BackendCapabilityContract: Codable, Sendable {
    /// Unique backend identifier
    public let backendId: BackendId
    
    /// Backend kind/category
    public let kind: BackendKind
    
    /// Contract identifier (e.g., "inference.v1")
    public let contractId: String
    
    /// Contract version
    public let contractVersion: Int
    
    /// Supported operations
    public let supportedOperations: [String]
    
    /// Minimum platform version required
    public let minPlatformVersion: String?
    
    /// Dependencies on other backends/services
    public let dependencies: [String]
    
    /// Backend-specific metadata
    public let metadata: [String: String]
    
    public init(
        backendId: BackendId,
        kind: BackendKind,
        contractId: String,
        contractVersion: Int,
        supportedOperations: [String] = [],
        minPlatformVersion: String? = nil,
        dependencies: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.backendId = backendId
        self.kind = kind
        self.contractId = contractId
        self.contractVersion = contractVersion
        self.supportedOperations = supportedOperations
        self.minPlatformVersion = minPlatformVersion
        self.dependencies = dependencies
        self.metadata = metadata
    }
}

// MARK: - Backend Readiness Check

/// Result of backend readiness verification
public struct BackendReadinessCheck: Codable, Sendable {
    /// Backend identifier
    public let backendId: BackendId
    
    /// Whether backend is ready for execution
    public let isReady: Bool
    
    /// Current readiness state
    public let state: BackendReadinessState
    
    /// Contract compatibility result
    public let contractCompatibility: ContractCompatibility
    
    /// Current lifecycle state
    public let lifecycleState: BackendLifecycleState
    
    /// Retry policy (if applicable)
    public let retryPolicy: BackendRetryPolicy?
    
    /// Fallback policy (if applicable)
    public let fallbackPolicy: FallbackPolicy?
    
    /// Last validation timestamp
    public let lastValidation: Date?
    
    /// Reason for non-ready state (if applicable)
    public let denialReason: String?
    
    /// Additional diagnostic information
    public let diagnostics: [String: String]?
    
    public init(
        backendId: BackendId,
        isReady: Bool,
        state: BackendReadinessState,
        contractCompatibility: ContractCompatibility,
        lifecycleState: BackendLifecycleState,
        retryPolicy: BackendRetryPolicy? = nil,
        fallbackPolicy: FallbackPolicy? = nil,
        lastValidation: Date? = nil,
        denialReason: String? = nil,
        diagnostics: [String: String]? = nil
    ) {
        self.backendId = backendId
        self.isReady = isReady
        self.state = state
        self.contractCompatibility = contractCompatibility
        self.lifecycleState = lifecycleState
        self.retryPolicy = retryPolicy
        self.fallbackPolicy = fallbackPolicy
        self.lastValidation = lastValidation
        self.denialReason = denialReason
        self.diagnostics = diagnostics
    }
}

// MARK: - Backend Registration Receipt

/// Receipt for backend registration
public struct BackendRegistrationReceipt: Codable, Sendable {
    /// Registered backend identifier
    public let backendId: BackendId
    
    /// Registration timestamp
    public let registeredAt: Date
    
    /// Registration context
    public let context: [String: String]?
    
    /// Evidence receipt ID (if available)
    public let evidenceReceiptId: String?
    
    public init(
        backendId: BackendId,
        registeredAt: Date = Date(),
        context: [String: String]? = nil,
        evidenceReceiptId: String? = nil
    ) {
        self.backendId = backendId
        self.registeredAt = registeredAt
        self.context = context
        self.evidenceReceiptId = evidenceReceiptId
    }
}

// MARK: - Backend Operation Context

/// Context for backend operations
public struct BackendOperationContext: Sendable {
    /// Operation identifier
    public let operationId: String
    
    /// Operation type
    public let operationType: String
    
    /// Requires evidence recording
    public let requiresEvidence: Bool
    
    /// Additional metadata
    public let metadata: [String: String]
    
    public init(
        operationId: String = UUID().uuidString,
        operationType: String,
        requiresEvidence: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.operationId = operationId
        self.operationType = operationType
        self.requiresEvidence = requiresEvidence
        self.metadata = metadata
    }
}

// MARK: - Backend Operation Protocol

/// Protocol for backend operations with evidence
public protocol BackendOperation: Sendable {
    var operationId: String { get }
    var operationType: String { get }
    var requiresEvidence: Bool { get }
}

// MARK: - Convenience Extensions

extension BackendId {
    public static func inferenceBackend() -> BackendId {
        BackendId(rawValue: "inference-backend")
    }
    
    public static func rendererBackend() -> BackendId {
        BackendId(rawValue: "renderer-backend")
    }
    
    public static func databaseBackend() -> BackendId {
        BackendId(rawValue: "database-backend")
    }
}

extension BackendCapabilityContract {
    public static func inferenceContract() -> BackendCapabilityContract {
        BackendCapabilityContract(
            backendId: .inferenceBackend(),
            kind: .inference,
            contractId: "inference.v1",
            contractVersion: 1,
            supportedOperations: ["text-generation", "embedding", "chat"]
        )
    }
    
    public static func rendererContract() -> BackendCapabilityContract {
        BackendCapabilityContract(
            backendId: .rendererBackend(),
            kind: .renderer,
            contractId: "renderer.v1",
            contractVersion: 1,
            supportedOperations: ["video-render", "audio-render", "preview"]
        )
    }
}

extension BackendReadinessCheck {
    public static func readyCheck() -> BackendReadinessCheck {
        BackendReadinessCheck(
            backendId: .inferenceBackend(),
            isReady: true,
            state: .ready,
            contractCompatibility: .compatible,
            lifecycleState: .active
        )
    }
    
    public static func notRegisteredCheck() -> BackendReadinessCheck {
        BackendReadinessCheck(
            backendId: .inferenceBackend(),
            isReady: false,
            state: .unregistered,
            contractCompatibility: .incompatible,
            lifecycleState: .uninitialized,
            denialReason: "Backend not registered with PlatformRuntime"
        )
    }
}
