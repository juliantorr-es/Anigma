# 01: System Architecture & Tiering: Extensive Detail

## Overview
Anigma adheres to a rigid 3-tier structure to enforce architectural isolation and prevent cross-tier pollution.

## The Tier Hierarchy
- **Tier 1 (Constitutional Layer)**: Defines immutable system state.
  - **Modules**: `AnigmaPrimitives`, `FoundationContracts`, `GovernanceContracts`.
  - **Mechanics**: No external IO, no native library integration, zero dependencies on Tier 2/3.
- **Tier 2 (Substrate Layer)**: Data-plane and execution engine.
  - **Modules**: `MediaCore`, `ExecutionCore`, `GrapheneEngine`.
  - **Mechanics**: Orchestrates hardware resources, GPU/ANE memory residency, and inference tensors.
- **Tier 3 (Feature/Daemon Layer)**: Implementation surface.
  - **Modules**: `AnigmaPipeline`, `DaemonKernel`, `SidecarService`, `AnigmaAppMac`.
  - **Mechanics**: Feature logic, business rules, IPC orchestration, UI presentation.

## Architectural Governance
- **Unidirectional Flow**: Tiers MUST depend downward. Tier 3 -> Tier 2 -> Tier 1.
- **Cycle Prevention**: Circular paths are caught by `validate_no_cycles.py` during pre-flight.
- **God-Module Prohibition**: Umbrella exports (`@_exported`) are banned outside Tier 1 facading.
