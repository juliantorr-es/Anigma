//
//  SecurityTests.swift
//  AnigmaCoreTests
//
//  Tests for the Security module infrastructure.
//

import XCTest
@testable import AnigmaCore

final class SecurityTests: XCTestCase {

    // MARK: - XAI Tests

    func testContributingFactorCreation() {
        let factor = ContributingFactor(
            name: "login_frequency",
            description: "Number of logins per hour",
            weight: 0.75,
            observedValue: "42",
            baselineValue: "10",
            influence: .positive,
            category: "behavior"
        )

        XCTAssertEqual(factor.name, "login_frequency")
        XCTAssertEqual(factor.weight, 0.75)
        XCTAssertEqual(factor.influence, .positive)
    }

    func testAIDecisionExplanation() {
        let factors = [
            ContributingFactor(name: "f1", description: "desc1", weight: 0.8, observedValue: "1", influence: .positive),
            ContributingFactor(name: "f2", description: "desc2", weight: 0.3, observedValue: "2", influence: .negative),
            ContributingFactor(name: "f3", description: "desc3", weight: 0.5, observedValue: "3", influence: .neutral)
        ]

        let explanation = AIDecisionExplanation(
            decisionType: .anomalyDetection,
            outcome: "ANOMALY_DETECTED",
            confidence: 0.85,
            summary: "Unusual access pattern detected",
            detailedExplanation: "The user exhibited unusual behavior",
            contributingFactors: factors,
            modelIdentifier: "anomaly-v1",
            modelVersion: "1.0.0"
        )

        XCTAssertEqual(explanation.decisionType, .anomalyDetection)
        XCTAssertEqual(explanation.outcome, "ANOMALY_DETECTED")
        XCTAssertEqual(explanation.confidence, 0.85)
        XCTAssertEqual(explanation.contributingFactors.count, 3)
        XCTAssertEqual(explanation.topFactors(2).count, 2)
        XCTAssertEqual(explanation.topFactors(2).first?.name, "f1")
        XCTAssertEqual(explanation.positiveFactors.count, 1)
        XCTAssertEqual(explanation.negativeFactors.count, 1)
    }

    func testLocalExplanationGenerator() {
        let generator = LocalExplanationGenerator(
            modelIdentifier: "test-model",
            modelVersion: "1.0"
        )

        let features = [
            FeatureContribution(name: "feature1", description: "Test feature", value: "100", contribution: 0.7),
            FeatureContribution(name: "feature2", description: "Another feature", value: "50", contribution: -0.3)
        ]

        let explanation = generator.generateExplanation(
            decisionType: .riskAssessment,
            outcome: "HIGH_RISK",
            confidence: 0.9,
            features: features
        )

        XCTAssertEqual(explanation.decisionType, .riskAssessment)
        XCTAssertEqual(explanation.outcome, "HIGH_RISK")
        XCTAssertEqual(explanation.contributingFactors.count, 2)
        XCTAssertFalse(explanation.summary.isEmpty)
    }

    func testXAIRegistry() async {
        let registry = XAIRegistry()

        let explanation = AIDecisionExplanation(
            decisionType: .accessControl,
            outcome: "ALLOW",
            confidence: 0.95,
            summary: "Access allowed",
            detailedExplanation: "User has required permissions",
            contributingFactors: [],
            modelIdentifier: "access-model",
            modelVersion: "1.0"
        )

        await registry.record(explanation)

        let retrieved = await registry.get(explanation.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, explanation.id)

        let stats = await registry.statistics()
        XCTAssertEqual(stats.totalDecisions, 1)
    }

    // MARK: - Model Integrity Tests

    func testInputValidator() {
        let bounds: [String: InputValidator.FeatureBounds] = [
            "feature1": InputValidator.FeatureBounds(min: 0, max: 100, mean: 50, stdDev: 15)
        ]

        let validator = InputValidator(
            featureBounds: bounds,
            requiredFeatures: ["feature1"]
        )

        // Valid input
        let result1 = validator.validate(["feature1": 55])
        XCTAssertTrue(result1.isValid)
        XCTAssertFalse(result1.isPotentiallyMalicious)

        // Missing required feature
        let result2 = validator.validate([:])
        XCTAssertFalse(result2.isValid)

        // Out of bounds
        let result3 = validator.validate(["feature1": 200])
        XCTAssertFalse(result3.isValid)
    }

    func testModelIntegrityManager() async {
        let manager = ModelIntegrityManager()

        let model = RegisteredModel(
            name: "test-model",
            version: "1.0.0",
            modelHash: "abc123",
            registeredBy: "test",
            inputSchema: "{}",
            outputSchema: "{}",
            baselineMetrics: ModelMetrics(accuracy: 0.95)
        )

        await manager.registerModel(model)

        let retrieved = await manager.getModel(model.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "test-model")

        // Test integrity check
        let validResult = await manager.verifyModelIntegrity(modelId: model.id, currentHash: "abc123")
        XCTAssertTrue(validResult.isValid)

        let invalidResult = await manager.verifyModelIntegrity(modelId: model.id, currentHash: "wrong")
        XCTAssertFalse(invalidResult.isValid)
    }

    // MARK: - Policy Enforcement Tests

    func testThreatLevels() {
        XCTAssertTrue(ThreatLevel.low < ThreatLevel.medium)
        XCTAssertTrue(ThreatLevel.medium < ThreatLevel.high)
        XCTAssertTrue(ThreatLevel.high < ThreatLevel.critical)
    }

    func testDetectedThreat() {
        let threat = DetectedThreat(
            threatType: "BRUTE_FORCE",
            level: .high,
            source: "user-123",
            target: "/api/login",
            description: "Multiple failed login attempts"
        )

        XCTAssertEqual(threat.threatType, "BRUTE_FORCE")
        XCTAssertEqual(threat.level, .high)
        XCTAssertEqual(threat.source, "user-123")
    }

    func testThreatLevelPolicy() {
        let policy = ThreatLevelPolicy()

        let lowThreat = DetectedThreat(
            threatType: "INFO",
            level: .low,
            source: "user-1",
            description: "Info"
        )

        let criticalThreat = DetectedThreat(
            threatType: "ATTACK",
            level: .critical,
            source: "user-2",
            description: "Critical"
        )

        XCTAssertEqual(policy.evaluate(lowThreat), .logOnly)
        XCTAssertEqual(policy.evaluate(criticalThreat), .block)
    }

    func testPolicyEnforcementEngine() async {
        let engine = PolicyEnforcementEngine()

        let threat = DetectedThreat(
            threatType: "TEST",
            level: .high,
            source: "test-source",
            description: "Test threat"
        )

        let decision = await engine.enforce(threat)
        XCTAssertEqual(decision.threatId, threat.id)
        XCTAssertNotNil(decision.action)
    }

    func testThreatFactory() {
        let accessThreat = ThreatFactory.fromAccessDenial(
            principal: "user-1",
            resource: "/admin",
            reason: "Insufficient permissions"
        )
        XCTAssertEqual(accessThreat.threatType, "ACCESS_VIOLATION")
        XCTAssertEqual(accessThreat.level, .medium)

        let anomalyThreat = ThreatFactory.fromAnomaly(
            source: "user-2",
            anomalyScore: 0.95,
            description: "Unusual behavior"
        )
        XCTAssertEqual(anomalyThreat.threatType, "BEHAVIORAL_ANOMALY")
        XCTAssertEqual(anomalyThreat.level, .critical)

        let authThreat = ThreatFactory.fromAuthFailures(
            source: "ip-1",
            failureCount: 15,
            timeWindowMinutes: 5
        )
        XCTAssertEqual(authThreat.threatType, "BRUTE_FORCE_ATTEMPT")
        XCTAssertEqual(authThreat.level, .high)
    }

    // MARK: - Cryptographic Security Tests

    func testKeyManager() async throws {
        let manager = KeyManager()

        // Generate symmetric key
        let keyMeta = await manager.generateSymmetricKey(
            name: "test-key",
            keyType: .dataKey,
            usage: .encryptDecrypt,
            createdBy: "test"
        )

        XCTAssertEqual(keyMeta.name, "test-key")
        XCTAssertEqual(keyMeta.keyType, .dataKey)
        XCTAssertTrue(keyMeta.isActive)
        XCTAssertFalse(keyMeta.isExpired)

        // Encrypt data
        guard let plaintext = "Hello, World!".data(using: .utf8) else {
            fatalError("Failed to unwrap plaintext")
        }
        let encrypted = try await manager.encrypt(data: plaintext, using: keyMeta.id)

        XCTAssertNotEqual(encrypted.ciphertext, plaintext)
        XCTAssertEqual(encrypted.keyId, keyMeta.id)

        // Decrypt data
        let decrypted = try await manager.decrypt(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            tag: encrypted.tag,
            using: keyMeta.id
        )

        XCTAssertEqual(decrypted, plaintext)
    }

    func testSigningKey() async throws {
        let manager = KeyManager()

        let keyMeta = await manager.generateSigningKeyPair(
            name: "test-signing-key",
            createdBy: "test"
        )

        XCTAssertEqual(keyMeta.keyType, .signingKey)
        XCTAssertEqual(keyMeta.algorithm, "Ed25519")

        // Sign data
        guard let data = "Sign this message".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        let signature = try await manager.sign(data: data, using: keyMeta.id)

        XCTAssertEqual(signature.keyId, keyMeta.id)

        // Verify signature
        let isValid = try await manager.verify(
            signature: signature.signature,
            for: data,
            using: keyMeta.id
        )

        XCTAssertTrue(isValid)

        // Tampered data should fail
        guard let tamperedData = "Tampered message".data(using: .utf8) else {
            fatalError("Failed to unwrap tamperedData")
        }
        let isTamperedValid = try await manager.verify(
            signature: signature.signature,
            for: tamperedData,
            using: keyMeta.id
        )

        XCTAssertFalse(isTamperedValid)
    }

    func testSecureRandom() {
        let bytes = SecureRandom.bytes(count: 32)
        XCTAssertEqual(bytes.count, 32)

        let token = SecureRandom.token(length: 16)
        XCTAssertFalse(token.isEmpty)

        let uuid = SecureRandom.uuid()
        XCTAssertNotNil(uuid)
    }

    func testHashUtilities() {
        guard let data = "Test data".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }

        let sha256 = HashUtilities.sha256(data)
        XCTAssertEqual(sha256.count, 32)

        let sha256Hex = HashUtilities.sha256Hex(data)
        XCTAssertEqual(sha256Hex.count, 64)

        let sha512 = HashUtilities.sha512(data)
        XCTAssertEqual(sha512.count, 64)
    }

    // MARK: - Vulnerability Disclosure Tests

    func testVulnerabilitySeverity() {
        XCTAssertEqual(VulnerabilitySeverity.from(cvssScore: 0.0), .none)
        XCTAssertEqual(VulnerabilitySeverity.from(cvssScore: 2.5), .low)
        XCTAssertEqual(VulnerabilitySeverity.from(cvssScore: 5.0), .medium)
        XCTAssertEqual(VulnerabilitySeverity.from(cvssScore: 8.0), .high)
        XCTAssertEqual(VulnerabilitySeverity.from(cvssScore: 10.0), .critical)
    }

    func testVulnerabilityManager() async {
        let manager = VulnerabilityManager()

        let vuln = await manager.reportVulnerability(
            title: "Test Vulnerability",
            description: "A test vulnerability for testing",
            severity: .high,
            affectedComponents: [
                AffectedComponent(name: "TestModule", affectedVersions: "< 1.2.0")
            ],
            reporter: "security-researcher"
        )

        XCTAssertTrue(vuln.trackingId.hasPrefix("ANIGMA-"))
        XCTAssertEqual(vuln.severity, .high)
        XCTAssertEqual(vuln.status, .reported)

        // Confirm the vulnerability
        try? await manager.confirmVulnerability(vuln.id, cvssScore: 7.5, confirmedBy: "security-team")

        let confirmed = await manager.getVulnerability(vuln.id)
        XCTAssertEqual(confirmed?.status, .confirmed)

        // Check statistics
        let stats = await manager.getStatistics()
        XCTAssertEqual(stats.totalVulnerabilities, 1)
    }

    func testSecurityAdvisory() {
        let advisory = SecurityAdvisory(
            advisoryId: "ANIGMA-SA-2024-001",
            vulnerabilityId: UUID(),
            cveId: "CVE-2024-12345",
            title: "Critical Security Issue",
            summary: "A critical security issue was discovered",
            fullText: "Full details here...",
            severity: .critical,
            cvssScore: 9.8,
            affectedVersions: "< 2.0.0",
            fixedVersions: ">= 2.0.0",
            recommendedAction: "Upgrade immediately"
        )

        XCTAssertEqual(advisory.severity, .critical)

        let markdown = advisory.toMarkdown()
        XCTAssertTrue(markdown.contains("ANIGMA-SA-2024-001"))
        XCTAssertTrue(markdown.contains("CVE-2024-12345"))
        XCTAssertTrue(markdown.contains("CRITICAL"))
    }

    // MARK: - Security Module Integration

    func testSecurityModuleInitialization() async {
        let auditLog = AuditLog()
        let security = await SecurityModule.initialize(auditLog: auditLog)

        XCTAssertNotNil(security.keyManager)
        XCTAssertNotNil(security.xaiRegistry)
        XCTAssertNotNil(security.enforcementEngine)
        XCTAssertNotNil(security.modelIntegrity)
        XCTAssertNotNil(security.vulnerabilityManager)
    }
}
