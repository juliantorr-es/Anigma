//
//  SecurityDoctrinePackCompat.swift
//  HarmoniaModule
//
//  Compact compatibility layer for the security doctrine pack.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore

public typealias DoctrineWarning = String

public struct SecurityDoctrinePackV1: VersionedDoctrinePack {
    public let id = "security-doctrine-v1"
    public let name = "Security Doctrine v1"
    public let version = "1.0.0"
    public let domain: DoctrineDomain = .security
    public let enabledByDefault = true
    public let minimumTrustTierForOverride: TrustTier = .platinum

    public let rules: [DoctrineRule] = [
        DoctrineRule(
            id: "sec-auth-001",
            title: "Strong Authentication Required",
            description: "Authentication should use strong mechanisms.",
            severity: .critical,
            implementation: .configuration,
            blocking: true,
            source: "OWASP ASVS L2",
            domain: .security,
            minimumTrustTier: .silver
        ),
        DoctrineRule(
            id: "sec-crypto-001",
            title: "No Hardcoded Secrets",
            description: "Secrets should not appear directly in source code.",
            severity: .critical,
            implementation: .astPattern,
            blocking: true,
            source: "MITRE CWE-798",
            domain: .security,
            minimumTrustTier: .bronze
        ),
        DoctrineRule(
            id: "sec-net-001",
            title: "HTTPS Required",
            description: "Network traffic should use TLS.",
            severity: .error,
            implementation: .filePattern,
            blocking: true,
            source: "NIST SP 800-52",
            domain: .security,
            minimumTrustTier: .bronze
        )
    ]

    public init() {}

    public func rule(withId id: String) -> DoctrineRule? {
        rules.first { $0.id == id }
    }

    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        guard let rule = rule(withId: ruleId) else { return false }
        return trustTier >= minimumTrustTierForOverride && !rule.blocking
    }

    public func evaluate(context: DoctrineEvaluationContext) async throws -> DoctrineEvaluationResult {
        var violations: [DoctrineViolation] = []
        if let filePath = context.filePath {
            violations.append(contentsOf: try await SecretsSecurityScout().scan(fileAt: filePath))
        }

        for rule in rules where context.trustTier.rawValue < rule.minimumTrustTier.rawValue && rule.enabled {
            violations.append(
                DoctrineViolation(
                    ruleId: rule.id,
                    severity: rule.severity,
                    message: "Security rule '\(rule.title)' requires trust tier \(rule.minimumTrustTier.rawValue)",
                    filePath: context.filePath ?? "unknown",
                    context: "Trust tier violation"
                )
            )
        }

        let criticalCount = violations.filter { $0.severity == .critical }.count
        let errorCount = violations.filter { $0.severity == .error }.count
        let warningCount = violations.filter { $0.severity == .warning }.count
        let penaltyScore = Double(criticalCount * 10 + errorCount * 5 + warningCount)
        let maxScore = Double(max(1, rules.count * 10))
        let healthScore = max(0.0, (maxScore - penaltyScore) / maxScore)

        return DoctrineEvaluationResult(
            packId: id,
            packName: name,
            packVersion: version,
            domain: domain,
            violations: violations,
            warnings: [],
            healthScore: healthScore,
            canProceed: criticalCount == 0,
            metadata: [
                "rules_evaluated": String(rules.count),
                "trust_tier": context.trustTier.rawValue
            ]
        )
    }
}

public struct DoctrineEvaluationContext: Sendable {
    public let trustTier: TrustTier
    public let filePath: String?
    public let metadata: [String: String]

    public init(trustTier: TrustTier, filePath: String? = nil, metadata: [String: String] = [:]) {
        self.trustTier = trustTier
        self.filePath = filePath
        self.metadata = metadata
    }
}

public struct DoctrineEvaluationResult: Sendable {
    public let packId: String
    public let packName: String
    public let packVersion: String
    public let domain: DoctrineDomain
    public let violations: [DoctrineViolation]
    public let warnings: [DoctrineWarning]
    public let healthScore: Double
    public let canProceed: Bool
    public let metadata: [String: String]

    public init(
        packId: String,
        packName: String,
        packVersion: String,
        domain: DoctrineDomain,
        violations: [DoctrineViolation],
        warnings: [DoctrineWarning],
        healthScore: Double,
        canProceed: Bool,
        metadata: [String: String] = [:]
    ) {
        self.packId = packId
        self.packName = packName
        self.packVersion = packVersion
        self.domain = domain
        self.violations = violations
        self.warnings = warnings
        self.healthScore = healthScore
        self.canProceed = canProceed
        self.metadata = metadata
    }
}

public struct SecretsSecurityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .security

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }
        let source = try String(contentsOfFile: path, encoding: .utf8).lowercased()
        let lines = source.components(separatedBy: .newlines)
        var violations: [DoctrineViolation] = []

        for (index, line) in lines.enumerated() {
            if line.contains("password") || line.contains("secret") || line.contains("token") || line.contains("api_key") {
                violations.append(
                    DoctrineViolation(
                        ruleId: "sec-crypto-001",
                        severity: .critical,
                        message: "Potential hardcoded secret detected",
                        filePath: path,
                        lineNumber: index + 1,
                        context: line
                    )
                )
            }
            if line.contains("http://") && !line.contains("https://") {
                violations.append(
                    DoctrineViolation(
                        ruleId: "sec-net-001",
                        severity: .error,
                        message: "Insecure HTTP usage detected",
                        filePath: path,
                        lineNumber: index + 1,
                        context: line
                    )
                )
            }
        }

        return violations
    }
}

public struct AuthSecurityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .security

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }
        let source = try String(contentsOfFile: path, encoding: .utf8).lowercased()
        if source.contains("allowanonymous") || source.contains("guestlogin") {
            return [
                DoctrineViolation(
                    ruleId: "sec-auth-001",
                    severity: .error,
                    message: "Weak authentication flow detected",
                    filePath: path,
                    context: "Source suggests an anonymous or guest authentication path"
                )
            ]
        }
        return []
    }
}
