# Core Governance Layer: Deep Dive

This document provides detailed technical guidance for working with Anigma's Core Governance Layer - the production-hardened, court-safe substrate.

## 1. Core Layer Components and Responsibilities

### 1.1 AnigmaCore: The ECS Foundation

**Primary Responsibilities:**
- Entity-Component-System implementation (`World`, `EntityId`, `Component`, `System`)
- Job/Workflow/Scheduler model for asynchronous processing
- Shared components (`FileComponent`, `QAComponent`, `MetadataComponent`)
- Actor-based concurrency for thread safety

**Key Invariants:**
- `World` is the ONLY entity management system
- All components must conform to `Component` protocol
- All systems must be stateless and async-safe
- No module may define its own ECS framework

### 1.2 DatabaseCore: Secure Data Access

**Primary Responsibilities:**
- Thread-safe SQLite access via `DatabaseActor`
- SQL injection prevention through parameterized queries
- Connection pooling and resource management
- Transaction safety and rollback capabilities

**Security Requirements:**
- All database access must go through `DatabaseActor`
- Never use raw SQLite C API directly
- Always use parameterized queries for user input
- Implement proper error handling for database operations

### 1.3 HarmoniaSpine: Governance State Management

**Primary Responsibilities:**
- Trust boundary enforcement
- Security event logging and auditing
- Operating mode management (read-only/assistive/autopilot)
- Kill switch and write gate implementation

**Critical Security Functions:**
- Hardware-backed key management
- Trusted timestamping with external TSA
- Evidence head signing and verification
- Emergency key revocation procedures

## 2. Harmonia: The Sole Governance Interface

### 2.1 Deterministic Wrapper Usage

**ALWAYS use the wrapper:**
```bash
# ✅ CORRECT: Deterministic wrapper
Anigma/Scripts/harmonia.sh <subcommand> [args...]

# The wrapper ensures:
# - Binary exists and is up-to-date
# - --format json unless HARMONIA_FORMAT=text is set
# - Proper error handling and logging
# - Single JSON envelope output
```

**NEVER use direct paths:**
```bash
# ❌ FORBIDDEN: Direct binary execution
./.build/release/harmonia
.tools/bin/harmonia
swift run harmonia

# ❌ FORBIDDEN: Direct build commands
swift build
swift test
xcodebuild
```

### 2.2 Output Format Requirements

**JSON Envelope Structure:**
```json
{
  "status": "ok|error",
  "timestamp": "2025-12-15T10:30:00Z",
  "command": "trust bounds",
  "payload": {
    // Command-specific data
  }
}
```

**Output Rules:**
- stdout: Single JSON envelope only
- stderr: All diagnostic messages
- No mixed output formats
- Consistent error handling

### 2.3 Core Commands and Their Security Implications

**Trust and Security Commands:**
```bash
# Query trust boundaries
Anigma/Scripts/harmonia.sh trust bounds

# Check security status
Anigma/Scripts/harmonia.sh security status

# Verify system integrity
Anigma/Scripts/harmonia.sh verify integrity

# List active policies
Anigma/Scripts/harmonia.sh policies list
```

**Governance State Commands:**
```bash
# Get current operating mode
Anigma/Scripts/harmonia.sh mode status

# Set operating mode (requires elevated privileges)
Anigma/Scripts/harmonia.sh mode set autopilot

# Check write gate status
Anigma/Scripts/harmonia.sh write-gate status

# Emergency kill switch
Anigma/Scripts/harmonia.sh emergency stop
```

## 3. Court-Safe ML Integration

### 3.1 Evidence Generation Pipeline

**ML Operation Flow:**
1. **Request**: Agent initiates ML operation through Harmonia
2. **Validation**: Harmonia validates against governance policies
3. **Execution**: ML worker processes request with hardware backing
4. **Signing**: Results signed with Secure Enclave/TPM keys
5. **Timestamping**: External RFC3161 TSA verification
6. **Storage**: Evidence stored in Accessum ledger
7. **Verification**: Offline verification capability maintained

**Evidence Structure:**
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
    "model_spec": {...},
    "run_spec": {...}
  },
  "content": {
    // Actual ML output
  }
}
```

### 3.2 Hardware-Backed Security

**Key Management:**
- Private keys stored in Secure Enclave/TPM
- Key rotation and revocation procedures
- Hardware attestation for device verification
- Emergency key destruction capabilities

**Canonical Serialization:**
- Cross-platform deterministic byte signing
- SHA256 hash verification for all artifacts
- Bitwise identical reproduction guarantees
- Platform-independent verification

### 3.3 Offline Verification

**Air-Gapped Verification Process:**
```bash
# Create verification bundle
anigma-receipt bundle --type legal_discovery --sign --timestamp

# Verify without trusting infrastructure
anigma-verify ./evidence-bundle-20241215/ \
    --strict \
    --trust-anchors ./auditor-certs/ \
    --revocation-list ./revoked-keys.txt \
    --format html \
    --output verification-report.html
```

**Verification Bundle Contents:**
- All evidence heads with signatures
- TSA tokens for timestamp verification
- Model and binary hashes
- Trust anchor certificates
- Revocation lists
- Verification software

## 4. Emergency Security Procedures

### 4.1 Key Compromise Response

**Immediate Actions:**
```bash
# Emergency key revocation
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# Generate verification bundle for compromised period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-15" \
    --include-revoked-keys
```

**Post-Incident Actions:**
1. Rotate all affected keys
2. Generate new trust anchors
3. Update all verification bundles
4. Audit all evidence generated during compromise period
5. Update revocation lists

### 4.2 System Integrity Failures

**Detection and Response:**
```bash
# Check system integrity
Anigma/Scripts/harmonia.sh verify integrity

# If integrity check fails:
Anigma/Scripts/harmonia.sh emergency stop
# Investigate and restore from known-good state
```

**Integrity Verification:**
- Binary hash verification
- Model integrity checking
- Configuration consistency
- Database integrity checks

## 5. Development and Testing Guidelines

### 5.1 Core Layer Development

**Development Environment:**
```bash
# Use mock mode for development without security requirements
export ML_WORKER_MOCK_MODE=true

# Test with mock hardware keys
export ANIGMA_MOCK_HARDWARE_KEYS=true
```

**Testing Requirements:**
- All cryptographic operations must be testable with mock keys
- Hardware operations must have software fallbacks for CI
- Evidence generation must be deterministic in test mode
- All security procedures must be testable

### 5.2 Security Testing

**Test Categories:**
- Cryptographic operation testing
- Hardware key management testing
- Evidence generation and verification
- Emergency procedure testing
- Offline verification testing

**Test Data Requirements:**
- Use test-only certificates and keys
- Mock TSA responses for testing
- Deterministic test data for reproducible tests
- Isolated test databases

## 6. Integration Patterns

### 6.1 Accessum Integration

**ML Operation Structure:**
```
runId/
├── ml/
│   ├── stepId/
│   │   ├── input/
│   │   ├── output/
│   │   ├── evidence/
│   │   └── metadata/
│   └── ...
└── ...
```

**Required Metadata:**
- Agent identification
- Model specification
- Run configuration
- Input/output hashes
- Timing information
- Resource usage

### 6.2 Capability Module Integration

**Contract Requirements:**
- All ML operations must go through Harmonia
- Evidence generation is mandatory for all operations
- Governance policies must be respected
- Audit trails must be maintained

**Integration Points:**
- Harmonia CLI for governance operations
- Accessum for evidence storage
- DatabaseCore for secure data access
- AnigmaCore for ECS operations

## 7. Monitoring and Observability

### 7.1 Security Metrics

**Key Metrics:**
- Evidence generation rate and success
- Key operation latency and success
- TSA verification success rate
- Integrity check results
- Policy violation counts

### 7.2 Performance Monitoring

**Critical Operations:**
- Evidence generation latency
- Cryptographic operation performance
- Database query performance
- Harmonia command execution time

## 8. Compliance and Audit Requirements

### 8.1 Audit Trail Requirements

**Mandatory Logging:**
- All evidence generation events
- Key management operations
- Policy changes and violations
- Security incidents and responses
- System integrity checks

### 8.2 Legal Discovery Support

**Discovery Capabilities:**
- Time-based evidence extraction
- Agent-specific activity reports
- Policy compliance reports
- Security incident timelines
- System state snapshots

The Core Governance Layer maintains the highest security and governance standards, providing a cryptographically auditable foundation that survives infrastructure compromise and supports legal defensibility.