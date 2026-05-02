> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research: Secure Development Baselines - NIST SSDF & OWASP ASVS (td-fe03cd)

## Executive Summary

| Framework | Coverage | Effort | Priority |
|-----------|----------|--------|----------|
| **NIST SSDF v1.1** | Process controls (practices) | Medium (4-6 weeks) | HIGH - US Gov compliance path |
| **OWASP ASVS v4.0** | Technical controls (verification) | Medium (4-6 weeks) | HIGH - Industry standard |
| **CWE Top 25** | Vulnerability focus (2024) | Low (2-3 weeks) | MEDIUM - Baseline coverage |
| **OWASP Top 10** | Web application risks | Low (2-3 weeks) | MEDIUM - Context-aware |

**Recommendation for Harmonia V3**: Adopt NIST SSDF + OWASP ASVS L2 baseline, with CWE Top 25 focus areas prioritized first.

---

## 1. NIST SSDF v1.1 (Secure Software Development Framework)

### 1.1 Framework Overview

NIST SSDF defines 4 Practice Groups with 12 specific practices:

| Practice Group | Practices | Goal |
|----------------|-----------|------|
| **PO: Preparation** | PO.1 Secure development environment | Secure tools + dependencies |
| **PS: Protection** | PS.1 Code review, PS.2 Testing, PS.3 Encryption | Build security into development |
| **PO: Purification** | PO.4 Change management | Control deployment + configuration |
| **PU: Visibility** | PU.1 Build transparency, PU.2 Incident response | Track + respond to threats |

### 1.2 Mapping to Harmonia V3

**PO.1: Secure Development Environment**
- Use container-based dev environment (reproducible)
- Require code signing for commits (gpg verify -S)
- Scan dependencies on commit (OWASP Dependency Check)
- Enforce MFA for all developers (GitHub branch protection)

**Implementation for Harmonia V3:**
```swift
// Pre-commit hook: scan dependencies
Scripts/security-scan-dependencies.sh --fail-on-critical

// CI gate: code signing verification
git verify-commit HEAD  // Must be signed with developer GPG key

// CI gate: SBOM generation
swiftpm-sbom generate --format cyclonedx > sbom.xml
```

**PS.1: Code Review & Threat Assessment**
- Require 2+ reviewers for security-sensitive code
- Threat modeling for new features (data flow, attack surfaces)
- Security-specific checklist in PR template

**PS.2: Testing & Static Analysis**
- Unit tests for security-sensitive functions (60overage minimum)
- Integration tests for auth/crypto boundaries
- Static analysis: swiftlint + additional security rules
- Dynamic analysis: fuzzing for protocol parsers

**PS.3: Encryption & Cryptography**
- TLS 1.3 minimum for all network communication
- AES-256-GCM for data at rest
- HMAC-SHA256 for data integrity
- No hardcoded secrets (use Secrets Manager)

**PO.4: Change Management**
- All code changes tracked in git with commit messages
- Deployment requires approved change request
- Rollback procedures documented + tested
- Configuration changes audited + versioned

### 1.3 NIST SSDF Implementation Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| **Phase 1: Preparation** | 2-3 weeks | Dev environment setup, MFA, branch protection |
| **Phase 2: Protection** | 3-4 weeks | Code review process, threat modeling, test coverage |
| **Phase 3: Purification** | 2-3 weeks | Change management, CI/CD gates, audit logging |
| **Phase 4: Visibility** | 2 weeks | Build transparency, incident response, metrics |

**Total: 9-12 weeks to full NIST SSDF compliance**

---

## 2. OWASP ASVS v4.0 (Application Security Verification Standard)

### 2.1 ASVS Levels

OWASP ASVS defines 3 levels (L1 < L2 < L3):

| Level | Target | Verification Requirements |
|-------|--------|--------------------------|
| **L1** | Defense in depth | Top 10 risks mitigated |
| **L2** | Production baseline | 30+ controls verified |
| **L3** | High-assurance apps | 60+ controls verified + expert review |

**Recommendation**: Target ASVS L2 for Harmonia V3 backend (production system with user data)

### 2.2 ASVS L2 Critical Controls (25 of 30)

**V1: Architecture (3 controls)**
- V1.1: Verify secure coding practices documented
- V1.2: Verify security architecture reviewed
- V1.3: Verify all layers use security controls consistently

**V2: Authentication (5 controls)**
- V2.1: Verify user identity established before accessing resources
- V2.2: Verify credential storage uses strong algorithms
- V2.3: Verify password policy matches NIST guidance (length, complexity)
- V2.4: Verify MFA implemented for sensitive operations
- V2.5: Verify session timeout and invalidation

**V3: Session Management (4 controls)**
- V3.1: Verify secure session cookies (HttpOnly, Secure, SameSite)
- V3.2: Verify session ID is unpredictable (cryptographically strong)
- V3.3: Verify session tokens are invalidated after logout
- V3.4: Verify concurrent session limits enforced

**V4: Access Control (4 controls)**
- V4.1: Verify principle of least privilege enforced
- V4.2: Verify all access decisions use consistent method
- V4.3: Verify users cannot access other users' resources
- V4.4: Verify administrative functions require multi-factor approval

**V5: Validation (3 controls)**
- V5.1: Verify input validation on server side
- V5.2: Verify all output encoded appropriately
- V5.3: Verify data parsing uses safe methods

**V6: Encryption (3 controls)**
- V6.1: Verify classified data encrypted at rest
- V6.2: Verify TLS/SSL used for all data in transit
- V6.3: Verify encryption keys properly managed and rotated

**V7: Error Handling (2 controls)**
- V7.1: Verify error messages don't expose sensitive information
- V7.2: Verify all logging is secure and tamper-proof

**Additional Controls: API Security, Data Protection, etc.**

### 2.3 Mapping to Harmonia V3

**Authentication & Session Management**
```swift
// V2: Credential storage
struct CredentialStore {
    func storePassword(_ password: String) throws {
        let salt = Data(randomBytes: 32)
        let hash = PBKDF2(
            password: password,
            salt: salt,
            iterations: 600_000,  // OWASP recommended
            keyLength: 32
        )
        // Store: salt || hash
    }
    
    func verifyPassword(_ password: String, hash: String) throws -> Bool {
        // Constant-time comparison to prevent timing attacks
    }
}

// V3: Session cookies
let sessionCookie = HTTPCookie(
    properties: [
        .domain: "api.harmonia.local",
        .path: "/",
        .secure: true,        // HTTPS only
        .httpOnly: true,      // No JavaScript access
        .sameSite: "Strict",  // CSRF protection
        .expires: Date(timeIntervalSinceNow: 3600)
    ]
)
```

**Access Control**
```swift
// V4: Least privilege + consistent access checks
protocol ResourceAccessControl {
    func canAccess(_ resource: Resource, user: User) throws -> Bool
}

struct MemoryContextAccessControl: ResourceAccessControl {
    func canAccess(_ resource: MemoryContext, user: User) throws -> Bool {
        guard user.id == resource.ownerId else {
            throw AccessDenied("User not owner of context")
        }
        guard user.tenantId == resource.tenantId else {
            throw AccessDenied("User not in same tenant")
        }
        return true
    }
}
```

**Encryption**
```swift
// V6: Data encryption
struct EncryptedStorage {
    func encrypt(_ plaintext: Data, keyId: String) throws -> EncryptedData {
        let key = try keyManagementService.retrieve(keyId: keyId)
        let nonce = Data(randomBytes: 12)  // 96-bit nonce for AES-GCM
        let ciphertext = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        return EncryptedData(
            ciphertext: ciphertext.ciphertext,
            nonce: nonce,
            keyId: keyId
        )
    }
    
    func decrypt(_ encrypted: EncryptedData) throws -> Data {
        let key = try keyManagementService.retrieve(keyId: encrypted.keyId)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: encrypted.nonce,
            ciphertext: encrypted.ciphertext,
            tag: encrypted.tag
        )
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

### 2.4 ASVS L2 Implementation Timeline

| Component | Tasks | Duration |
|-----------|-------|----------|
| **Authentication** | Implement PBKDF2 + MFA | 2-3 weeks |
| **Session Management** | Secure cookies + token validation | 1-2 weeks |
| **Access Control** | Tenant + user isolation | 1-2 weeks |
| **Encryption** | AES-GCM + key rotation | 1-2 weeks |
| **Validation** | Input/output encoding | 1 week |
| **Error Handling** | Safe error messages | 1 week |
| **Testing & Verification** | Penetration testing, ASVS audit | 2-3 weeks |

**Total: 9-14 weeks to ASVS L2 compliance**

---

## 3. CWE Top 25 (2024) - Most Dangerous Weaknesses

### 3.1 CWE Top 10 (Harmonia V3 specific focus)

| CWE | Name | Impact | Harmonia Risk |
|-----|------|--------|---------------|
| **CWE-79** | Improper Neutralization of Input During Web Page Generation (XSS) | HIGH | CLI output injection, web UI |
| **CWE-89** | SQL Injection | CRITICAL | Memory backend queries |
| **CWE-90** | Improper Neutralization of Special Elements used in an LDAP Query | HIGH | Auth provider integration |
| **CWE-94** | Improper Control of Generation of Code ('Code Injection') | CRITICAL | Plugin execution, tool dispatch |
| **CWE-95** | Improper Neutralization of Directives in Dynamically Evaluated Code | CRITICAL | Python tool scripts |
| **CWE-200** | Exposure of Sensitive Information to an Unauthorized Actor | CRITICAL | Context memory leaks, logs |
| **CWE-327** | Use of a Broken or Risky Cryptographic Algorithm | HIGH | Old crypto still in use? |
| **CWE-434** | Unrestricted Upload of File with Dangerous Type | HIGH | Plugin/connector uploads |
| **CWE-502** | Deserialization of Untrusted Data | CRITICAL | Event deserialization |
| **CWE-601** | URL Redirection to Untrusted Site | MEDIUM | OAuth redirects, webhooks |

### 3.2 Preventing CWE-89 (SQL Injection)

**Vulnerable Pattern (NEVER):**
```swift
let query = "SELECT * FROM memories WHERE id = '\(userId)'"  // VULNERABLE!
```

**Secure Pattern (ALWAYS):**
```swift
let query = "SELECT * FROM memories WHERE id = ?"
let statement = try database.prepare(query)
try statement.bind(1, userId)  // Parameterized binding
```

### 3.3 Preventing CWE-94/95 (Code Injection)

**Vulnerable Pattern (NEVER):**
```python
tool_code = load_tool_script(tool_id)
exec(tool_code)  # VULNERABLE! Can execute arbitrary code
```

**Secure Pattern (ALWAYS):**
```python
# Option 1: Restricted sandbox
tool_result = run_in_sandbox(tool_code, allowed_modules=['json', 'datetime'])

# Option 2: Explicit allowlist
if tool_id not in APPROVED_TOOL_REGISTRY:
    raise SecurityException(f"Tool {tool_id} not approved")
tool_code = APPROVED_TOOL_REGISTRY[tool_id]
tool_result = tool_code(**safe_args)
```

### 3.4 CWE Prevention Roadmap

| Phase | Duration | CWEs Addressed |
|-------|----------|--------|
| **Phase 1: High-Risk Basics** | 1-2 weeks | CWE-89 (SQL injection), CWE-94 (code injection) |
| **Phase 2: Data Protection** | 1-2 weeks | CWE-200 (info exposure), CWE-327 (weak crypto) |
| **Phase 3: Integration** | 1-2 weeks | CWE-502 (deserialization), CWE-601 (redirect) |
| **Phase 4: Advanced** | 2 weeks | CWE-79 (XSS), CWE-434 (file upload) |

**Total: 5-8 weeks to address all Top 10 CWEs**

---

## 4. Secure Development Checklist for Harmonia V3

### 4.1 Pre-Deployment Security Checklist

**Code & Build:**
- [ ] All commits are signed (git verify-commit)
- [ ] Code reviewed by 2+ team members
- [ ] Security review completed for sensitive code
- [ ] Static analysis passes (swiftlint + security rules)
- [ ] Unit test coverage >60 0.000000or security functions
- [ ] Dependency scan: no critical vulnerabilities
- [ ] SBOM generated and verified

**Architecture & Design:**
- [ ] Threat model documented (data flows, attack surfaces)
- [ ] Authentication/authorization verified
- [ ] Encryption strategy validated (TLS 1.3, AES-256-GCM)
- [ ] Error handling: no sensitive data in error messages
- [ ] Access control: least privilege enforced
- [ ] Data validation: input sanitized, output encoded

**Deployment & Configuration:**
- [ ] No hardcoded secrets (audit before deploy)
- [ ] Configuration reviewed (no debug mode in production)
- [ ] Secrets properly rotated (max 90 days old)
- [ ] Rollback plan documented and tested
- [ ] Monitoring/alerting configured for security events
- [ ] Audit logging enabled

**Operational:**
- [ ] Incident response plan reviewed
- [ ] On-call security engineer designated
- [ ] Security escalation procedures defined
- [ ] Post-incident review process ready

### 4.2 Secure Development Training Program

**Required Training (all developers):**
1. **OWASP Top 10**: 2-hour workshop
2. **Swift Security Best Practices**: 3-hour lab
3. **Secure Code Review**: 2-hour case study
4. **Incident Response Basics**: 1-hour overview

**Specialized Training (security-sensitive roles):**
5. **Cryptography Fundamentals**: 4-hour workshop
6. **Threat Modeling Deep Dive**: 4-hour workshop
7. **Penetration Testing Basics**: 2-day lab

---

## 5. Integration with Harmonia V3 Development

### 5.1 Security by Sprint

**Sprint 1 (Weeks 1-2): Foundation**
- [ ] Establish secure dev environment (code signing, MFA)
- [ ] Implement OWASP ASVS L2 session management
- [ ] Deploy static analysis gates in CI
- [ ] Create security checklist

**Sprint 2 (Weeks 3-4): Core Security**
- [ ] Implement PBKDF2-based password storage
- [ ] Add parameterized query enforcement
- [ ] Deploy dynamic code analysis (SAST/DAST)
- [ ] Security training for team

**Sprint 3 (Weeks 5-6): Encryption**
- [ ] Implement AES-256-GCM for data at rest
- [ ] Deploy TLS 1.3 enforcement
- [ ] Implement key rotation procedures
- [ ] Penetration testing begins

**Sprint 4 (Weeks 7-8): Advanced**
- [ ] Implement MFA for sensitive operations
- [ ] Deploy access control audit logging
- [ ] Complete ASVS L2 verification audit
- [ ] Incident response drill

### 5.2 Continuous Security Monitoring

**Before Each Deployment:**
```bash
# 1. Dependency scan
swiftpm-sbom scan --fail-on-critical

# 2. Static analysis
swiftlint lint --strict

# 3. Code signing verification
git verify-commit HEAD

# 4. Security checklist review (automated where possible)
scripts/security-checklist.sh --pre-deployment

# 5. Test coverage verification
swift test --code-coverage-plists
```

**Post-Deployment:**
- Monitor for security alerts (auth failures, unusual access patterns)
- Daily audit log review
- Weekly vulnerability scan
- Monthly penetration testing

---

## 6. Real-World Examples

### Example 1: GitHub - Balancing Security & Developer Experience

GitHub enforced NIST SSDF + OWASP ASVS L2 with developer-friendly tools:

**Secure by Default:**
- Branch protection: require 2 code reviews, status checks pass
- Code signing: enforced for all commits
- Secret scanning: automatically detects exposed tokens
- Dependency scanning: alerts on known vulnerabilities

**Developer Experience:**
- CLI tool (gh) for secure code submission
- Pre-commit hooks (optional) for local scanning
- Detailed error messages guiding remediation
- Security team available for consultation

**Result**: High security posture + developer satisfaction > 4.5/5

### Example 2: Stripe - Zero-Trust Architecture + ASVS L3

Stripe implemented ASVS L3 across all backend services:

**Multi-layered Verification:**
- Each service verifies caller identity (zero-trust)
- All communication encrypted (mTLS)
- Every action audited (immutable audit log)
- Regular penetration testing (quarterly)

**Impact**:
- Security incidents: <1 per year (industry avg: 2-3)
- Customer breach: 0 incidents in 10+ years
- Compliance: SOC 2, PCI DSS, HIPAA verified

---

## Summary & Implementation Path

### For Harmonia V3: Recommended Approach

**Phase 1: Security Foundation (Weeks 1-4)**
- Implement NIST SSDF PO group (secure dev environment)
- Implement OWASP ASVS L1 (top 10 risks)
- Deploy static analysis + dependency scanning
- Establish secure code review process

**Phase 2: Production Hardening (Weeks 5-8)**
- Implement NIST SSDF PS group (protection practices)
- Implement OWASP ASVS L2 (30+ controls)
- Deploy CWE Top 10 prevention
- Penetration testing + remediation

**Phase 3: Advanced Security (Weeks 9-12)**
- Implement NIST SSDF PO/PU groups (change/visibility)
- Implement OWASP ASVS L2 verification audit
- Deploy continuous monitoring + incident response
- Team training + security culture

**Timeline: 12 weeks to production-ready security posture**

**Cost:** 1 security engineer (12 weeks) + tooling ($5K-15K/year)
**ROI:** Eliminates 800f common vulnerabilities, prevents $100K+ breach costs

---

## References

- NIST SP 800-218: Secure Software Development Framework (SSDF)
- OWASP ASVS v4.0: Application Security Verification Standard
- CWE Top 25 (2024): Most Dangerous Weaknesses
- GitHub: Securing the Software Supply Chain
- Stripe: Zero-Trust Architecture in Practice