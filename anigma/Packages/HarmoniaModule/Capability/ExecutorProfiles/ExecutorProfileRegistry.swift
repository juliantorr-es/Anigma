//
//  ExecutorProfileRegistry.swift
//  HarmoniaModule
//
//  Registry and resolver for executor profiles.
//

import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import CryptoKit
import Foundation

/// Actor-backed registry for executor profiles.
public actor ExecutorProfileRegistry: ExecutorProfileProviding {
    private var profiles: [String: ExecutorProfile] = [:]
    private let evidenceRecorder: EvidenceRecording?

    /// Creates a registry with optional initial profiles.
    public init(
        profiles: [ExecutorProfile] = [],
        evidenceRecorder: EvidenceRecording? = nil
    ) {
        self.evidenceRecorder = evidenceRecorder
        for profile in profiles {
            self.profiles[profile.id] = profile
        }
    }

    /// Registers a profile in the registry.
    func register(profile: ExecutorProfile) {
        profiles[profile.id] = profile
    }

    public func listProfiles(trustTier: TrustTier) async throws -> [ExecutorProfileSummary] {
        profiles.values
            .filter { $0.defaults.governance.requiredTrustTier <= trustTier }
            .sorted { $0.id < $1.id }
            .map {
                ExecutorProfileSummary(
                    id: $0.id,
                    version: $0.version,
                    displayName: $0.displayName,
                    executorKind: $0.executorKind,
                    defaultVariant: $0.defaultVariant
                )
            }
    }

    public func getProfile(id: String, trustTier: TrustTier) async throws -> ExecutorProfile {
        guard let profile = profiles[id] else {
            throw ExecutorProfileError.notFound(id: id)
        }
        guard profile.defaults.governance.requiredTrustTier <= trustTier else {
            throw ExecutorProfileError.accessDenied(
                reason: "Trust tier insufficient for profile \(id)")
        }
        return profile
    }

    public func resolveProfile(
        id: String,
        variantId: String?,
        taskOverrides: ExecutorProfileOverrides?,
        attemptOverrides: ExecutorProfileOverrides?,
        trustTier: TrustTier
    ) async throws -> ResolvedExecutorProfile {
        let profile = try await getProfile(id: id, trustTier: trustTier)
        let resolvedVariantId = variantId ?? profile.defaultVariant

        let variantOverrides: ExecutorProfileOverrides?
        if let resolvedVariantId {
            guard let variant = profile.variants.first(where: { $0.id == resolvedVariantId }) else {
                throw ExecutorProfileError.variantNotFound(id: id, variantId: resolvedVariantId)
            }
            variantOverrides = variant.overrides
        } else {
            variantOverrides = nil
        }

        let merged = try mergeProfile(
            profile: profile,
            variantId: resolvedVariantId,
            variantOverrides: variantOverrides,
            taskOverrides: taskOverrides,
            attemptOverrides: attemptOverrides
        )

        try await recordResolutionEvidence(
            profile: profile,
            variantId: resolvedVariantId,
            taskOverrides: taskOverrides,
            attemptOverrides: attemptOverrides
        )

        return merged
    }

    public func canUseProfile(id: String, trustTier: TrustTier) async throws -> Bool {
        guard let profile = profiles[id] else {
            throw ExecutorProfileError.notFound(id: id)
        }
        return profile.defaults.governance.requiredTrustTier <= trustTier
    }

    // MARK: - Merge and Validation

    private func mergeProfile(
        profile: ExecutorProfile,
        variantId: String?,
        variantOverrides: ExecutorProfileOverrides?,
        taskOverrides: ExecutorProfileOverrides?,
        attemptOverrides: ExecutorProfileOverrides?
    ) throws -> ResolvedExecutorProfile {
        var modelId = profile.defaults.modelId
        var mlTaskOptions = profile.defaults.mlTaskOptions
        var permissions = profile.defaults.permissions
        var granularCapabilities = profile.defaults.granularCapabilities
        var budgets = profile.defaults.budgets
        var governance = profile.defaults.governance

        if let variantOverrides {
            try applyOverrides(
                variantOverrides,
                modelId: &modelId,
                mlTaskOptions: &mlTaskOptions,
                permissions: &permissions,
                granularCapabilities: &granularCapabilities,
                budgets: &budgets,
                governance: &governance
            )
        }

        if let taskOverrides {
            try applyOverrides(
                taskOverrides,
                modelId: &modelId,
                mlTaskOptions: &mlTaskOptions,
                permissions: &permissions,
                granularCapabilities: &granularCapabilities,
                budgets: &budgets,
                governance: &governance
            )
        }

        if let attemptOverrides {
            try applyOverrides(
                attemptOverrides,
                modelId: &modelId,
                mlTaskOptions: &mlTaskOptions,
                permissions: &permissions,
                granularCapabilities: &granularCapabilities,
                budgets: &budgets,
                governance: &governance
            )
        }

        return ResolvedExecutorProfile(
            id: profile.id,
            version: profile.version,
            executorKind: profile.executorKind,
            variantId: variantId,
            modelId: modelId,
            mlTaskOptions: mlTaskOptions,
            permissions: permissions,
            granularCapabilities: granularCapabilities,
            budgets: budgets,
            governance: governance
        )
    }

    private func applyOverrides(
        _ overrides: ExecutorProfileOverrides,
        modelId: inout String,
        mlTaskOptions: inout MLTaskOptions,
        permissions: inout ExecutorPermissions,
        granularCapabilities: inout GranularCapabilities,
        budgets: inout ContractBudgets,
        governance: inout ExecutorProfileGovernance
    ) throws {
        if let overrideModelId = overrides.modelId {
            modelId = overrideModelId
        }

        if let overrideOptions = overrides.mlTaskOptions {
            try validateMaxTokens(
                base: mlTaskOptions.maxTokens,
                override: overrideOptions.maxTokens
            )
            mlTaskOptions = overrideOptions
        }
        

        if let overridePermissions = overrides.permissions {
            let baseSet = Set(permissions)
            guard Set(overridePermissions).isSubset(of: baseSet) else {
                throw ExecutorProfileError.governanceViolation(
                    code: "permissions_escalation",
                    message: "Overrides may not add permissions"
                )
            }
            permissions = overridePermissions
        }

        if let overrideCapabilities = overrides.granularCapabilities {
            let baseSet = Set(granularCapabilities)
            guard Set(overrideCapabilities).isSubset(of: baseSet) else {
                throw ExecutorProfileError.governanceViolation(
                    code: "capability_escalation",
                    message: "Overrides may not add granular capabilities"
                )
            }
            granularCapabilities = overrideCapabilities
        }

        if let overrideBudgets = overrides.budgets {
            budgets = try mergeBudgets(base: budgets, override: overrideBudgets)
        }

        if let overrideGovernance = overrides.governance {
            governance = try mergeGovernance(base: governance, override: overrideGovernance)
        }
    }

    private func validateMaxTokens(base: Int?, override: Int?) throws {
        if let base, let override, override > base {
            throw ExecutorProfileError.governanceViolation(
                code: "tokens_escalation",
                message: "Overrides may not increase max tokens"
            )
        }
    }

    private func mergeBudgets(base: ContractBudgets, override: ContractBudgets) throws
        -> ContractBudgets {
        let maxWallTime = try restrictOptional(
            base: base.maxWallTime,
            override: override.maxWallTime,
            code: "walltime_escalation",
            message: "Overrides may not increase max wall time"
        )
        let maxTokens = try restrictOptional(
            base: base.maxTokens,
            override: override.maxTokens,
            code: "budget_tokens_escalation",
            message: "Overrides may not increase max tokens"
        )
        let maxToolCalls = try restrictOptional(
            base: base.maxToolCalls,
            override: override.maxToolCalls,
            code: "tool_calls_escalation",
            message: "Overrides may not increase max tool calls"
        )

        if override.maxRetries > base.maxRetries {
            throw ExecutorProfileError.governanceViolation(
                code: "retries_escalation",
                message: "Overrides may not increase retries"
            )
        }

        return ContractBudgets(
            maxWallTime: maxWallTime,
            maxTokens: maxTokens,
            maxToolCalls: maxToolCalls,
            maxRetries: override.maxRetries
        )
    }

    private func restrictOptional<T: Comparable>(
        base: T?,
        override: T?,
        code: String,
        message: String
    ) throws -> T? {
        if let base, let override {
            guard override <= base else {
                throw ExecutorProfileError.governanceViolation(code: code, message: message)
            }
            return override
        }
        if base == nil, override != nil {
            return override
        }
        if base != nil, override == nil {
            throw ExecutorProfileError.governanceViolation(code: code, message: message)
        }
        return base
    }

    private func mergeGovernance(
        base: ExecutorProfileGovernance,
        override: ExecutorProfileGovernance
    ) throws -> ExecutorProfileGovernance {
        if override.requiredTrustTier < base.requiredTrustTier {
            throw ExecutorProfileError.governanceViolation(
                code: "trust_tier_escalation",
                message: "Overrides may not reduce required trust tier"
            )
        }
        if override.securityZone != base.securityZone {
            throw ExecutorProfileError.governanceViolation(
                code: "security_zone_escalation",
                message: "Overrides may not change security zone"
            )
        }
        if override.allowUnattendedExecution && !base.allowUnattendedExecution {
            throw ExecutorProfileError.governanceViolation(
                code: "unattended_escalation",
                message: "Overrides may not allow unattended execution"
            )
        }
        if override.allowGovernedBuild && !base.allowGovernedBuild {
            throw ExecutorProfileError.governanceViolation(
                code: "governed_build_escalation",
                message: "Overrides may not allow governed builds"
            )
        }
        return override
    }

    // MARK: - Evidence

    private func recordResolutionEvidence(
        profile: ExecutorProfile,
        variantId: String?,
        taskOverrides: ExecutorProfileOverrides?,
        attemptOverrides: ExecutorProfileOverrides?
    ) async throws {
        guard let evidenceRecorder else { return }

        let profileHash = try sha256(profile.canonicalEncode())
        let taskOverrideHash = try taskOverrides.flatMap { try sha256($0.canonicalEncode()) }
        let attemptOverrideHash = try attemptOverrides.flatMap { try sha256($0.canonicalEncode()) }

        var payload: [String: String] = [
            "profile_id": profile.id,
            "profile_hash": profileHash
        ]
        if let variantId {
            payload["variant_id"] = variantId
        }
        if let taskOverrideHash {
            payload["task_override_hash"] = taskOverrideHash
        }
        if let attemptOverrideHash {
            payload["attempt_override_hash"] = attemptOverrideHash
        }

        let head = EvidenceHead(
            headId: UUID().uuidString.lowercased(),
            headHash: profileHash,
            lastActor: "executor-profile-registry"
        )
        let content = try JSONEncoder().encode(payload)
        try await evidenceRecorder.recordEvidence(head: head, content: content)
    }

    private func sha256(_ data: Data) throws -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
