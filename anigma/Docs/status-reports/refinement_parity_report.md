# Refinement Parity Analysis Report

**Date**: 2026-01-11
**Status**: DRAFT
**Context**: Analysis of the Anigma repository to identify modules falling below the "refinement parity" of core infrastructure (`AnigmaCore`, `HarmoniaModule`).

## Executive Summary

The Anigma repository exhibits a robust "Core" (Tier 1 & 2) with strict concurrency, heavy testing, and formal governance contracts. However, the "Periphery" (Tier 3 Capabilities, Native Bridges, and Vertical Adapters) currently lags in refinement.

"Refinement Parity" is defined as:
1.  **Strict Concurrency**: Enabled (Found consistent across `Package.swift`).
2.  **Test Coverage**: Existence of a corresponding `Test` target with meaningful coverage.
3.  **Implementation Quality**: Absence of mock/stub logic in production code, absence of hardcoded system paths.
4.  **Documentation**: Presence of `README.md` and public API documentation.

## Critical Gaps identified

### 1. Ghost Modules (Verticals)
The following modules exist as distinct targets but lack corresponding Test Suites, which is a violation of the high-assurance standard set by `AnigmaCore`:

*   **`AnigmaAgents`**: Core interface for Agentic workflows. Used by `AnigmaAIConsole` but has **ZERO** tests. The `Agent.swift` file is purely protocol definitions with no concrete implementation coverage nearby.
*   **`AnigmaCorporate`** & **`AnigmaEducation`**: Vertical specializations. Likely placeholders or early-stage, but currently "unrefined" code.
    *   *Remediation*: Create `AnigmaAgentsTests` to validate `AgentContext` serialization and `AgentCapability` logic.

### 2. Native Bridge "Hollows"
The "Kit" modules wrapping native/C functionality appear to be in a verified "Stub" state or utilizing mock data rather than real FFI calls.

*   **`DocumentRenderKit`**:
    *   **Finding**: `NativeDocumentRenderer.render` returns hardcoded `Data([0x01, 0x02, 0x03])` (Line 40). It claims to wrap `anigma_renderer_t` but bypasses the actual render call for the result data.
    *   **Risk**: High. The rendering pipeline is effectively a mockup.
    *   *Remediation*: Connect the `outBuf` from C-shim to the Swift `Data` return. Add functional tests with real PDF/Vector assets.
*   **`ContainerKit`**, **`OOXMLKit`**, **`TypographyKit`**:
    *   **Finding**: No corresponding Test targets (`*Tests`) found in `Tests/`.
    *   *Remediation*: Add test harnesses that exercise the C-API interoperability.

### 3. Infrastructure Fragility
Modules that are critical for operations but rely on "Happy Path" assumptions or hardcoded environments.

*   **`AnigmaGeminiBridge`**:
    *   **Finding**: `MCPClient.swift` contains hardcoded search paths (`/usr/local/bin`, `.build/release`) and relies on `ENV` vars. No `Test` target.
    *   **Risk**: Medium. Installation issues on non-standard environments.
    *   *Remediation*: Refactor `mcpBinaryPath` into a configuration struct injected at init. Add unit tests for the JSON-RPC message handling.

### 4. UI/Feature Layers
High-level feature modules often escape backend rigor, but for a "High Assurance" app, this is a gap.

*   **`DataUI`** & **`ExportUI`**:
    *   **Finding**: Complex dependencies (`DataEngine`, `RendererKit`) but no dedicated `DataUITests` target to verify ViewModels or formatting logic.
    *   **Finding**: `AnigmaTUI` exists as a package but appears abandoned (no tests, low file count).
    *   *Remediation*: Introduce ViewModel testing for `DataUI`.

## Action Plan (Priority Order)

1.  **Fix `DocumentRenderKit`**: The hardcoded mock data is a functional lie. This must be the first step for "Parity" if this module is to be considered "Native".
2.  **Test `AnigmaAgents`**: As the backbone of the AI Console, this needs contracts and tests ensuring the strict `Sendable` types behave as expected.
3.  **Harden `AnigmaGeminiBridge`**: Remove hardcoded paths; standard configuration via `gemini.config.json`.
4.  **Audit Vertical Backlogs**: Determine if `AnigmaCorporate`/`AnigmaEducation` are active. If not, archive them. If yes, mandate tests.

## Metrics for Parity

| Module Area | Strictly Concurr. | Tests Exists? | No Mocks? | Docs? |
|-------------|-------------------|---------------|-----------|-------|
| `AnigmaCore` | ✅ | ✅ | ✅ | ✅ |
| `Harmonia` | ✅ | ✅ | ✅ | ✅ |
| `DocumentRenderKit` | ✅ | ❌ | ❌ | ❌ |
| `AnigmaAgents` | ✅ | ❌ | N/A | ❌ |
| `GeminiBridge` | ✅ | ❌ | ⚠️ | ❌ |

**Goal**: Move all Red (❌) marks to Green (✅) by Q2.
