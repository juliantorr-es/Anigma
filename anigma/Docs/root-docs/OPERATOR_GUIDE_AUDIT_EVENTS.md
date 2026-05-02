# Operator Guide: Governance Audit Events

## Overview

Anigma Governance enforces policies (Kill Switch, Operating Modes, Write Gate) on all operations. When an operation is denied, a **Policy Violation** event is recorded in the Audit Log.

This guide defines the schema of these events and how to interpret them.

## Event Schema

All governance denials generate an audit event with:
- **Type**: `policy_violation`
- **Module**: `Governance`
- **Description**: `Write blocked: <summary>`

### Guaranteed Metadata Fields

The `metadata` dictionary contains the structured provenance of the denial.

| Field | Description | Example |
|-------|-------------|---------|
| `violation_id` | Unique UUID for this specific denial instance. | `550e8400-e29b-41d4-a716-446655440000` |
| `operation` | The operation that was attempted. | `database_mutation`, `addComponent` |
| `project_id` | The project scope (if applicable). | `project-alpha` or empty string |
| `mode_source` | Source of the effective operating mode. | `global`, `project`, `default` |
| `failed_checks` | Comma-separated list of check IDs that failed. | `operating-mode, kill-switch` |

## Interpreting Failures

### Common Denial Scenarios

| Failed Check ID | Meaning | Remediation |
|-----------------|---------|-------------|
| `operating-mode` | The current mode (`read_only`) prevents this operation. | Change mode to `assistive` or `autopilot`. |
| `kill-switch` | The Kill Switch is active for this scope. | Use `kill-switch show` to see reason, `kill-switch clear` to restore. |
| `embedding-model-mismatch` | Query model differs from stored data model. | Re-index content or switch query model. |
| `scan-limit-exceeded` | Query required scanning more rows than allowed. | Increase `--scan-limit` or optimize query. |

## CLI Debugging

Use the `--explain` flag with write commands to see the full denial payload immediately:

```bash
# Example
harmonia-v2 memo "test" --project-id p1 --explain
```

Output:
```text
🚫 Governance DENIED write
   Reason: Governance violation: operating-mode
   Violation ID: 550e8400-e29b-41d4-a716-446655440000
   Mode Source: project
   Checks: Mode Read Only does not allow writes
```
