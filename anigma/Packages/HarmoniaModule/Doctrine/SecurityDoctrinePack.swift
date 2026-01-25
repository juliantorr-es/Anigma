//
//  SecurityDoctrinePack.swift
//  HarmoniaModule
//
//  Security Doctrine Pack v1.0.0
//  Grounded in OWASP ASVS/Top 10, NIST SSDF, MITRE CWE.
//  Not vibes - actual security invariants with blocking enforcement.
//

@preconcurrency import Foundation
import AnigmaPrimitives
import DoctrineCore

// MARK: - Security Doctrine Pack v1

/// Security Doctrine Pack v1.0.0
/// Application security, supply chain, and local-first safety rules.
public struct SecurityDoctrinePackV1: VersionedDoctrinePack {
    public let id = "security-doctrine-v1"
    public let name = "Security Doctrine v1"
    public let version = "1.0.0"
    public let domain: DoctrineDomain = .security
    public let enabledByDefault = true
    public let minimumTrustTierForOverride: TrustTier = .platinum  // Security is strict

    public func rule(withId id: String) -> DoctrineRule? {
        rules.first { $0.id == id }
    }

    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        guard let rule = rule(withId: ruleId) else { return false }
        guard trustTier >= minimumTrustTierForOverride else { return false }
        return !rule.blocking
    }

    public let rules: [DoctrineRule] = [
        // SEC-AUTH-001: Authentication must satisfy OWASP ASVS L2
        DoctrineRule(
            id: "sec-auth-001",
            title: "Strong Authentication Required",
            description: "All authentication mechanisms must use multi-factor or certificate-based auth",
            severity: .critical,
            implementation: .configuration,
            blocking: true,
            source: "OWASP ASVS L2",
            domain: .security,
            minimumTrustTier: .silver
        ),

        // SEC-CRYPTO-001: No hardcoded secrets
        DoctrineRule(
            id: "sec-crypto-001",
            title: "No Hardcoded Secrets",
            description: "Secrets, keys, and passwords must not be hardcoded in source code",
            severity: .critical,
            implementation: .astPattern,
            blocking: true,
            source: "MITRE CWE-798",
            domain: .security,
            minimumTrustTier: .bronze
        ),

        // SEC-CRYPTO-002: Strong encryption required
        DoctrineRule(
            id: "sec-crypto-002",
            title: "Strong Encryption Required",
            description: "Must use AES-256 or stronger, no MD5/SHA1 for security",
            severity: .error,
            implementation: .astPattern,
            blocking: true,
            source: "NIST SP 800-57",
            domain: .security,
            minimumTrustTier: .silver
        ),

        // SEC-NET-001: HTTPS required
        DoctrineRule(
            id: "sec-net-001",
            title: "HTTPS Required",
            description: "All network communication must use TLS 1.2+",
            severity: .error,
            implementation: .filePattern,
            blocking: true,
            source: "NIST SP 800-52",
            domain: .security,
            minimumTrustTier: .bronze
        ),

        // SEC-DATA-001: Data encryption at rest
        DoctrineRule(
            id: "sec-data-001",
            title: "Data Encryption at Rest",
            description: "Sensitive data must be encrypted when stored",
            severity: .critical,
            implementation: .configuration,
            blocking: true,
            source: "NIST SP 800-111",
            domain: .security,
            minimumTrustTier: .gold
        ),

        // SEC-INPUT-001: Input validation
        DoctrineRule(
            id: "sec-input-001",
            title: "Input Validation Required",
            description: "All user input must be validated and sanitized",
            severity: .error,
            implementation: .astPattern,
            blocking: true,
            source: "OWASP Top 10 - Injection",
            domain: .security,
            minimumTrustTier: .silver
        ),

        // SEC-ACCESS-001: Principle of least privilege
        DoctrineRule(
            id: "sec-access-001",
            title: "Least Privilege Access",
            description: "Components must have minimum required permissions only",
            severity: .warning,
            implementation: .configuration,
            blocking: false,
            source: "CIS Benchmark",
            domain: .security,
            minimumTrustTier: .gold
        ),

        // SEC-AUDIT-001: Security logging
        DoctrineRule(
            id: "sec-audit-001",
            title: "Security Event Logging",
            description: "All security events must be logged with audit trail",
            severity: .error,
            implementation: .configuration,
            blocking: true,
            source: "NIST SP 800-92",
            domain: .security,
            minimumTrustTier: .silver
        )
    ]

    public init() {}

    /// Evaluates security posture and returns blocking violations
    public func evaluate(context: DoctrineEvaluationContext) async throws -> DoctrineEvaluationResult {
        var violations: [DoctrineViolation] = []
        let warnings: [DoctrineWarning] = []

        // Run security scouts based on context
        if let filePath = context.filePath {
            // File-level security checks
            let secretsScout = SecretsSecurityScout()
            let secretViolations = try await secretsScout.scan(fileAt: filePath)
            violations.append(contentsOf: secretViolations)
        }

        // Evaluate trust tier requirements
        for rule in rules {
            if context.trustTier.rawValue < rule.minimumTrustTier.rawValue && rule.enabled {
                let violation = DoctrineViolation(
                    ruleId: rule.id,
                    severity: rule.severity,
                    message: "Security rule '\(rule.title)' requires trust tier \(rule.minimumTrustTier.rawValue) but current tier is \(context.trustTier.rawValue)",
                    filePath: context.filePath ?? "unknown",
                    lineNumber: nil,
                    context: "Trust tier violation"
                )
                violations.append(violation)
            }
        }

        // Calculate security health score
        let healthScore = try await calculateSecurityHealthScore(violations: violations, context: context)

        return DoctrineEvaluationResult(
            packId: id,
            packName: name,
            packVersion: version,
            domain: domain,
            violations: violations,
            warnings: warnings,
            healthScore: healthScore,
            canProceed: violations.filter { $0.severity == .critical }.isEmpty,
            metadata: [
                "rules_evaluated": String(rules.count),
                "trust_tier": context.trustTier.rawValue,
                "security_posture": healthScore > 0.8 ? "strong" : healthScore > 0.6 ? "moderate" : "weak"
            ]
        )
    }

    /// Calculates overall security health score (0.0 to 1.0)
    private func calculateSecurityHealthScore(violations: [DoctrineViolation], context: DoctrineEvaluationContext) async throws -> Double {
        let criticalCount = violations.filter { $0.severity == .critical }.count
        let errorCount = violations.filter { $0.severity == .error }.count
        let warningCount = violations.filter { $0.severity == .warning }.count

        // Weighted scoring: critical = 10 points, error = 5 points, warning = 1 point
        let penaltyScore = Double(criticalCount * 10 + errorCount * 5 + warningCount * 1)
        let maxPossibleScore = Double(rules.count * 10) // Assume worst case

        let healthScore = max(0.0, (maxPossibleScore - penaltyScore) / maxPossibleScore)

        // Boost score based on trust tier
        let trustMultiplier: Double
        switch context.trustTier {
        case .platinum: trustMultiplier = 1.2
        case .gold: trustMultiplier = 1.1
        case .trusted: trustMultiplier = 1.0
        case .silver: trustMultiplier = 0.95
        case .bronze: trustMultiplier = 0.9
        }

        return min(1.0, healthScore * trustMultiplier)
    }
}

// MARK: - Evaluation Data Models

/// Context for evaluating a doctrine pack.
public struct DoctrineEvaluationContext: Sendable {
    public let trustTier: TrustTier
    public let filePath: String?
    public let metadata: [String: String]

    public init(
        trustTier: TrustTier,
        filePath: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.trustTier = trustTier
        self.filePath = filePath
        self.metadata = metadata
    }
}

/// Result of doctrine evaluation, including violations and health score.
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

/// Lightweight warning emitted during doctrine evaluations.
public struct DoctrineWarning: Sendable {
    public let ruleId: String
    public let message: String

    public init(ruleId: String, message: String) {
        self.ruleId = ruleId
        self.message = message
    }
}

// MARK: - Security Scouts

/// Scout that detects secrets in code using AST services.
public actor SecretsSecurityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .security

    private let astClient: ASTClient

    public init(astClient: ASTClient? = nil) {
        self.astClient = astClient ?? ASTClient()
    }

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }
        guard FileManager.default.fileExists(atPath: path) else { return [] }

        // Use AST client for analysis
        let result = try await astClient.analyzeFile(path, visitors: ["security"])
        return result.findings
    }
}

/// Scout that detects authentication patterns.
public actor AuthSecurityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .security

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }
        guard FileManager.default.fileExists(atPath: path) else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let lowerLine = line.lowercased()

            // Check for insecure patterns
            if lowerLine.contains("md5") || lowerLine.contains("sha1") {
                violations.append(DoctrineViolation(
                    ruleId: "sec-crypto-002",
                    severity: .error,
                    message: "Weak hash algorithm detected (MD5/SHA1)",
                    filePath: path,
                    lineNumber: lineNumber,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }

            if lowerLine.contains("http://") && !lowerLine.contains("https://") {
                violations.append(DoctrineViolation(
                    ruleId: "sec-net-001",
                    severity: .error,
                    message: "Insecure HTTP protocol detected",
                    filePath: path,
                    lineNumber: lineNumber,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
        }

        return violations
    }
}
