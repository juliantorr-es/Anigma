//
//  ToolContracts.swift
//  AnigmaPrimitives
//
//  Tool contracts and related types for Harmonia Tool Router
//  Defines the contracts that tools must follow to be safely executable by agents
//

import CryptoKit
import Foundation

/// Versioning primitive for tool contracts
public struct ToolContractVersion: Codable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Version string in format "major.minor.patch"
    public var string: String {
        return "\\(major).\\(minor).\\(patch)"
    }

    /// Creates version from string in format "major.minor.patch"
    /// - Returns nil if format is invalid
    public init?(string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return nil }

        self.major = components[0]
        self.minor = components[1]
        self.patch = components[2]
    }
}

/// Loop breaker configuration for tool calls
public struct LoopBreakerConfig: Codable, Sendable {
    /// Threshold of repeats within the window before blocking
    public let threshold: Int

    /// Window size in seconds for detection
    public let windowSeconds: Int

    /// Cooldown seconds after blocking before allowing further attempts
    public let cooldownSeconds: Int

    /// Recovery strategy the blocked agent must use
    public let requiredRecoveryStrategy: RecoveryStrategy

    public init(
        threshold: Int,
        windowSeconds: Int,
        cooldownSeconds: Int,
        requiredRecoveryStrategy: RecoveryStrategy
    ) {
        self.threshold = threshold
        self.windowSeconds = windowSeconds
        self.cooldownSeconds = cooldownSeconds
        self.requiredRecoveryStrategy = requiredRecoveryStrategy
    }
}

/// Recovery strategies for loop breaking
public enum RecoveryStrategy: String, Codable, Sendable {
    /// Replace with unified diff and preconditionHash verification
    case requireUnifiedDiff

    /// Replace with byte-range patch with preconditionHash verification
    case requireByteRangePatch

    /// Require fresh read delta (no edit operations)
    case requireFreshReadDelta

    /// Escalate to human intervention
    case escalateToHuman
}

/// Tool contract definition with versioned requirements
/// This represents the contract that a tool implementation must satisfy
public struct ToolContract: Codable, Sendable {
    /// Name of the tool
    public let toolName: String

    /// Description of what the tool does
    public let toolDescription: String

    /// Version of the contract
    public let contractVersion: ToolContractVersion

    /// Input schema for this tool (JSON Schema)
    public let inputSchema: String

    /// Output schema for this tool (JSON Schema)
    public let outputSchema: String

    /// Required capabilities for this tool to execute
    public let requiredCapabilities: [String]

    /// Loop breaker configuration for this tool
    public let loopBreakerConfig: LoopBreakerConfig

    /// Whether this tool can be run in parallel with other operations
    public let allowParallel: Bool

    /// Whether this tool modifies the system (vs read-only access)
    public let modifiesSystem: Bool

    public init(
        toolName: String,
        toolDescription: String,
        contractVersion: ToolContractVersion,
        inputSchema: String,
        outputSchema: String,
        requiredCapabilities: [String],
        loopBreakerConfig: LoopBreakerConfig = LoopBreakerConfig(
            threshold: 3,
            windowSeconds: 60,
            cooldownSeconds: 300,
            requiredRecoveryStrategy: .requireUnifiedDiff
        ),
        allowParallel: Bool = false,
        modifiesSystem: Bool = false
    ) {
        self.toolName = toolName
        self.toolDescription = toolDescription
        self.contractVersion = contractVersion
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.requiredCapabilities = requiredCapabilities
        self.loopBreakerConfig = loopBreakerConfig
        self.allowParallel = allowParallel
        self.modifiesSystem = modifiesSystem
    }
}

/// Result of a tool call with structured response format
public struct ToolCallResponse: Codable, Sendable {
    /// Status of the tool execution
    public let status: ToolCallStatus

    /// The optional result payload (if status is successful)
    public let result: Data?

    /// The tool name that was called
    public let toolName: String

    /// ID of the evidence bundle documenting this call
    public let evidenceId: String?

    /// Deterministic next action the agent should take (if loop was detected)
    public let nextAction: String?

    /// Human-readable diagnosis string (if there was an error or loop detected)
    public let diagnosis: String?

    /// Recovery strategy that the agent should follow (if loop was detected)
    public let recoveryStrategy: RecoveryStrategy?

    /// Timestamp when this response was generated
    public let timestampMs: Int64

    public init(
        status: ToolCallStatus,
        result: Data? = nil,
        toolName: String,
        evidenceId: String? = nil,
        nextAction: String? = nil,
        diagnosis: String? = nil,
        recoveryStrategy: RecoveryStrategy? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.status = status
        self.result = result
        self.toolName = toolName
        self.evidenceId = evidenceId
        self.nextAction = nextAction
        self.diagnosis = diagnosis
        self.recoveryStrategy = recoveryStrategy
        self.timestampMs = timestampMs
    }
}

/// Status of a tool call
public enum ToolCallStatus: String, Codable, Sendable {
    /// Tool call completed successfully
    case success

    /// Tool call failed with error
    case failed

    /// Tool call was blocked (e.g., loop detected)
    case blocked
}

/// Registry of all available tool contracts and session management
public final class ToolRegistry: Codable, @unchecked Sendable {
    /// Singleton instance
    public static let shared = ToolRegistry()

    /// Available tool contracts indexed by tool name
    private var contracts: [String: ToolContract] = [:]

    /// Session database configuration management
    private var sessionConfigs: [String: String] = [:]  // Store database paths

    private init() {}

    /// Register a tool contract
    /// - Parameter contract: The tool contract to register
    public func register(contract: ToolContract) {
        contracts[contract.toolName] = contract
    }

    /// Get a tool contract by name
    /// - Parameter toolName: Name of the tool
    /// - Returns: The tool contract if found, or nil if not registered
    public func contract(for toolName: String) -> ToolContract? {
        return contracts[toolName]
    }

    /// Get all available tool contracts
    /// - Returns: Array of all contracts
    public func allContracts() -> [String: ToolContract] {
        return contracts
    }

    /// Check if a tool name is registered
    /// - Parameter toolName: Name of the tool
    /// - Returns: True if the tool is registered, false otherwise
    public func isRegistered(toolName: String) -> Bool {
        return contracts[toolName] != nil
    }

    /// Register a session configuration
    /// - Parameter databasePath: The database path for this session
    /// - Parameter sessionConfigId: Unique ID for the configuration
    /// - Returns: Registration ID for the configuration
    public func registerSessionConfig(_ databasePath: String, sessionConfigId: String) -> String {
        sessionConfigs[sessionConfigId] = databasePath
        return sessionConfigId
    }

    /// Get a session configuration by ID
    /// - Parameter sessionConfigId: ID of the session configuration
    /// - Returns: The database path if found, or nil if not registered
    public func sessionConfig(for sessionConfigId: String) -> String? {
        return sessionConfigs[sessionConfigId]
    }
}

/// Tool call request with signature for loop detection
public struct ToolCallRequest: Codable, Sendable {
    /// Name of the tool being called
    public let toolName: String

    /// Session identifier
    public let sessionId: String

    /// File path the tool is operating on (if applicable)
    public let filePath: String?

    /// Serialized parameters of the call
    public let parameters: String

    /// Timestamp when this request was created
    public let timestampMs: Int64

    /// Computed fingerprint for this request
    public var fingerprint: String {
        let components = [toolName, sessionId, filePath ?? "", parameters]
        let combined = components.joined(separator: "|")

        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    public init(
        toolName: String,
        sessionId: String,
        filePath: String? = nil,
        parameters: String
    ) {
        self.toolName = toolName
        self.sessionId = sessionId
        self.filePath = filePath
        self.parameters = parameters
        self.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
    }
}

/// Evidence recorder for recording loop breaker events.
///
/// Note: This protocol is specifically for tool call loop detection events.
/// For general evidence recording, use `ContractsCore.EvidenceRecording`.
public protocol LoopEvidenceRecorder: Sendable {
    /// Record a loop breaker event
    func recordLoopEvent(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: Sendable]
    ) async throws
}

/// Deprecated: Use `LoopEvidenceRecorder` instead.
@available(
    *, deprecated, renamed: "LoopEvidenceRecorder",
    message: "Renamed to LoopEvidenceRecorder to clarify its loop-specific purpose"
)
public typealias EvidenceRecorder = LoopEvidenceRecorder

/// Loop breaker event types
public enum LoopEvent: String, Codable, Sendable {
    /// Call attempt with loop detected
    case loopDetected

    /// Call was blocked due to loop
    case callBlocked

    /// Call was allowed with warning
    case warningIssued

    /// Call was allowed normally
    case callAllowed
}

/// Statistics for loop breaker monitoring
public struct LoopBreakerStats: Codable, Sendable {
    /// Total number of calls processed
    public let totalCalls: Int

    /// Number of calls that were blocked
    public let blockedCalls: Int

    /// Number of warnings issued
    public let warningsIssued: Int

    /// Set of unique tool names called
    public let uniqueTools: Set<String>

    /// Recent call fingerprints for debugging
    public let recentCalls: [String]

    public init(
        totalCalls: Int,
        blockedCalls: Int,
        warningsIssued: Int,
        uniqueTools: Set<String>,
        recentCalls: [String]
    ) {
        self.totalCalls = totalCalls
        self.blockedCalls = blockedCalls
        self.warningsIssued = warningsIssued
        self.uniqueTools = uniqueTools
        self.recentCalls = recentCalls
    }
}
