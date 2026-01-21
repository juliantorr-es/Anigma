# Native Dependency Intake System

> **Production-ready CLI workflow for governed native dependency management**
>
> This system implements the complete intake decision record workflow for native library dependencies in Anigma, ensuring proper governance before any implementation begins.

## Overview

The Native Dependency Intake System provides a production-hardened CLI workflow that:

1. **Enforces Governance**: Requires complete Intake Decision Records (IDR) before implementation
2. **Tracks Status**: Maintains registry of all native dependencies with status tracking
3. **Validates Completeness**: Ensures decision framework is fully completed
4. **Prevents Ad-hoc**: Blocks direct native dependency additions without proper process

## CLI Commands

### `harmonia native intake <library-name>`

Creates a new Intake Decision Record for a native library.

```bash
# Create IDR for libgit2
harmonia native intake libgit2

# Create IDR with specific author
harmonia native intake libgit2 --author "John Doe"
```

**What it does:**
- Creates IDR-{library}.md from the decision framework template
- Pre-fills metadata (created date, author, etc.)
- Adds entry to NativeDependencies.toml registry as PENDING_IDR
- Prevents duplicate IDR creation
- Provides next steps guidance

**Output:**
```
🚀 Creating Intake Decision Record for: libgit2
✅ Intake Decision Record created: Docs/governance/native-deps/intake/IDR-libgit2.md

📋 Next Steps:
1. Complete the decision framework in Docs/governance/native-deps/intake/IDR-libgit2.md
2. Submit for security, legal, and architecture review
3. Await approval before any implementation

📊 Current Status: PENDING_IDR
📝 Registry Entry: Docs/governance/native-deps/registry/NativeDependencies.toml
```

### `harmonia native status <library-name>`

Shows the current status of a native library dependency.

```bash
harmonia native status libgit2
```

**What it shows:**
- Registry status and metadata
- IDR file existence and status
- Contract artifact status
- Risk, business, and compliance scores
- License and category information

**Output:**
```
📊 Native Dependency Status: libgit2
==================================
Registry Status: PENDING_IDR
Category: VersionControl
License: GPLv2 with linking exception
Risk Score: 4
Business Score: 8
Compliance Score: 8
IDR File: EXISTS
IDR Status: DRAFT
Contract: NOT_FOUND
```

### `harmonia native validate <library-name>`

Validates that the intake decision process is complete and ready for approval.

```bash
harmonia native validate libgit2
```

**What it validates:**
- IDR file exists with all required sections
- Decision framework is complete (Business Case, Security Risk, Compliance, Recommendation)
- All checklist items are completed
- Registry entry exists
- Optional: Contract artifact exists

**Output:**
```
🔍 Validating Native Dependency: libgit2
======================================
✅ IDR file exists
✅ Required decision framework sections complete
✅ All checklist items completed
✅ Registry entry exists

📊 Validation Summary:
  Errors: 0
  Warnings: 0
✅ Validation passed - Ready for approval
```

### `harmonia native list`

Lists all native dependencies in the registry.

```bash
harmonia native list
```

**Output:**
```
📋 Native Dependencies Registry
=============================
SQLite
libgit2
example-pending
```

## File Structure

### Intake Decision Records
```
Docs/governance/native-deps/intake/
├── IDR-TEMPLATE.md          # Template for new IDRs
├── IDR-libgit2.md          # libgit2 decision record
├── IDR-SQLITE.md           # SQLite decision record
└── IDR-{library}.md        # Other library records
```

### Registry
```
Docs/governance/native-deps/registry/
└── NativeDependencies.toml   # TOML registry with metadata
```

## Workflow Process

### Phase 1: Intake
1. **Create IDR**: `harmonia native intake <library>`
2. **Complete Framework**: Fill all sections in the IDR file
3. **Decision Analysis**: Score business case, security risk, compliance
4. **Submit for Review**: Send to security, legal, and architecture teams

### Phase 2: Review
1. **Security Review**: Threat model and mitigation assessment
2. **Legal Review**: License compatibility and compliance check
3. **Architecture Review**: Integration strategy and boundary definition
4. **Final Approval**: Sign-off from all required approvers

### Phase 3: Implementation
1. **Create Contract**: Generate NATIVE.{library}.md in contract-artifacts
2. **Implement**: Add native surface and Swift wrapper
3. **Test**: Comprehensive test suite including security validation
4. **Update Registry**: Change status from PENDING_IDR to APPROVED

### Phase 4: Operations
1. **Monitoring**: Enable vulnerability scanning and compliance monitoring
2. **Updates**: Managed version updates through governed process
3. **Audits**: Regular security and compliance audits

## Decision Framework

The IDR template enforces completion of all required sections:

### Required Scores (1-10 scale)
- **Business Case Score**: Necessity and value assessment
- **Security Risk Score**: Threat level and mitigation effectiveness  
- **Compliance Score**: License and legal compatibility

### Approval Workflow
- **Author**: Initiates the IDR and completes business case
- **Security Review**: Assesses threat model and mitigations
- **Legal Review**: Validates license compatibility
- **Architecture Review**: Confirms integration strategy
- **Final Approval**: Senior architect or governance board

### Governance Hooks
The system generates receipts for governance tracking:
- **NativeDepIntake**: IDR creation and metadata
- **NativeDepUpdate**: Version updates and changes
- **VulnerabilityDetected**: Security findings
- **ComplianceViolation**: Governance issues

## Integration with Existing Systems

### Contract Artifacts
IDRs reference existing contract artifacts:
- Links to `NATIVE.{library}.md` in `contract-artifacts/NativeDeps/`
- Maintains authority boundary definitions
- Preserves API contract requirements

### Native Library Lifecycle
Follows the four-phase lifecycle defined in `NATIVE-LIBRARY-LIFECYCLE.md`:
- Phase 1: Intake Assessment (enforced by IDR)
- Phase 2: Implementation Planning (contract artifacts)
- Phase 3: Validation Requirements (testing framework)
- Phase 4: Operational Governance (long-term management)

### Dependency Boundary Policy
Enforces the boundary policy:
- Clear native surface ownership
- Defined Swift wrapper boundaries
- Restricted call site access
- Sandboxing requirements

## Security and Compliance

### License Checking
Validates license compatibility with Anigma-SA-NC:
- MIT, BSD, Apache 2.0: ✅ Compatible
- GPL, LGPL: ⚠️ Requires linking exception analysis
- Proprietary: ❌ Generally incompatible

### Risk Assessment
Standardized risk scoring:
- **Low (1-3)**: System libraries, well-audited code
- **Medium (4-6)**: Network access, file system access
- **High (7-10)**: Parsing untrusted data, privileged operations

### Distribution Models
Supports all approved linking models:
- **systemLibrary**: System-provided libraries
- **vendored**: Full source in repository
- **custom**: Managed build process
- **binary**: Verified pre-compiled artifacts

## Troubleshooting

### Common Issues

**"Template file not found"**
Ensure `Docs/governance/native-deps/intake/IDR-TEMPLATE.md` exists

**"Registry file not found"**  
Ensure `Docs/governance/native-deps/registry/NativeDependencies.toml` exists

**"Intake Decision Record already exists"**
Use `harmonia native status <library>` to view existing IDR
Complete existing IDR instead of creating duplicate

**Validation fails with missing sections**
Ensure all required sections are completed in the IDR:
- Business Case Score: X/10
- Security Risk Score: X/10  
- Compliance Score: X/10
- Overall Recommendation: APPROVED/REJECTED

### Getting Help

```bash
# Show native command help
harmonia native
# Usage: harmonia native <subcommand>
# Subcommands:
#   intake <library-name>        Create Intake Decision Record
#   status <library-name>         Show dependency status
#   validate <library-name>       Validate intake decision
#   list                        List all dependencies
```

## Migration Path

For existing native dependencies without proper IDRs:

1. **Retroactive IDR**: Create IDR for existing dependency
2. **Assessment**: Complete decision framework based on current state
3. **Validation**: Use `harmonia native validate` to check completeness
4. **Registry Update**: Ensure proper registry entry exists
5. **Contract Creation**: Add missing contract artifacts

This ensures all native dependencies follow the same governance process going forward.
