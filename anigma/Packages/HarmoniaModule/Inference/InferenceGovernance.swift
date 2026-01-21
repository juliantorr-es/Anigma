//
//  InferenceGovernance.swift
//  HarmoniaModule
//
//  Governance integration for the Inference Plane.
//  Ensures inference operations respect privacy, tenant, and security policies.
//

import AnigmaCore
import ContractsCore
import Foundation
import TelemetryCore

// MARK: - Inference Governance

/// Governance checks for inference operations.
public actor InferenceGovernance {
    private var policyCache: [String: InferencePolicy] = [:]

    public init() {}

    // MARK: - Policy Management

    /// Sets the inference policy for a tenant.
    public func setPolicy(_ policy: InferencePolicy) {
        policyCache[policy.tenantId] = policy
    }

    /// Gets the inference policy for a tenant.
    public func getPolicy(forTenant tenantId: String) -> InferencePolicy {
        policyCache[tenantId] ?? InferencePolicy.default(tenantId: tenantId)
    }

    // MARK: - Validation

    /// Validates an inference task against governance policies.
    public func validate(task: InferenceTask) -> InferenceValidationResult {
        let policy = getPolicy(forTenant: task.context.tenantId)
        var issues: [InferenceGovernanceIssue] = []

        // Check if task kind is allowed
        if !policy.allowedTaskKinds.contains(task.kind) {
            issues.append(.taskKindNotAllowed(task.kind))
        }

        // Check privacy level compatibility
        if task.constraints.privacyLevel == .restricted {
            if !policy.allowRestrictedData {
                issues.append(.restrictedDataNotAllowed)
            }
            if !task.constraints.localOnly && policy.restrictedDataRequiresLocal {
                issues.append(.restrictedDataRequiresLocal)
            }
        }

        // Check remote access
        if !task.constraints.localOnly && !policy.allowRemoteInference {
            issues.append(.remoteInferenceNotAllowed)
        }

        // Check quality tier
        if let minTier = policy.minQualityTier {
            if let taskTier = task.constraints.minQualityTier, taskTier < minTier {
                issues.append(.qualityTierBelowMinimum(required: minTier, requested: taskTier))
            }
        }

        // Check autopilot vs assistive (commented out - requires InferenceConstraints.autopilotAllowed)
        // if policy.assistiveOnly && task.constraints.autopilotAllowed {
        //     issues.append(.autopilotNotAllowed)
        // }

        return InferenceValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            policy: policy
        )
    }

    /// Validates a model selection against governance policies.
    public func validateModel(
        _ model: ModelDescriptor,
        forTask task: InferenceTask
    ) -> InferenceValidationResult {
        let policy = getPolicy(forTenant: task.context.tenantId)
        var issues: [InferenceGovernanceIssue] = []

        // Check if model is allowed
        if let allowedModels = policy.allowedModels, !allowedModels.contains(model.id) {
            issues.append(.modelNotAllowed(model.id))
        }

        // Check if model is blocked
        if policy.blockedModels.contains(model.id) {
            issues.append(.modelBlocked(model.id))
        }

        // Check backend is allowed
        if !policy.allowedBackends.contains(model.backend) {
            issues.append(.backendNotAllowed(model.backend))
        }

        // Check quality tier
        if let minTier = policy.minQualityTier {
            if model.capabilities.qualityTier < minTier {
                issues.append(
                    .modelQualityBelowMinimum(
                        required: minTier, actual: model.capabilities.qualityTier))
            }
        }

        return InferenceValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            policy: policy
        )
    }

    /// Validates a node selection against governance policies.
    public func validateNode(
        _ node: ComputeNode,
        forTask task: InferenceTask
    ) -> InferenceValidationResult {
        let policy = getPolicy(forTenant: task.context.tenantId)
        var issues: [InferenceGovernanceIssue] = []

        // Check tenant scope
        if let nodeScope = node.tenantScope, nodeScope != task.context.tenantId {
            issues.append(.nodeTenantMismatch(expected: task.context.tenantId, actual: nodeScope))
        }

        // Check data residency for restricted data
        if task.constraints.privacyLevel == .restricted {
            if node.capabilities.dataResidency == .external {
                issues.append(.nodeResidencyViolation(required: .local, actual: .external))
            }
            if policy.restrictedDataRequiresLocal && node.capabilities.dataResidency != .local {
                issues.append(
                    .nodeResidencyViolation(
                        required: .local, actual: node.capabilities.dataResidency))
            }
        }

        // Check allowed residencies
        if !policy.allowedDataResidencies.contains(node.capabilities.dataResidency) {
            issues.append(.nodeResidencyNotAllowed(node.capabilities.dataResidency))
        }

        return InferenceValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            policy: policy
        )
    }

    // MARK: - Rate Limiting

    private var rateLimitState: [String: RateLimitState] = [:]

    /// Checks rate limits for a tenant.
    public func checkRateLimit(forTenant tenantId: String) -> RateLimitResult {
        let policy = getPolicy(forTenant: tenantId)
        let state = rateLimitState[tenantId] ?? RateLimitState()

        let now = Date()
        let windowStart = now.addingTimeInterval(-60)  // 1 minute window

        // Clean old entries
        var mutableState = state
        mutableState.requestTimestamps = mutableState.requestTimestamps.filter { $0 > windowStart }
        mutableState.tokenCounts = mutableState.tokenCounts.filter { $0.timestamp > windowStart }

        // Check request rate
        if mutableState.requestTimestamps.count >= policy.maxRequestsPerMinute {
            return RateLimitResult(
                allowed: false,
                reason: "Request rate limit exceeded",
                retryAfter: .seconds(60)
            )
        }

        // Check token rate
        let totalTokens = mutableState.tokenCounts.reduce(0) { $0 + $1.tokens }
        if totalTokens >= policy.maxTokensPerMinute {
            return RateLimitResult(
                allowed: false,
                reason: "Token rate limit exceeded",
                retryAfter: .seconds(60)
            )
        }

        // Record this request
        mutableState.requestTimestamps.append(now)
        rateLimitState[tenantId] = mutableState

        return RateLimitResult(
            allowed: true,
            reason: nil,
            retryAfter: nil
        )
    }

    /// Records token usage for rate limiting.
    public func recordTokenUsage(forTenant tenantId: String, tokens: Int) {
        var state = rateLimitState[tenantId] ?? RateLimitState()
        state.tokenCounts.append(TokenCount(tokens: tokens, timestamp: Date()))
        rateLimitState[tenantId] = state
    }
}

// MARK: - Inference Policy

/// Policy governing inference for a tenant.
public struct InferencePolicy: Sendable, Codable {
    public let tenantId: String
    public let allowedTaskKinds: Set<InferenceTaskKind>
    public let allowedBackends: Set<BackendKind>
    public let allowedModels: Set<String>?
    public let blockedModels: Set<String>
    public let allowedDataResidencies: Set<DataResidency>
    public let allowRemoteInference: Bool
    public let allowRestrictedData: Bool
    public let restrictedDataRequiresLocal: Bool
    public let minQualityTier: QualityTier?
    public let maxCostTier: CostTier?
    public let assistiveOnly: Bool
    public let maxRequestsPerMinute: Int
    public let maxTokensPerMinute: Int
    public let maxConcurrentTasks: Int

    public init(
        tenantId: String,
        allowedTaskKinds: Set<InferenceTaskKind> = Set(InferenceTaskKind.allCases),
        allowedBackends: Set<BackendKind> = [.mlx, .llamaCpp, .ollama, .remoteAPI],
        allowedModels: Set<String>? = nil,
        blockedModels: Set<String> = [],
        allowedDataResidencies: Set<DataResidency> = [.local, .onPremise],
        allowRemoteInference: Bool = false,
        allowRestrictedData: Bool = true,
        restrictedDataRequiresLocal: Bool = true,
        minQualityTier: QualityTier? = nil,
        maxCostTier: CostTier? = nil,
        assistiveOnly: Bool = false,
        maxRequestsPerMinute: Int = 60,
        maxTokensPerMinute: Int = 100000,
        maxConcurrentTasks: Int = 10
    ) {
        self.tenantId = tenantId
        self.allowedTaskKinds = allowedTaskKinds
        self.allowedBackends = allowedBackends
        self.allowedModels = allowedModels
        self.blockedModels = blockedModels
        self.allowedDataResidencies = allowedDataResidencies
        self.allowRemoteInference = allowRemoteInference
        self.allowRestrictedData = allowRestrictedData
        self.restrictedDataRequiresLocal = restrictedDataRequiresLocal
        self.minQualityTier = minQualityTier
        self.maxCostTier = maxCostTier
        self.assistiveOnly = assistiveOnly
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxTokensPerMinute = maxTokensPerMinute
        self.maxConcurrentTasks = maxConcurrentTasks
    }

    public static func `default`(tenantId: String) -> InferencePolicy {
        InferencePolicy(tenantId: tenantId)
    }

    public static func strict(tenantId: String) -> InferencePolicy {
        InferencePolicy(
            tenantId: tenantId,
            allowedBackends: [.mlx],
            allowedDataResidencies: [.local],
            allowRemoteInference: false,
            restrictedDataRequiresLocal: true,
            assistiveOnly: true,
            maxRequestsPerMinute: 30,
            maxTokensPerMinute: 50000
        )
    }
}

// MARK: - Validation Result

/// Result of governance validation.
public struct InferenceValidationResult: Sendable {
    public let isValid: Bool
    public let issues: [InferenceGovernanceIssue]
    public let policy: InferencePolicy
}

/// Governance issues found during validation.
public enum InferenceGovernanceIssue: Sendable {
    case taskKindNotAllowed(InferenceTaskKind)
    case restrictedDataNotAllowed
    case restrictedDataRequiresLocal
    case remoteInferenceNotAllowed
    case qualityTierBelowMinimum(required: QualityTier, requested: QualityTier)
    case autopilotNotAllowed
    case modelNotAllowed(String)
    case modelBlocked(String)
    case backendNotAllowed(BackendKind)
    case modelQualityBelowMinimum(required: QualityTier, actual: QualityTier)
    case nodeTenantMismatch(expected: String, actual: String)
    case nodeResidencyViolation(required: DataResidency, actual: DataResidency)
    case nodeResidencyNotAllowed(DataResidency)

    public var description: String {
        switch self {
        case .taskKindNotAllowed(let kind):
            return "Task kind '\(kind)' not allowed by policy"
        case .restrictedDataNotAllowed:
            return "Restricted data processing not allowed"
        case .restrictedDataRequiresLocal:
            return "Restricted data requires local-only processing"
        case .remoteInferenceNotAllowed:
            return "Remote inference not allowed by policy"
        case .qualityTierBelowMinimum(let required, let requested):
            return "Quality tier \(requested) below minimum \(required)"
        case .autopilotNotAllowed:
            return "Autopilot mode not allowed; assistive only"
        case .modelNotAllowed(let id):
            return "Model '\(id)' not in allowed list"
        case .modelBlocked(let id):
            return "Model '\(id)' is blocked"
        case .backendNotAllowed(let backend):
            return "Backend '\(backend)' not allowed"
        case .modelQualityBelowMinimum(let required, let actual):
            return "Model quality \(actual) below minimum \(required)"
        case .nodeTenantMismatch(let expected, let actual):
            return "Node tenant '\(actual)' doesn't match task tenant '\(expected)'"
        case .nodeResidencyViolation(let required, let actual):
            return "Node residency '\(actual)' violates required '\(required)'"
        case .nodeResidencyNotAllowed(let residency):
            return "Node residency '\(residency)' not allowed"
        }
    }
}

// MARK: - Rate Limiting

/// Result of rate limit check.
public struct RateLimitResult: Sendable {
    public let allowed: Bool
    public let reason: String?
    public let retryAfter: Duration?
}

/// State for rate limiting.
private struct RateLimitState: Sendable {
    var requestTimestamps: [Date] = []
    var tokenCounts: [TokenCount] = []
}

private struct TokenCount: Sendable {
    let tokens: Int
    let timestamp: Date
}

// MARK: - Governed Inference Service

/// Inference service with full governance integration.
public actor GovernedInferenceService {
    private let inferenceService: InferenceService
    private let governance: InferenceGovernance
    private let telemetryClient: TelemetryClient?

    public init(
        inferenceService: InferenceService,
        governance: InferenceGovernance,
        telemetryClient: TelemetryClient? = nil
    ) {
        self.inferenceService = inferenceService
        self.governance = governance
        self.telemetryClient = telemetryClient
    }

    /// Runs an inference task with governance checks.
    public func run(_ task: InferenceTask) async throws -> InferenceResult {
        // Check rate limit
        let rateResult = await governance.checkRateLimit(forTenant: task.context.tenantId)
        guard rateResult.allowed else {
            throw InferenceError.rateLimited(retryAfter: rateResult.retryAfter)
        }

        // Validate task against policy
        let validation = await governance.validate(task: task)
        guard validation.isValid else {
            let reasons = validation.issues.map(\.description).joined(separator: "; ")
            throw InferenceError.policyViolation(reason: reasons)
        }

        // Run inference
        let result = try await inferenceService.run(task)

        // Record token usage
        await governance.recordTokenUsage(
            forTenant: task.context.tenantId,
            tokens: result.tokensIn + result.tokensOut
        )

        // Record telemetry
        if let telemetry = telemetryClient {
            _ = await telemetry.emit(
                category: .workflow,
                name: "inference_executed",
                privacyClassification: .internal,
                values: [
                    "tokens_in": .integer(result.tokensIn),
                    "tokens_out": .integer(result.tokensOut),
                    "latency_ms": .double(result.latency.milliseconds),
                    "task_kind": .hashedToken(TelemetryHash(input: task.kind.rawValue)),
                    "model": .hashedToken(TelemetryHash(input: result.modelUsed)),
                    "backend": .hashedToken(TelemetryHash(input: result.backendUsed.rawValue))
                ]
            )
        }

        return result
    }

    /// Sets the inference policy for a tenant.
    public func setPolicy(_ policy: InferencePolicy) async {
        await governance.setPolicy(policy)
    }
}

// Duration extensions are defined in RunnerManager.swift

// Note: InferenceError cases are defined in InferenceTypes.swift
