# Governed Workflow Guide

## Overview

Anigma implements a governed patch system based on **receipt-based validation** and **phase contracts**. This guide explains the current toolchain for making governed changes to the repository.

> **Note**: This document describes the current governed toolchain. For the old CLI interface, see [archive/governed-workflow-guide-old.md](archive/governed-workflow-guide-old.md).

## Core Principles

1. **Receipt Chain Integrity** - All operations create receipts that link to previous steps
2. **Phase Contract Enforcement** - Changes must reference phase IDs and acceptance criteria
3. **Wrapper Script Usage** - Never use `swift build`, `swift test`, or `xcodebuild` directly
4. **Evidence-Based Validation** - All changes require cryptographic evidence

## Build and Validation Commands

**Always use the Harmonia wrapper script:**

```bash
# Build with Swift 6 strict concurrency checks
Scripts/harmonia.sh swift6

# Run security validation
Scripts/harmonia.sh security

# Run trust/evidence validation
Scripts/harmonia.sh trust
```

**Never use these commands directly:**
- ❌ `swift build`
- ❌ `swift test`
- ❌ `xcodebuild`
- ❌ `swift run harmonia ...`
- ❌ `./.build/.../harmonia*`

## Governed Patch Workflow

### 1. Check Repository State

Before generating any patches, ensure the repository is clean:

```bash
repo_clean_check
```

This verifies:
- You're on the `main` branch
- Submodules are clean
- Working tree doesn't touch forbidden paths

### 2. Generate Patch

Create a patch for your proposed changes:

```bash
generate_patch --description "Fix: Update documentation for governance compliance" \
               --files "README.md,Docs/guide/getting-started.md"
```

### 3. Propose Patch

Propose the patch with phase ID and acceptance criteria:

```bash
propose_patch --patch-hash <hash-from-generate> \
              --phase-id "docs-governance-update" \
              --acceptance-refs "Docs/governance/phases/documentation.md"
```

**Required fields:**
- `--phase-id`: Which phase this change belongs to
- `--acceptance-refs`: Path to acceptance criteria document

### 4. Validate Patch

Run validation gates before applying:

```bash
validate_patch --patch-hash <hash-from-propose>
```

The plugin will:
- Check receipt chain integrity
- Verify phase contract compliance
- Run security gates
- Validate type authority boundaries

### 5. Apply Patch

If validation passes, apply the patch:

```bash
apply_patch --patch-hash <hash-from-validate>
```

### 6. Commit Changes (Integrator Only)

Only the Integrator agent can commit:

```bash
commit_changes --message "docs: Update for governance compliance" \
               --receipt-hash <hash-from-apply>
```

## Error Recovery

### Validation Failure

If `validate_patch` fails:

```bash
diagnose_patch_failure --patch-hash <failed-hash>
```

This will:
- Read receipts and stored patch
- Explain the failure
- Suggest the next tool to use

### Apply Failure

If `apply_patch` fails:

```bash
# Quarantine the patch
quarantine_patch --patch-hash <failed-hash>

# Or rollback the last apply
rollback_last_apply
```

## Tool Reference

For detailed tool documentation, see:
- [agent_tools.md](../governance/agent_tools.md) - Complete tool reference with receipts and `nextTool` hints
- [AGENTS.md](../../AGENTS.md) - Governance rules and wrapper script requirements
- [Docs/governance/phases/](../governance/phases/) - Phase contracts and acceptance criteria

## Phase Contracts

Every patch must reference a phase contract that defines:
- **Authority boundary**: What modules/files can be modified
- **Surface API**: Public interfaces affected
- **Concurrency model**: Actor isolation requirements
- **Stop conditions**: When the phase is complete
- **Acceptance tests**: How to verify success
- **Migration plan**: Rollback and compatibility strategy

## Best Practices

1. **Always use `repo_clean_check` first** - Prevents working on dirty state
2. **Reference phase contracts** - Every proposal needs `--phase-id` and `--acceptance-refs`
3. **Run validation before apply** - Catch issues early
4. **Use `diagnose_patch_failure`** - Get actionable guidance on failures
5. **Preserve receipts** - Never delete `.opencode/ledger/` files
6. **Follow wrapper script rules** - Use `Scripts/harmonia.sh` for all builds

## Workflow Example

```bash
# 1. Check repo state
repo_clean_check

# 2. Generate patch for documentation updates
generate_patch --description "Update docs for governance compliance" \
               --files "README.md,Docs/guide/getting-started.md"

# 3. Propose with phase reference
propose_patch --patch-hash abc123... \
              --phase-id "docs-governance-update" \
              --acceptance-refs "Docs/governance/phases/documentation.md"

# 4. Validate
validate_patch --patch-hash def456...

# 5. Apply if validation passes
apply_patch --patch-hash def456...

# 6. Commit (Integrator only)
commit_changes --message "docs: Align with AGENTS.md governance rules" \
               --receipt-hash ghi789...
```

---

**This workflow ensures every change is: INSPECTED → PROPOSED → VALIDATED → APPLIED → RECORDED** with complete cryptographic evidence at each step.
