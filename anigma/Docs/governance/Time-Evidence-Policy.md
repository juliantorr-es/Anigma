# Time-Evidence Policy

> Last updated: 2025-12-29
> Canonical v3.2 Requirement: Time anchoring as external evidence with documented trust assumptions
> Status: **Active** – Policy enforcement in progress

---

## Executive Summary

Time anchoring is **NOT a mathematical invariant**. It is external evidence with explicit trust assumptions. This policy specifies:

1. **Layers of time evidence** (system clock → RFC3161 TSA → NIST Beacon)
2. **Per-operation requirements** (which operations require which evidence level)
3. **Trust assumptions** (clearly documented and auditable)
4. **Verification procedures** (how auditors validate timestamps)

---

## Layers of Time Evidence

### Layer 1: System Clock (Weak Evidence)

**Description:** Timestamps from `Date().timeIntervalSince1970`

**Trust Assumption:** System clock is accurate to ±seconds

**Use Cases:**
- Development/local testing
- Non-critical logging
- UI display purposes

**Security:** 
- ❌ Not suitable for legal evidence
- ❌ Easy to manipulate (user can change system time)
- ❌ Not verifiable by third parties

**Cost:** Free (native to OS)

---

### Layer 2: Filesystem Timestamps (Slightly Stronger)

**Description:** File `mtime`/`ctime` recorded by filesystem

**Trust Assumption:** Filesystem enforces monotonic ordering; clock tampering visible

**Use Cases:**
- Build artifact dating
- Cache validation
- Access logs

**Security:**
- ❌ Still vulnerable to system-wide time manipulation
- ⚠️  Some evidence from immutability (can't retroactively change old files)
- ❌ Not verifiable by external parties

**Cost:** Free (filesystem native)

---

### Layer 3: NTP Synchronized (Better)

**Description:** System clock synchronized via Network Time Protocol

**Trust Assumption:** NTP server is accurate; synchronization prevents large skew

**Use Cases:**
- Distributed system coordination
- Logs that need temporal ordering
- Session lifecycle timestamps

**Security:**
- ⚠️  Requires NTP daemon running
- ⚠️  Vulnerable to network attacks
- ✓ Provides monotonic clock (prevents time reversals)

**Cost:** Low (standard infrastructure)

---

### Layer 4: RFC3161 TSA (Cryptographic Proof)

**Description:** Trusted Timestamp Authority token via RFC 3161

**Trust Assumption:** TSA is trustworthy; signature proves "this hash existed at this time"

**Use Cases:**
- Legal-grade evidence
- Regulatory compliance
- Court-admissible records

**Security:**
- ✓ Cryptographically signed by TSA
- ✓ External proof independent of our infrastructure
- ✓ Verifiable by hostile auditors
- ⚠️ Requires trust in specific TSA

**Cost:** Moderate (TSA service typically $0.50-2.00 per timestamp)

**Verification:**
```bash
# Verify RFC3161 token
openssl ts -verify -in timestamp.tsr -data payload.bin -CAfile tsa-cert.pem
```

---

### Layer 5: NIST Randomness Beacon (Government-Backed)

**Description:** NIST Randomness Beacon provides periodic signed random values

**Trust Assumption:** NIST infrastructure is reliable and government-sanctioned

**Use Cases:**
- High-stakes legal proceedings
- Regulatory evidence
- Government procurement

**Security:**
- ✓ Government-backed infrastructure
- ✓ Cryptographically signed
- ✓ Publicly auditable beacon
- ✓ Verifiable by any party

**Cost:** Free (public service)

**Verification:**
```bash
# NIST Beacon API: https://beacon.nist.gov/
curl https://beacon.nist.gov/api/records/latest
```

---

### Layer 6: Blockchain Anchoring (Decentralized)

**Description:** Hash anchored to blockchain (Bitcoin, Ethereum, etc.)

**Trust Assumption:** Blockchain consensus is immutable; network is secure

**Use Cases:**
- Maximum decentralization requirement
- Censorship-resistant evidence
- Cryptocurrency transactions

**Security:**
- ✓ Decentralized (no single point of trust)
- ✓ Cryptographically proven
- ⚠️ Requires trust in blockchain security
- ⚠️ May have legal/regulatory issues

**Cost:** Variable (blockchain fees)

---

## Per-Operation Requirements

### Policy Table

| Operation | Level | Requirement | Authority |
|-----------|-------|-------------|-----------|
| **Local Development Build** | 1 | System clock | Developer machine |
| **CI Build Artifact** | 2 | Filesystem timestamp | CI runner |
| **Test Execution Log** | 2 | NTP synchronized | Test infrastructure |
| **Master Ledger Entry** | 3 | NTP synchronized | Harmonia daemon |
| **Production Receipt** | 4 | RFC3161 + NIST | Production infrastructure |
| **Legal Evidence Bundle** | 5 | RFC3161 + NIST + Blockchain | Legal operations |
| **Regulatory Audit** | 4 | RFC3161 mandatory | Compliance officer |

---

## Implementation Requirements

### Code Integration

ReceiptWire and PhaseTransitionWire MUST enforce time evidence levels:

```swift
public struct ReceiptWire: Codable, Sendable {
    /// Required time evidence level for this receipt
    public let timestampEvidenceLevel: TimeEvidenceLevel
    
    /// Timestamp in milliseconds since epoch
    public let timestampMs: Int64
    
    /// Optional RFC3161 TSA token (required if evidenceLevel >= .rfc3161)
    public let tsaToken: String?
    
    /// Optional NIST Beacon record (required if evidenceLevel >= .nistBeacon)
    public let nistBeaconRecord: String?
}

public enum TimeEvidenceLevel: String, Codable {
    case systemClock = "system_clock"
    case filesystem = "filesystem"
    case ntp = "ntp"
    case rfc3161 = "rfc3161"
    case nistBeacon = "nist_beacon"
    case blockchain = "blockchain"
}
```

### Enforcement Rules

1. **ReceiptWire.create()** MUST accept `timeEvidenceLevel` parameter
2. **Production receipts** (timeEvidenceLevel >= .rfc3161) MUST have valid TSA tokens
3. **Legal receipts** (timeEvidenceLevel == .blockchain) MUST have blockchain proof
4. **Tests** MUST verify timestamp level enforcement

---

## Trust Assumptions Document

### For Auditors

When auditing time evidence, verify:

1. **System clock assumption:** NTP is running; clock skew < 1 second
   ```bash
   ntpstat  # Should show synchronized
   ```

2. **RFC3161 assumption:** TSA is trusted Certificate Authority
   ```bash
   openssl verify -CAfile root-certs.pem tsa-cert.pem
   ```

3. **NIST Beacon assumption:** Hash is present in official NIST Beacon
   ```bash
   curl https://beacon.nist.gov/api/records/<timestamp>
   ```

4. **Blockchain assumption:** Transaction confirmed with sufficient depth
   ```bash
   # Bitcoin example
   bitcoin-cli getrawtransaction <txid> 1 | jq .confirmations
   ```

---

## Verification Checklist

**For Hostile Auditors (Air-Gapped):**

1. **System clock authority** – Check if NTP was configured
   - ✓ Can verify: NTP server IP, synchronization source
   - ✗ Cannot verify offline: Current system accuracy

2. **RFC3161 authority** – Verify TSA signature and certificate chain
   - ✓ Can verify offline: TSA signature, certificate validity, root trust
   - ✓ Command: `openssl ts -verify -in token.tsr`

3. **NIST Beacon** – Check beacon.nist.gov for hash at timestamp
   - ✓ Can verify offline: Download historical beacon records
   - ✓ Source: https://beacon.nist.gov/api/records/<timestamp>

4. **Blockchain** – Verify transaction and confirmation count
   - ✓ Can verify offline: Chain work, transaction inclusion
   - ✓ Using: Bitcoin Core, Etherscan API cache, etc.

---

## Migration Path

### Phase 1: Documentation (Now)
- ✅ Policy defined with trust assumptions
- ✅ Per-operation requirements specified
- ✅ Verification procedures documented

### Phase 2: Code Enforcement (Q1 2026)
- [ ] Add `timestampEvidenceLevel` to ReceiptWire
- [ ] Add TSA token integration to production receipts
- [ ] Enforce level requirements in `ReceiptWire.create()`
- [ ] Tests verify enforcement

### Phase 3: Production Integration (Q2 2026)
- [ ] RFC3161 TSA service integration
- [ ] NIST Beacon querying for high-stakes operations
- [ ] Blockchain anchoring for legal-grade evidence
- [ ] Audit trail of evidence level enforcement

### Phase 4: Validation (Q3 2026)
- [ ] Auditor testing with air-gapped tooling
- [ ] Cross-validation with external TSAs
- [ ] Legal review for court admissibility

---

## Failure Modes & Remediation

### If System Clock is Inaccurate

**Detection:** Timestamp outside ±24 hours of actual time

**Impact:** Low for local development; HIGH for production

**Remediation:**
- Immediately stop accepting new timestamps
- Alert operations team
- Inspect NTP configuration
- Resync system time
- Re-verify affected receipts

### If RFC3161 TSA is Unavailable

**Detection:** TSA endpoint unreachable

**Impact:** Cannot create legal-grade receipts

**Remediation:**
- Fallback to NIST Beacon (if acceptable)
- Queue receipts for retry after TSA recovery
- Document downtime in audit trail
- Escalate to operations

### If Timestamp is Later Discovered to Be Forged

**Detection:** Blockchain anchor or NIST Beacon contradicts recorded time

**Impact:** HIGH – Evidence validity questioned

**Remediation:**
- Flag receipt as "disputed"
- Investigate NTP/TSA compromise
- Generate incident report
- Notify legal/compliance

---

## References

- RFC 3161 (Time-Stamp Protocol): https://tools.ietf.org/html/rfc3161
- NIST Randomness Beacon: https://beacon.nist.gov/
- NTP (Network Time Protocol): https://www.ntp.org/
- Bitcoin Timestamping: https://github.com/opentimestamps/python-opentimestamps

---

## Questions & Governance

**For clarifications on policy:**
1. Review this document first
2. Check per-operation requirements table
3. Consult canonical v3.2 RFC 3161 section
4. Escalate to governance team

---

**This policy is binding for all receipt and evidence operations. Non-compliant timestamps will be rejected by production systems.**
