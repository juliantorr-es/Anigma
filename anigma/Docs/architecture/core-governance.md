# Core Governance Layer: Production-Hardened Substrate

The Core Governance Layer provides the production-hardened, court-safe foundation that ensures security, auditability, and legal defensibility for all Anigma operations.

## Overview

The Core Governance Layer is the **immutable foundation** of Anigma that contains only the essential components needed for production-grade, court-safe operations. It maintains minimal dependencies and provides cryptographic guarantees that survive infrastructure compromise.

## Core Components

### AnigmaCore: ECS Foundation
- **Purpose**: Single source of truth for Entity-Component-System architecture
- **Components**: `World`, `EntityId`, `Component`, `System`, `Scheduler`
- **Features**: Jobs/workflows, audit logging, kill switch, operating modes, write gates
- **Guarantees**: Actor-based concurrency safety, Apple Silicon optimization

### DatabaseCore: Secure Data Access
- **Purpose**: Secure SQLite access with governed data lifecycle
- **Components**: `DatabaseActor`, query interfaces, connection management
- **Features**: Content-addressed storage, retention policies, tamper-evident operations
- **Guarantees**: Type-safe queries, Swift 6 concurrency compliance

### HarmoniaSpine: Governance State
- **Purpose**: Central governance and trust boundary management
- **Components**: Trust boundaries, security events, policy enforcement
- **Features**: Operating modes (read-only/assistive/autopilot), access control
- **Guarantees**: Deterministic state transitions, audit trails

## Court-Safe ML Worker Integration

### Hardware-Backed Security
- **Secure Enclave/TPM signing**: All evidence heads signed with hardware-protected keys
- **Trusted timestamping**: External RFC3161 TSA verification for legal timestamps
- **Canonical serialization**: Cross-platform deterministic byte signing
- **Key custody management**: Hardware-protected private keys with rotation/revocation

### Evidence Generation
```bash
# Generate legal-grade receipt for any query
anigma-receipt explain --agent-id "agent-123" --legal-grade --format pdf

# Create court-ready evidence bundle
anigma-receipt bundle --type legal_discovery --sign --timestamp

# Air-gapped verification by hostile auditors
anigma-verify ./evidence-bundle-20241213/ \
    --strict \
    --trust-anchors ./auditor-certs/ \
    --revocation-list ./revoked-keys.txt \
    --format html \
    --output verification-report.html
```

### Offline Verification
- **Infrastructure independence**: Evidence bundles verifiable without trusting Anigma
- **Cryptographic provenance**: SHA256 verification of all artifacts
- **Legal defensibility**: Court-admissible evidence chains

## Harmonia: The Only Governance Surface

### Deterministic Wrapper
All Core Layer operations MUST use the Harmonia wrapper:

```bash
# ✅ CORRECT: Use deterministic wrappers
Scripts/harmonia.sh <subcommand> [args...]        # CLI operations
Scripts/harmonia-surface.sh [args...]             # Surface testing

# ❌ FORBIDDEN: Never run these directly
swift build
swift test  
swift run
xcodebuild
./.build/.../harmonia*
.tools/bin/harmonia*
```

### Automation Interface
- **Output**: Single JSON envelope on stdout only
- **Diagnostics**: All diagnostic messages on stderr
- **Format**: Always `--format json` unless `HARMONIA_FORMAT=text` is set
- **State**: All governance state queries go through Harmonia

## Security Boundaries

### Process Isolation
- **Resource limits**: CPU, memory, and I/O throttling
- **Sandboxing**: File system and network access restrictions
- **Privilege separation**: Minimal privilege principle for all operations

### Emergency Procedures
```bash
# Emergency key revocation
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# Generate verification bundle for compromised period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-13" \
    --include-revoked-keys
```

## Core Layer Guarantees

### Security Guarantees
- **Cryptographic provenance**: All operations signed and timestamped
- **Hardware attestation**: Evidence heads signed with Secure Enclave/TPM
- **Offline verification**: No dependency on Anigma infrastructure for verification
- **Legal defensibility**: Court-admissible evidence chains

### Operational Guarantees
- **Deterministic behavior**: Same inputs produce same outputs across platforms
- **Audit trails**: Complete, tamper-evident logging of all operations
- **Kill switch**: Immediate termination capability for all operations
- **Retention policies**: Automated data lifecycle management

### Development Guarantees
- **Type safety**: Swift 6 concurrency compliance throughout
- **Testability**: Comprehensive test coverage with mock modes
- **Documentation**: Complete API documentation with examples
- **Backward compatibility**: Stable interfaces with versioning support

## Integration Patterns

### Core Layer Usage
```swift
// ✅ CORRECT: Use AnigmaCore ECS primitives
import AnigmaCore

let world = World()
let entityId = await world.createEntity()
await world.addComponent(entityId, FileComponent(path: "/path/to/file"))

// ✅ CORRECT: Use DatabaseCore for data access
import DatabaseCore

let database = DatabaseActor(path: "/path/to/database.sqlite")
let results = await database.query("SELECT * FROM documents WHERE processed = ?", [false])

// ❌ FORBIDDEN: Direct SQLite C API usage
// ❌ FORBIDDEN: Custom ECS implementations
// ❌ FORBIDDEN: Bypassing Harmonia for governance state
```

### ML Operations
- **Accessum integration**: All ML operations follow runId/ml/stepId/ structure
- **Mock mode**: Use `ML_WORKER_MOCK_MODE=true` for development
- **Backend documentation**: Record which models and binaries are used
- **Evidence generation**: Automatic receipt generation for all operations

## Compliance and Standards

### Legal Compliance
- **Court admissibility**: Evidence chains meet legal evidentiary standards
- **Data governance**: GDPR, CCPA, and institutional privacy compliance
- **Audit requirements**: SOX, HIPAA, and industry-specific audit support
- **Retention policies**: Automated compliance with legal hold requirements

### Technical Standards
- **Cryptographic standards**: FIPS 140-2 compliant algorithms
- **Timestamp standards**: RFC3161 trusted timestamping
- **Serialization standards**: Canonical, deterministic byte formats
- **Concurrency standards**: Swift 6 Sendable and actor compliance

The Core Governance Layer provides the foundation that makes Anigma suitable for institutional deployment where security, auditability, and legal defensibility are non-negotiable requirements.