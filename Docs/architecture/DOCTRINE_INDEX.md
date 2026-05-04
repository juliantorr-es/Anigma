# Doctrine Index - Canonical Architecture References

**Document ID:** DOCTRINE-INDEX-2026-001  
**Version:** 1.1  
**Status:** ACTIVE  
**Owner:** Architecture Team  

---

## Purpose

This document is the **single source of truth** for which architecture documents are canonical and which are superseded.  

**RULE:** Agents must implement from canonical documents only. Implementing from superseded documents is a P0 architectural violation.

---

## Canonical Documents

### Governance
| Document | Scope | Status | Notes |
|----------|-------|--------|-------|
| [../governance/GIT_COMMIT_AND_REMOTE_DOCTRINE.md](../governance/GIT_COMMIT_AND_REMOTE_DOCTRINE.md) | Git workflow | **CANONICAL** | Required for all commits/pushes. |
| [../governance/TABULAR_DOCUMENTATION_DOCTRINE.md](../governance/TABULAR_DOCUMENTATION_DOCTRINE.md) | Tabular/CSV docs | **CANONICAL** | Standardizes CSV artifact schemas. |
| [../governance/TESTING_DOCTRINE.md](../governance/TESTING_DOCTRINE.md) | Testing philosophy, framework policy, receipts | **CANONICAL** | Defines Swift Testing migration, JSON receipt policy, evidence standards. |
| [../governance/BUILD_TOOLING_DOCTRINE.md](../governance/BUILD_TOOLING_DOCTRINE.md) | Build and compiler evidence, driver/llbuild doctrine | **CANONICAL** | Defines source-grounded build evidence, Swift driver, llbuild, and `anigma doctor` rules. |
| [../governance/WORKTREE_DOCTRINE.md](../governance/WORKTREE_DOCTRINE.md) | Worktree workflow | **CANONICAL** | Standardizes Git worktree usage. |

### Architecture Capabilities (Future)
| Document | Scope | Status | Notes |
|----------|-------|--------|-------|
| [../roadmap/future-capabilities/architecture-operations-capability.md](../roadmap/future-capabilities/architecture-operations-capability.md) | Architecture cockpit, validation lanes, evidence indexes, publishing | **FUTURE** | Roadmap for ArchitectureOperationsCapability. Blocked until anigma-app Debug builds reliably. |

---

## Architectural Diagrams

- **[System Tiering](../diagrams/source/system-tiering.mmd)**: Illustrates the mandatory dependency direction (Tier 3 → Tier 2 → Tier 1) and defines forbidden cyclic dependencies that the package graph audit must enforce.
- **[Governance Control Plane](../diagrams/source/governance-control-plane.mmd)**: Visualizes the flow of documentation and governance: from developer proposal through tool-based validation and registry update to production runtime logs.
- **[Document Artifact Pipeline](../diagrams/source/document-artifact-pipeline.mmd)**: Shows the canonical flow of documentation from Git source to both derived architecture diagrams and the Notion display surface.
