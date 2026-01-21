# Security and Governance Compliance Guide

This document provides comprehensive security and governance guidelines for agents working with Anigma's two-tier architecture.

## 1. Core Layer Security Requirements

### 1.1 Immutable Security Boundaries

**Core Layer Security Invariants:**
- **Hardware-backed signing**: All evidence heads signed with Secure Enclave/TPM keys
- **Trusted timestamping**: External RFC3161 TSA verification for legal timestamps
- **Canonical serialization**: Cross-platform deterministic byte signing
- **Key custody management**: Hardware-protected private keys with rotation/revocation
- **Offline verification**: Evidence bundles verifiable without trusting Anigma infrastructure

**Critical Security Rules:**
- NEVER bypass Harmonia wrapper for Core operations
- NEVER use direct Swift build commands in production
- NEVER access Core databases directly
- ALWAYS generate evidence for ML operations
- ALWAYS follow emergency procedures for security incidents

### 1.2 Harmonia Security Interface

**Secure Command Patterns:**
```bash
# ✅ SECURE: Use wrapper for all operations
Anigma/Scripts/harmonia.sh trust bounds
Anigma/Scripts/harmonia.sh security status
Anigma/Scripts/harmonia.sh verify integrity

# ✅ SECURE: Evidence generation
anigma-receipt explain --agent-id "agent-123" --legal-grade --format pdf
anigma-receipt bundle --type legal_discovery --sign --timestamp

# ✅ SECURE: Verification
anigma-verify ./evidence-bundle/ --strict --trust-anchors ./certs/
```

**Forbidden Operations:**
```bash
# ❌ FORBIDDEN: Direct Core access
swift build
swift test
swift run harmonia
./.build/release/harmonia
sqlite3 harmonia_harness.sqlite "SELECT * FROM trust_boundaries"
```

### 1.3 Evidence Generation Requirements

**Mandatory Evidence for All ML Operations:**
```json
{
  "evidence_head": {
    "hash": "sha256:...",
    "signature": "base64:...",
    "timestamp": "2025-12-15T10:30:00Z",
    "tsa_token": "base64:...",
    "model_hash": "sha256:...",
    "input_hash": "sha256:...",
    "output_hash": "sha256:..."
  },
  "provenance": {
    "agent_id": "agent-123",
    "run_id": "run-456",
    "step_id": "step-789",
    "model_spec": {
      "name": "model-name",
      "version": "1.0.0",
      "hash": "sha256:..."
    },
    "run_spec": {
      "temperature": 0.7,
      "max_tokens": 1000,
      "parameters": {...}
    }
  },
  "content": {
    "response": "Generated content",
    "confidence": 0.95,
    "token_count": 150
  }
}
```

**Evidence Generation Checklist:**
- [ ] Hardware-backed signature generated
- [ ] External TSA timestamp obtained
- [ ] Model hash calculated and stored
- [ ] Input/output hashes calculated
- [ ] Agent identification recorded
- [ ] Run context documented
- [ ] Evidence stored in Accessum ledger

## 2. Capability Module Security

### 2.1 Data Governance Requirements

**PII Handling Rules:**
```swift
// ✅ SECURE: Use Harmonia governance for PII
let policyResult = await harmonia.evaluatePolicy(
    action: "process_pii_data",
    context: [
        "data_type": "medical_records",
        "user_role": "healthcare_provider",
        "consent_obtained": "true"
    ]
)

if policyResult.allowed {
    // Process with audit trail
    await auditLog.logDataAccess(
        userId: userId,
        dataType: "medical_records",
        purpose: "treatment",
        timestamp: Date()
    )
} else {
    throw GovernanceError.policyViolation(policyResult.reason)
}
```

**Content Sanitization:**
```swift
// ✅ SECURE: Sanitize content with privilege logging
struct ContentSanitizer {
    func sanitize(_ content: String, for user: User) async throws -> String {
        let sanitized = try await redactPII(content)
        
        await auditLog.logContentSanitization(
            originalLength: content.count,
            sanitizedLength: sanitized.count,
            redactionCount: redactionCount,
            userId: user.id,
            timestamp: Date()
        )
        
        return sanitized
    }
}
```

### 2.2 Access Control Implementation

**RBAC/ABAC Patterns:**
```swift
// ✅ SECURE: Use existing permission patterns
struct PermissionComponent: Component, Codable {
    let userId: String
    let resource: String
    let actions: [String]
    let conditions: [String: String]
}

struct AccessControlSystem: System {
    func update(world: World) async {
        let requests = await world.query(AccessRequestComponent.self)
        
        for (entity, request) in requests {
            let allowed = await evaluateAccess(
                userId: request.userId,
                resource: request.resource,
                action: request.action
            )
            
            if allowed {
                await world.addComponent(entity, AccessGrantedComponent())
            } else {
                await world.addComponent(entity, AccessDeniedComponent(reason: "Insufficient privileges"))
                await auditLog.logAccessDenied(request)
            }
        }
    }
}
```

### 2.3 Audit Trail Requirements

**Mandatory Audit Events:**
```swift
// ✅ SECURE: Comprehensive audit logging
protocol AuditEvent {
    var timestamp: Date { get }
    var userId: String? { get }
    var action: String { get }
    var resource: String? { get }
    var outcome: AuditOutcome { get }
    var metadata: [String: String] { get }
}

enum AuditOutcome {
    case success
    case failure(reason: String)
    case policyViolation(reason: String)
    case securityIncident(reason: String)
}

// Usage examples
await auditLog.log(
    DataAccessEvent(
        userId: userId,
        action: "read_document",
        resource: documentId,
        outcome: .success,
        metadata: ["document_type": "medical_record"]
    )
)

await auditLog.log(
    PolicyViolationEvent(
        userId: userId,
        action: "export_data",
        resource: datasetId,
        outcome: .policyViolation(reason: "Insufficient data classification"),
        metadata: ["required_clearance": "secret", "user_clearance": "confidential"]
    )
)
```

## 3. ML Operations Security

### 3.1 Model Integrity Verification

**Model Hash Verification:**
```swift
// ✅ SECURE: Verify model integrity before use
struct ModelIntegrityVerifier {
    func verifyModel(at path: URL, expectedHash: String) throws -> Bool {
        let actualHash = calculateSHA256(forFileAt: path)
        
        guard actualHash == expectedHash else {
            throw ModelIntegrityError.hashMismatch(
                expected: expectedHash,
                actual: actualHash
            )
        }
        
        return true
    }
    
    func calculateSHA256(forFileAt path: URL) -> String {
        // Implementation using CryptoKit
    }
}
```

**Model Drift Detection:**
```swift
// ✅ SECURE: Monitor for model drift
struct ModelDriftDetector {
    func detectDrift(
        currentOutputs: [ModelOutput],
        baselineOutputs: [ModelOutput],
        threshold: Double = 0.05
    ) -> ModelDriftResult {
        let driftScore = calculateDriftScore(current: currentOutputs, baseline: baselineOutputs)
        
        return ModelDriftResult(
            driftScore: driftScore,
            driftDetected: driftScore > threshold,
            recommendation: driftScore > threshold ? "Retrain model" : "Continue monitoring"
        )
    }
}
```

### 3.2 Prompt Injection Prevention

**Input Sanitization:**
```swift
// ✅ SECURE: Sanitize prompts against injection
struct PromptSanitizer {
    func sanitize(_ prompt: String) -> SanitizedPrompt {
        let cleaned = prompt
            .replacingOccurrences(of: "\\b(system|assistant|user)\\s*:", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[INST\\]|\\[/INST\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return SanitizedPrompt(
            original: prompt,
            sanitized: cleaned,
            riskScore: calculateRiskScore(prompt),
            warnings: detectSuspiciousPatterns(prompt)
        )
    }
    
    private func calculateRiskScore(_ prompt: String) -> Double {
        // Implement risk scoring algorithm
    }
    
    private func detectSuspiciousPatterns(_ prompt: String) -> [String] {
        // Detect injection attempts, role confusion, etc.
    }
}
```

### 3.3 Output Validation

**Content Safety Checks:**
```swift
// ✅ SECURE: Validate model outputs
struct OutputValidator {
    func validate(_ output: String, context: ValidationContext) -> ValidationResult {
        var violations: [SafetyViolation] = []
        
        // Check for PII leakage
        if let piiViolation = detectPIILeakage(output, allowedContext: context.allowedPII) {
            violations.append(piiViolation)
        }
        
        // Check for harmful content
        if let harmfulViolation = detectHarmfulContent(output) {
            violations.append(harmfulViolation)
        }
        
        // Check for policy violations
        if let policyViolation = detectPolicyViolation(output, policies: context.applicablePolicies) {
            violations.append(policyViolation)
        }
        
        return ValidationResult(
            isSafe: violations.isEmpty,
            violations: violations,
            sanitizedOutput: violations.isEmpty ? output : sanitizeOutput(output, violations: violations)
        )
    }
}
```

## 4. Emergency Security Procedures

### 4.1 Key Compromise Response

**Immediate Response Actions:**
```bash
# 1. Emergency key revocation
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# 2. Generate verification bundle for compromise period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-15" \
    --include-revoked-keys

# 3. Emergency system stop
Anigma/Scripts/harmonia.sh emergency stop

# 4. Verify system integrity
Anigma/Scripts/harmonia.sh verify integrity
```

**Post-Incident Recovery:**
```bash
# 1. Generate new keys
anigma-key generate --type signing --hardware-backed

# 2. Update trust anchors
anigma-trust update-anchors --new-anchors ./new-anchors/

# 3. Rotate all evidence signatures
anigma-receipt rotate-signatures --start-date "2024-12-15"

# 4. Verify recovery
anigma-verify ./recovery-bundle/ --strict
```

### 4.2 Data Breach Response

**Breach Containment:**
```bash
# 1. Immediate containment
Anigma/Scripts/harmonia.sh write-gate close
Anigma/Scripts/harmonia.sh mode set readonly

# 2. Generate breach evidence
anigma-receipt bundle --type data_breach --sign --timestamp

# 3. Audit affected data
Anigma/Scripts/harmonia.sh audit data-access --start-date "2024-12-01" --end-date "2024-12-15"

# 4. Export audit logs for investigation
Anigma/Scripts/harmonia.sh export-audit-logs --format json --output ./breach-audit-logs.json
```

**Investigation Support:**
```bash
# 1. Generate comprehensive evidence bundle
anigma-receipt bundle \
    --type forensic_investigation \
    --include-system-logs \
    --include-access-logs \
    --include-evidence-heads \
    --sign \
    --timestamp

# 2. Create timeline of events
anigma-timeline generate \
    --start-date "2024-12-01" \
    --end-date "2024-12-15" \
    --include-security-events \
    --include-access-events \
    --output ./breach-timeline.json
```

## 5. Compliance and Legal Requirements

### 5.1 GDPR Compliance

**Data Subject Rights Implementation:**
```swift
// ✅ COMPLIANT: Right to be forgotten
struct GDPRRightToErasure {
    func eraseUserData(for userId: String) async throws {
        // Log erasure request
        await auditLog.logGDPRRequest(
            userId: userId,
            requestType: "erasure",
            timestamp: Date()
        )
        
        // Erase user data from all modules
        await eraseFromAllModules(userId: userId)
        
        // Generate evidence of erasure
        let evidence = await anigmaReceipt.generateEvidence(
            operation: "gdpr_erasure",
            userId: userId,
            timestamp: Date()
        )
        
        await accessum.storeEvidence(evidence)
    }
}
```

**Data Processing Records:**
```swift
// ✅ COMPLIANT: Maintain processing records
struct DataProcessingRecord {
    let controller: String
    let processor: String
    let purposes: [String]
    let legalBasis: String
    let dataCategories: [String]
    let retentionPeriod: String
    let securityMeasures: [String]
    let internationalTransfers: [String]
}
```

### 5.2 HIPAA Compliance

**Protected Health Information (PHI) Handling:**
```swift
// ✅ COMPLIANT: PHI access controls
struct PHIAccessController {
    func requestPHIAccess(
        userId: String,
        patientId: String,
        purpose: String,
        minimumNecessary: [String]
    ) async throws -> PHIAccessResult {
        
        // Verify user authorization
        guard await verifyPHIAuthorization(userId: userId, patientId: patientId) else {
            throw HIPAAError.unauthorizedAccess
        }
        
        // Apply minimum necessary standard
        let filteredData = await applyMinimumNecessary(
            patientId: patientId,
            requestedFields: minimumNecessary
        )
        
        // Log access for audit trail
        await auditLog.logPHIAccess(
            userId: userId,
            patientId: patientId,
            purpose: purpose,
            fieldsAccessed: minimumNecessary,
            timestamp: Date()
        )
        
        return PHIAccessResult(data: filteredData, auditId: auditId)
    }
}
```

### 5.3 SOC 2 Compliance

**Security Controls Implementation:**
```swift
// ✅ COMPLIANT: SOC 2 security controls
struct SOC2SecurityControls {
    // Common Criteria 6.1: Logical Access Controls
    func enforceLogicalAccess(user: User, resource: Resource) async -> AccessDecision {
        return await evaluateAccessControl(user: user, resource: resource)
    }
    
    // Common Criteria 6.7: System Operation
    func monitorSystemOperations() async -> SystemOperationReport {
        return await generateSystemOperationReport()
    }
    
    // Common Criteria 6.8: Change Management
    func trackSystemChanges(change: SystemChange) async {
        await auditLog.logSystemChange(change)
    }
    
    // Common Criteria 6.10: System Configuration
    func validateSystemConfiguration() async -> ConfigurationReport {
        return await validateAgainstSecurityBaseline()
    }
}
```

## 6. Security Testing and Validation

### 6.1 Security Test Cases

**Authentication and Authorization Tests:**
```swift
class SecurityTests: XCTestCase {
    func testAuthenticationBypass() async throws {
        // Test that authentication cannot be bypassed
        let result = await attemptAuthenticationBypass()
        XCTAssertFalse(result.success, "Authentication bypass should fail")
    }
    
    func testAuthorizationEscalation() async throws {
        // Test that privilege escalation is prevented
        let result = await attemptPrivilegeEscalation()
        XCTAssertFalse(result.success, "Privilege escalation should fail")
    }
    
    func testDataExfiltration() async throws {
        // Test that data exfiltration is prevented
        let result = await attemptDataExfiltration()
        XCTAssertFalse(result.success, "Data exfiltration should fail")
    }
}
```

### 6.2 Penetration Testing

**Security Test Scenarios:**
```bash
# Test Core Layer security
./Scripts/security-test-core.sh

# Test module isolation
./Scripts/security-test-module-isolation.sh

# Test data protection
./Scripts/security-test-data-protection.sh

# Test audit trail integrity
./Scripts/security-test-audit-trail.sh
```

### 6.3 Continuous Security Monitoring

**Security Metrics:**
```swift
struct SecurityMetrics {
    let authenticationFailures: Int
    let authorizationFailures: Int
    let policyViolations: Int
    let securityIncidents: Int
    let evidenceGenerationFailures: Int
    let keyRotationEvents: Int
}
```

**Alert Thresholds:**
```swift
struct SecurityAlertThresholds {
    let maxAuthFailuresPerHour = 10
    let maxPolicyViolationsPerDay = 5
    let maxEvidenceFailuresPerHour = 3
    let maxKeyRotationFailures = 0
}
```

## 7. Security Documentation and Training

### 7.1 Security Documentation Requirements

**Required Security Documents:**
- Security Policy and Procedures
- Incident Response Plan
- Data Classification Guidelines
- Access Control Procedures
- Encryption and Key Management
- Audit and Logging Procedures
- Security Training Materials

### 7.2 Agent Security Training

**Security Training Checklist:**
- [ ] Understand Core Layer security boundaries
- [ ] Know how to use Harmonia wrapper securely
- [ ] Understand evidence generation requirements
- [ ] Know emergency response procedures
- [ ] Understand data handling requirements
- [ ] Know how to report security incidents
- [ ] Understand compliance requirements

Following these security and governance guidelines ensures that Anigma maintains its court-safe, cryptographically auditable security posture while enabling compliant and secure AI operations.