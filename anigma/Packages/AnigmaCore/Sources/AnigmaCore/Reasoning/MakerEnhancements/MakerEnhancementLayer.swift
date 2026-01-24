//
//  MakerEnhancementLayer.swift
//  AnigmaCore
//
//  Phase 1 scaffolding for MakerEngine enhancements. Defines the swappable
//  adapter boundary and a pure Swift fallback so builds remain stable without
//  native dependencies.
//

import Foundation
import ContractsCore

/// Resource limits enforced by MakerEngine enhancements.
public struct MakerResourceLimits: Sendable, Codable {
    public let maxBytes: Int
    /// Maximum line count before a resource limit is triggered.
    public let maxLines: Int
    public let maxDurationSeconds: TimeInterval

    public init(
        maxBytes: Int = 1_000_000,
        maxLines: Int = Int.max,
        maxDurationSeconds: TimeInterval = 1.0
    ) {
        self.maxBytes = maxBytes
        self.maxLines = maxLines
        self.maxDurationSeconds = maxDurationSeconds
    }

    public static let `default` = MakerResourceLimits()
}

/// Diff adapter used by MakerEngine enhancements.
public protocol MakerDiffAdapter: Sendable {
    func diff(baseline: String, candidate: String, limits: MakerResourceLimits) throws -> MakerDiffResult
}

/// Seeded diff adapter that can run deterministically with a context.
public protocol SeededMakerDiffAdapter: MakerDiffAdapter {
    func diff(
        baseline: String,
        candidate: String,
        limits: MakerResourceLimits,
        determinism: DeterminismContext
    ) throws -> MakerDiffResult
}

/// Result of a diff operation.
public struct MakerDiffResult: Sendable, Codable {
    public let changed: Bool
    public let deltaBytes: Int
    public let summary: String

    public init(changed: Bool, deltaBytes: Int, summary: String) {
        self.changed = changed
        self.deltaBytes = deltaBytes
        self.summary = summary
    }
}

/// Parser adapter used by MakerEngine enhancements.
public protocol MakerParseAdapter: Sendable {
    func parse(text: String, limits: MakerResourceLimits) throws -> MakerParseResult
}

/// Seeded parse adapter that can run deterministically with a context.
public protocol SeededMakerParseAdapter: MakerParseAdapter {
    func parse(text: String, limits: MakerResourceLimits, determinism: DeterminismContext) throws -> MakerParseResult
}

/// Result of a parse operation.
public struct MakerParseResult: Sendable, Codable {
    public let nodeCount: Int
    public let diagnostics: [String]

    public init(nodeCount: Int, diagnostics: [String] = []) {
        self.nodeCount = nodeCount
        self.diagnostics = diagnostics
    }
}

/// Regex validator adapter used by MakerEngine enhancements.
public protocol MakerRegexValidator: Sendable {
    func validate(pattern: String, content: String, limits: MakerResourceLimits) throws -> MakerRegexValidationResult
}

/// Seeded regex validator that can run deterministically with a context.
public protocol SeededMakerRegexValidator: MakerRegexValidator {
    func validate(
        pattern: String,
        content: String,
        limits: MakerResourceLimits,
        determinism: DeterminismContext
    ) throws -> MakerRegexValidationResult
}

/// Result of a regex validation operation.
public struct MakerRegexValidationResult: Sendable, Codable {
    public let isMatch: Bool
    public let checkedLength: Int
    public let diagnostics: [String]

    public init(isMatch: Bool, checkedLength: Int, diagnostics: [String] = []) {
        self.isMatch = isMatch
        self.checkedLength = checkedLength
        self.diagnostics = diagnostics
    }
}

/// Policy evaluator adapter used by MakerEngine enhancements.
public protocol MakerPolicyEvaluator: Sendable {
    func evaluate(candidate: StepCandidate, context: StepContext) async throws -> MakerPolicyEvaluation
}

/// Seeded policy evaluator that can run deterministically with a context.
public protocol SeededMakerPolicyEvaluator: MakerPolicyEvaluator {
    func evaluate(
        candidate: StepCandidate,
        context: StepContext,
        determinism: DeterminismContext
    ) async throws -> MakerPolicyEvaluation
}

/// Result of a policy evaluation.
public struct MakerPolicyEvaluation: Sendable, Codable {
    public let flags: [PolicyFlag]
    public let violations: [PolicyViolation]

    public init(flags: [PolicyFlag] = [], violations: [PolicyViolation] = []) {
        self.flags = flags
        self.violations = violations
    }
}

/// Swappable enhancement layer for MakerEngine.
public struct MakerEnhancementLayer: Sendable {
    public let diffAdapter: any MakerDiffAdapter
    public let parseAdapter: any MakerParseAdapter
    public let regexValidator: any MakerRegexValidator
    public let policyEvaluator: any MakerPolicyEvaluator

    public init(
        diffAdapter: any MakerDiffAdapter,
        parseAdapter: any MakerParseAdapter,
        regexValidator: any MakerRegexValidator,
        policyEvaluator: any MakerPolicyEvaluator
    ) {
        self.diffAdapter = diffAdapter
        self.parseAdapter = parseAdapter
        self.regexValidator = regexValidator
        self.policyEvaluator = policyEvaluator
    }

    /// Pure Swift fallback that keeps builds stable until native intake is approved.
    public static func fallback() -> MakerEnhancementLayer {
        MakerEnhancementLayer(
            diffAdapter: MakerFallbackDiffAdapter(),
            parseAdapter: MakerFallbackParseAdapter(),
            regexValidator: MakerFallbackRegexValidator(),
            policyEvaluator: MakerFallbackPolicyEvaluator()
        )
    }
}

/// Stable adapter identifiers and fallback versions used in receipts.
public enum MakerAdapterIdentity {
    public static let diffId = "diff"
    public static let parseId = "parse"
    public static let regexId = "regex"
    public static let policyId = "policy"
    public static let fallbackVersion = "fallback-v1"
    public static let unknownVersion = "unknown"
}

/// Adapter version provider for receipt identity.
public protocol MakerAdapterVersioned: Sendable {
    var adapterVersion: String { get }
}

// MARK: - Fallback adapters

/// Deterministic, pure Swift diff adapter.
final class MakerFallbackDiffAdapter: MakerDiffAdapter, SeededMakerDiffAdapter, MakerAdapterVersioned {
    var adapterVersion: String { MakerAdapterIdentity.fallbackVersion }

    func diff(baseline: String, candidate: String, limits: MakerResourceLimits) throws -> MakerDiffResult {
        let deltaBytes = candidate.utf8.count - baseline.utf8.count
        let summary: String
        if baseline == candidate {
            summary = "No changes"
        } else if MakerResourceSizer.exceeds(texts: [baseline, candidate], limits: limits) {
            summary = "Candidate exceeded size limit"
        } else {
            summary = "Diff completed (byte delta: \(deltaBytes))"
        }

        return MakerDiffResult(
            changed: baseline != candidate,
            deltaBytes: deltaBytes,
            summary: summary
        )
    }

    func diff(
        baseline: String,
        candidate: String,
        limits: MakerResourceLimits,
        determinism: DeterminismContext
    ) throws -> MakerDiffResult {
        try diff(baseline: baseline, candidate: candidate, limits: limits)
    }
}

/// Deterministic, pure Swift parse adapter that returns structural hints only.
final class MakerFallbackParseAdapter: MakerParseAdapter, SeededMakerParseAdapter, MakerAdapterVersioned {
    var adapterVersion: String { MakerAdapterIdentity.fallbackVersion }

    func parse(text: String, limits: MakerResourceLimits) throws -> MakerParseResult {
        if MakerResourceSizer.exceeds(text: text, limits: limits) {
            return MakerParseResult(
                nodeCount: 0,
                diagnostics: ["Input exceeded size limit"]
            )
        }

        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return MakerParseResult(nodeCount: lineCount, diagnostics: [])
    }

    func parse(text: String, limits: MakerResourceLimits, determinism: DeterminismContext) throws -> MakerParseResult {
        try parse(text: text, limits: limits)
    }
}

/// Deterministic, pure Swift regex validator.
final class MakerFallbackRegexValidator: MakerRegexValidator, SeededMakerRegexValidator, MakerAdapterVersioned {
    var adapterVersion: String { MakerAdapterIdentity.fallbackVersion }

    func validate(pattern: String, content: String, limits: MakerResourceLimits) throws -> MakerRegexValidationResult {
        if MakerResourceSizer.exceeds(text: content, limits: limits) {
            return MakerRegexValidationResult(
                isMatch: false,
                checkedLength: min(content.utf8.count, limits.maxBytes),
                diagnostics: ["Content exceeded size limit"]
            )
        }

        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: (content as NSString).length)
        let match = regex.firstMatch(in: content, options: [], range: range) != nil

        return MakerRegexValidationResult(
            isMatch: match,
            checkedLength: content.utf8.count,
            diagnostics: []
        )
    }

    func validate(
        pattern: String,
        content: String,
        limits: MakerResourceLimits,
        determinism: DeterminismContext
    ) throws -> MakerRegexValidationResult {
        try validate(pattern: pattern, content: content, limits: limits)
    }
}

/// Deterministic, pure Swift policy evaluator placeholder.
final class MakerFallbackPolicyEvaluator: MakerPolicyEvaluator, SeededMakerPolicyEvaluator, MakerAdapterVersioned {
    var adapterVersion: String { MakerAdapterIdentity.fallbackVersion }

    func evaluate(candidate: StepCandidate, context: StepContext) async throws -> MakerPolicyEvaluation {
        // Phase 1 fallback: do not mutate existing policy logic. Enhanced policy
        // evaluation will be wired in subsequent phases.
        return MakerPolicyEvaluation(flags: [], violations: [])
    }

    func evaluate(
        candidate: StepCandidate,
        context: StepContext,
        determinism: DeterminismContext
    ) async throws -> MakerPolicyEvaluation {
        try await evaluate(candidate: candidate, context: context)
    }
}
