# Governed Workflow Guide

## Overview

Anigma implements a governed patch system that transforms "make changes and hope for the best" into "prove every change and track all side effects." This guide explains how to use the governed workflow from agent action to final commit.

## Core Principles

1. **Evidence is Mandatory Input** - All operations must go through evidence enforcement
2. **Ledger-First Durability** - Record intent before making changes
3. **Cryptographic Integrity** - All steps are linked by hash chain
4. **Human Oversight Gates** - Certain operations require explicit approval

## Workflow Phases

### Phase 1: Inspection

**Purpose**: Analyze repository and create change proposal.

```bash
# Inspect repository state
harmonia inspect-repo \
  --session-id <uuid> \
  --output-format json \
  --output-dir ./inspection-artifacts

# Creates: inspection-report.json, evidence-chain.json, snapshot.json
```

**Outputs**:
- `inspection-report.json` - Human-readable repository analysis
- `evidence-chain.json` - Complete evidence of inspection process
- `snapshot.json` - Content-addressed repository snapshot

**Evidence Created**:
- Hardware-backed signature of inspection results
- RFC3161 timestamp for temporal authenticity
- BLAKE3(JCS) content digests for integrity

### Phase 2: Generation

**Purpose**: Create a minimal patch based on inspection findings.

```bash
# Generate change proposal
harmonia generate-patch \
  --session-id <uuid> \
  --report ./inspection-report.json \
  --snapshot ./snapshot.json \
  --output-dir ./proposal-artifacts

# Creates: proposal.json, generation-receipt.json, evidence-update.json
```

**Key Options**:
- `--acceptance-refs` - Required criteria references
- `--risk-notes` - Risk assessment notes
- `--phase-id` - Which development phase this belongs to

**Validation**:
- Proposal must reference inspection receipt
- Must include acceptance criteria
- Risk notes required for high-risk changes

### Phase 3: Validation

**Purpose**: Validate patch against comprehensive governance gates.

```bash
# Validate patch artifact
harmonia validate-patch \
  --session-id <uuid> \
  --artifact ./proposal-artifacts/proposal.json \
  --validation-pack fast \
  --output-dir ./validation-artifacts

# Creates: validation-report.json, validation-receipt.json, updated-evidence.json
```

**Validation Packs**:
- `fast` - Quick checks (syntax, boundaries, type authority)
- `full` - Comprehensive checks (Swift 6, security, dependencies, escape hatches)

**Required Gates**:
- Swift 6 strict concurrency compliance
- Type authority boundaries (no duplicate definitions)
- Dependency insulation (Core vs Capability modules)
- Escape hatch expiry checks
- Macro expansion safety

**Failure Modes**:
- **Rejected** - Patch fails validation, must return to Phase 1
- **Needs Human Review** - Automated validation passes but requires human judgment
- **Quarantined** - Patch flagged for security review

### Phase 4: Approval

**Purpose**: Explicit human approval of validated patches.

```bash
# Approve patch for merge
harmonia approve-patch \
  --session-id <uuid> \
  --artifact ./validation-artifacts/proposal.json \
  --approver <human-identity> \
  --justification <approval-justification> \
  --output-dir ./approval-artifacts

# Creates: approval-receipt.json, updated-evidence.json
```

**Approval Requirements**:
- All validation packs must have passed
- Risk assessment must be documented
- Approver identity must be recorded
- Justification must reference acceptance criteria

### Phase 5: Merge

**Purpose**: Apply approved patch to repository with full evidence tracking.

```bash
# Merge patch to repository
harmonia apply-patch \
  --session-id <uuid> \
  --artifact ./approval-artifacts/proposal.json \
  --dry-run false \
  --output-dir ./merge-artifacts

# Creates: merge-receipt.json, rollback-info.json, final-evidence.json
```

**Rollback Support**:
- If merge fails, rollback information is generated
- Rollback complexity is assessed (trivial/simple/moderate/complex)
- Original state can be restored

### Phase 6: Reporting

**Purpose**: Generate comprehensive human-facing reports.

```bash
# Generate analyst report
harmonia generate-report \
  --session-id <uuid> \
  --artifact ./merge-artifacts/proposal.json \
  --format html \
  --output-dir ./reports

# Creates: analyst-report.html, bundle.json
```

**Report Contents**:
- Complete receipt chain from all phases
- Risk assessment and mitigation strategies
- Rollback complexity analysis
- Evidence references for audit verification

## Evidence Chain Integrity

Every phase creates a receipt that references:
- **Previous receipt hash** - Cryptographic link to prior step
- **Artifact hashes** - Content addressing of all created files
- **Evidence attachments** - Supporting documentation and analysis
- **Hardware signatures** - Cryptographic proof of authority

## Session Management

Sessions provide isolation between different agents working on the same repository:

```bash
# Start new session
harmonia session start --session-id <uuid>

# Merge session to master
harmonia session merge --session-id <uuid> --into master

# End session
harmonia session end --session-id <uuid> --delete-db
```

**Session Database Features**:
- SQLite database with same schema as master ledger
- Automatic merge via `ATTACH DATABASE`
- Optional persistence for long-running workflows

## Integration with Existing Tools

The governed workflow integrates with existing Anigma tools:

### Git Operations
- `inspect-repo` uses `git status`, `git log`, `git diff`
- `apply-patch` uses `git apply` with rollback support

### Build System
- `validate-patch` can invoke `swift build` and `swift test`
- Evidence includes build logs and test results

### Code Analysis
- `inspect-repo` parses Swift files for type authority violations
- AST-based analysis for security patterns

## Error Handling

### Common Error Scenarios

1. **Validation Failure**
   ```bash
   if harmonia validate-patch --validation-pack fast; then
     echo "Validation failed - fix issues and retry"
     exit 1
   fi
   ```

2. **Merge Conflict**
   ```bash
   if ! harmonia apply-patch --dry-run true; then
     echo "Resolve conflicts and retry"
     exit 1
   fi
   ```

3. **Insufficient Evidence**
   ```bash
   if ! harmonia validate-patch --evidence-level moderate; then
     echo "Insufficient evidence - gather more data"
     exit 1
   fi
   ```

## Security Considerations

### Hardware-Backed Signing
- Uses Secure Enclave/TPM for private key storage
- Signatures included in every receipt
- Public verification via `anigma-verify` tool

### Isolation
- Session databases are isolated from master
- Tool router prevents filesystem access outside approved paths
- Evidence chain prevents tampering across sessions

## Best Practices

1. **Always Use Session IDs** - Provides traceability across operations
2. **Preserve All Artifacts** - Never delete intermediate files
3. **Document Rationale** - Include justification in approval phases
4. **Test Rollbacks** - Verify rollback procedures before production
5. **Monitor Evidence Levels** - Ensure sufficient evidence for operation type

## Troubleshooting

### Common Issues and Solutions

| Issue | Symptom | Solution |
|--------|-----------|----------|
| Receipt chain broken | "Evidence validation failed" | Re-run from last known good state |
| Type authority violation | "Duplicate symbol found" | Check for imported modules or type conflicts |
| Insufficient evidence | "Evidence level too low" | Add more inspection data or lower risk |
| Merge conflict | "Patch does not apply cleanly" | Use `git merge-tool` or resolve manually |

## Integration Examples

### Example 1: Simple Bug Fix
```bash
# Complete workflow for single-file change
harmonia session start --session-id $(uuidgen)
harmonia inspect-repo --session-id $SESSION_ID
harmonia generate-patch --session-id $SESSION_ID --phase-id bugfix
harmonia validate-patch --session-id $SESSION_ID --validation-pack full
harmonia approve-patch --session-id $SESSION_ID --approver "dev-lead@example.com"
harmonia apply-patch --session-id $SESSION_ID
harmonia generate-report --session-id $SESSION_ID --format text
harmonia session end --session-id $SESSION_ID
```

### Example 2: Feature Development
```bash
# Multi-phase workflow for new capability
SESSION_ID=$(uuidgen)

# Phase 1: Analysis
harmonia inspect-repo --session-id $SESSION_ID --deep-analysis
harmonia generate-patch --session-id $SESSION_ID --phase-id feature-x --risk-notes "New capability adds external dependency"

# Phase 2: Validation
harmonia validate-patch --session-id $SESSION_ID --validation-pack full --security-scan

# Phase 3: Approval
harmonia approve-patch --session-id $SESSION_ID --approver "security-team@example.com" --justification "Security review passed, dependency approved"

# Phase 4: Implementation
harmonia apply-patch --session-id $SESSION_ID
harmonia validate-patch --session-id $SESSION_ID --validation-pack integration

# Phase 5: Reporting
harmonia generate-report --session-id $SESSION_ID --format html --include-build-artifacts
harmonia session end --session-id $SESSION_ID --merge-to master
```

---

This guide ensures every change is: **INSPECTED → PROPOSED → VALIDATED → APPROVED → APPLIED → RECORDED** with complete cryptographic evidence at each step.