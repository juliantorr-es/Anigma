# Anigma Module Maturity Matrix

**Date**: 2026-01-11
**Version**: 1.0

## 1. Maturity Model Definitions

We define **Maturity** based on the presence of rigorous engineering artifacts required for a "High Assurance" local-first AI system.

*   **Level 5 (Golden) 🏆**:
    *   **Tests**: Full Test Suite in `Tests/`.
    *   **Docs**: `README.md` present explaining the module.
    *   **Concurrency**: Strict Concurrency checks enabled (Global standard).
*   **Level 4 (Silver) 🥈**:
    *   **Tests**: Present.
    *   **Docs**: **Missing**.
*   **Level 3 (Bronze) 🥉**:
    *   **Tests**: **Missing**.
    *   **Docs**: **Missing**.
    *   **Code**: Implementation exists (> 0 swift files).
*   **Level 1 (Paper/Ghost) 👻**:
    *   **Code**: Minimal (< 3 files) or Placeholder only.
    *   **Tests/Docs**: Missing.

---

## 2. Module Analysis (By Layer)

### Tier 1 & 2: Core Infrastructure (High Maturity)

The foundation of Anigma is largely **Golden**, adhering to strict governance.

| Module | Status | Tests? | Docs? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `AnigmaCore` | 🏆 L5 | ✅ | ✅ | The bedrock. Full coverage. |
| `AnigmaPrimitives` | 🏆 L5 | ✅ | ✅ | Crypto/Hash primitives. |
| `DatabaseCore` | 🏆 L5 | ✅ | ✅ | SQLite/GRDB wrapper. |
| `ContractsCore` | 🏆 L5 | ✅ | ✅ | Job/Task definitions. |
| `ExecutionCore` | 🏆 L5 | ✅ | ✅ | Job runners. |
| `TelemetryCore` | 🏆 L5 | ✅ | ✅ | Logging/Tracing. |
| `CapabilityCore` | 🏆 L5 | ✅ | ✅ | Plugin system. |
| `GovernanceCore` | 🏆 L5 | ⚠️ | ✅ | **Tests imply integrated governance tests elsewhere?** (Verify) |
| `StorageCore` | 🏆 L5 | ✅ | ✅ | Artifact storage. |
| `DoctrineCore` | 🏆 L5 | ✅ | ✅ | Policy engine. |

### Tier 3: AI Capabilities (Mixed Maturity)

The active AI modules are well-maintained, but newer agents/console features are lagging.

| Module | Status | Tests? | Docs? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `HarmoniaModule` | 🏆 L5 | ✅ | ✅ | The Coding Agent (Prime feature). |
| `DiaplasionModule` | 🏆 L5 | ✅ | ✅ | Context/Memory. |
| `AccessumModule` | 🏆 L5 | ✅ | ✅ | Resource Access. |
| `PolytroposModule` | 🏆 L5 | ✅ | ✅ | Routing. |
| `PraxisCore` | 🏆 L5 | ✅ | ✅ | Reasoning. |
| `AnigmaAgents` | 🥉 L3 | ❌ | ❌ | **Critical Gap**. Agent interfaces used by Console. |
| `AnigmaAIConsole` | 🥉 L3 | ❌ | ❌ | **Critical Gap**. The UI for Agents. |
| `CodexModule` | 🥈 L4 | ✅ | ❌ | Knowledge graph. Needs README. |
| `ConexusModule` | 🥈 L4 | ✅ | ❌ | Integrations. Needs README. |

### Native & Bridge Layer (Low Maturity)

This layer claims high-performance C-interop but is currently largely scaffolding.

| Module | Status | Tests? | Docs? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `AnigmaGeminiBridge`| 🥉 L3 | ❌ | ❌ | Hardcoded paths. Fragile. |
| `DocumentRenderKit` | 🥉 L3 | ❌ | ❌ | **Mock Data Detected**. Not real rendering. |
| `ContainerKit` | 🥉 L3 | ❌ | ❌ | No tests for container format. |
| `OOXMLKit` | 🥉 L3 | ❌ | ❌ | No tests for Office/Word parsing. |
| `TypographyKit` | 🥉 L3 | ❌ | ❌ | Font handling. |
| `VectorOpsKit` | 🥉 L3 | ❌ | ❌ | Vector math. |

### Domain Verticals (High Risk)

These modules are substantial (~2600 LOC) but completely untested, representing a significant quality risk.

| Module | Status | Tests? | Docs? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `AnigmaCorporate` | 🥉 L3 | ❌ | ❌ | **High Risk**. 15+ Connectors (Jira, Salesforce), 0 Tests. |
| `AnigmaEducation` | 🥉 L3 | ❌ | ❌ | LTI/OneRoster adapters. Untested. |
| `AnigmaWork` | 🥉 L3 | ❌ | ❌ | Workflow logic, untested. |

### Core Infrastructure (Correction)

| Module | Status | Tests? | Docs? | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `GovernanceCore` | 🥉 L3 | ❌ | ✅ | **Critical**. Policy Core has NO dedicated tests found. |

## 3. Recommended Remediation Order

To bring the "Rest of the Repo" to **Refinement Parity** with Tier 1:

1.  **Elevate `AnigmaGeminiBridge` (L3 -> L4)**:
    *   Add `AnigmaGeminiBridgeTests`.
    *   Verify arbitrary binary path execution.
    *   *Why*: Agent stability depends on this bridge.

2.  **Elevate `DocumentRenderKit` (L3 -> L4)**:
    *   Remove hardcoded mocks.
    *   Add `DocumentRenderKitTests` with a sample PDF/SVG.
    *   *Why*: "Native" claims are currently unproven.

3.  **Elevate `AnigmaAgents` (L3 -> L4)**:
    *   Add `AnigmaAgentsTests` to verify `AgentContext` and `Capability` serialization.
    *   *Why*: This is the shared type library for all future agents.

4.  **Backfill Documentation (L4 -> L5)**:
    *   Add `README.md` to `CodexModule`, `ConexusModule`, `AnigmaAppMac`.

## 4. Metrics Summary

*   **Golden Modules**: 25+
*   **Silver Modules**: ~5
*   **Bronze Modules**: ~15 (Mostly Native/UI)
*   **Ghost Modules**: ~3

**Conclusion**: The Core is healthy. The "Edge" (UI, Bridges, Native) is brittle.
