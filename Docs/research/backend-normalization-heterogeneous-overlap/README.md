# Backend Normalization vs. Heterogeneous Saturated Architecture

## Overview
This diagnostic research maps the assumptions made during backend/executable consolidation against the heterogeneous saturated architecture doctrine. 

## Research Documents
1. [Assumption Map](assumption-map.md)
2. [Backend Target Classification](backend-target-classification.md)
3. [Executable/Sidecar Map](executable-sidecar-map.md)
4. [Contract/Executor Boundary Map](contract-executor-boundary-map.md)
5. [ECS Dataflow Overlap](ecs-dataflow-overlap.md)
6. [Materialization and Copy Claims](materialization-and-copy-claims.md)
7. [Misalignment Findings](misalignment-findings.md)
8. [Follow-up TD Plan](followup-td-plan.md)

## Status
- **Pre-Diagnostic Snapshot**: Captured in `.build/anigma-graph/`
- **Initial Audit**: 24 errors, 160 warnings.
- **Key Conflict**: Conflation of "readiness" with "buildability" for native sidecars.
