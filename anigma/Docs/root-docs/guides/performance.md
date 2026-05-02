# Saturated Performance & Regression Guardrails

## Status: 🔄 RENOVATION IN PROGRESS
Integrating **Wall Elimination** and **Saturated Baselines** into the performance guide.

## Overview
Anigma’s performance philosophy is built on **Hardware Saturation**. We don't just aim for "fast"; we aim for the **Theoretical Peak** of the Apple Silicon unified memory architecture. This guide defines how we measure saturation and how we use **Regression Guardrails** to prevent architectural "Walls" from creeping back into the codebase.

---

## 1. The Saturated Performance Profile

Every feature in Anigma must be evaluated against the **Six Architectural Walls**.

| Wall | Saturated Standard | Target Metric |
| :--- | :--- | :--- |
| **Coordination** | Fused Megakernels | <100μs CPU-GPU Sync Tax |
| **Serialization** | Binary Atlases (SoA) | **Zero** transformation cycles |
| **Governance** | Pre-Signed Missions | No real-time CPU policy checks |
| **Evidence** | In-Kernel SIMD-Blake3 | <2% execution overhead |
| **I/O** | Predictive Pre-fetching | Match SSD Peak Throughput |
| **Scheduling** | Shared-Memory Queues | <50μs Mission Dispatch Latency |

---

## 2. Regression Guardrails (Saturation Gating)

We use the `RegressionGuardrails.swift` system to enforce these standards in CI/CD.

### A. The Coordination Guardrail
**Check**: Detects synchronous waits (e.g., `waitUntilCompleted()`) in any DSL execution path.
- **Strict Mode**: Fails if any synchronous wait exceeds 50μs.

### B. The Serialization Guardrail
**Check**: Detects AoS (Array of Structures) layouts in high-throughput components.
- **Strict Mode**: Fails if a `[Float]` is stored directly in a component instead of a `SaturatedEmbeddingComponent` (Atlas Pointer).

### C. The Evidence Guardrail
**Check**: Verifies that a mission generates **In-Kernel Heartbeats**.
- **Strict Mode**: Fails if a GPU mission completes without writing a valid SIMD-Blake3 hash to the Saturated Logging Ring.

---

## 3. Measuring Saturation

To verify if a feature is truly "Saturated," use the following benchmarks:

### Semantic Search (Accessum)
- **Baseline**: 1,000,000 documents searched and ranked in **<10ms**.
- **Saturation**: >90% GPU Compute Unit occupancy.

### LLM Inference (Harmonia)
- **Baseline**: **>45 tokens/sec** (llama-3-8b-instruct) on M2 Max.
- **Efficiency**: **>1.87 tokens per Joule** (Lucebox standard).

---

## 4. Performance Tuning Workflow

1. **Identify the Wall**: Use the `TelemetryCore` traces to find where the hardware is starving (bubbles in the Metal debugger).
2. **Fuse the Kernel**: If the wall is **Coordination**, fuse the discrete kernels into a single **Megakernel**.
3. **Unzip the Data**: If the wall is **Serialization**, migrate the data to a **Binary Atlas (SoA)**.
4. **Pre-Sign the Mission**: If the wall is **Governance**, move the policy evaluation to the pre-launch phase.

---

**In Anigma, performance is not a feature—it is the architectural foundation.**
