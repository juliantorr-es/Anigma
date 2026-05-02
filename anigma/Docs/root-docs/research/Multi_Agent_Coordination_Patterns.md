> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Multi-Agent Coordination Patterns

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Context:** Agent-to-Agent (A2A) Orchestration

## Executive Summary

As Anigma evolves from single-agent tasks to multi-agent workflows, the coordination pattern becomes the bottleneck for both "Reasoning Quality" and "Token Efficiency." Academic research in 2025 shows a significant resurgence of the **Blackboard Architecture**, particularly when combined with **Model Context Protocol (MCP)** and **Vector Databases**, as it avoids the "Telephone Game" errors inherent in sequential message passing.

## 1. Blackboard vs. Message Passing (2025 Trends)

| Feature | Blackboard Architecture | Message Passing (e.g., AutoGen) |
| :--- | :--- | :--- |
| **Mechanism** | Central shared memory. | Point-to-point messages. |
| **Visibility** | **Global**: Every agent sees all context. | **Local**: Only sees current thread. |
| **Token Cost** | **Low**: Agents pull only relevant data. | **High**: History is passed redundantly. |
| **Complexity** | High (State management). | Low (Reactive). |
| **Best For** | Complex reasoning (e.g., Architecture). | Simple reactive tasks (e.g., Triage). |

## 2. The Resurgence of the "Shared Brain"

The **Blackboard Architecture** is the "North Star" for Anigma's multi-agent coordination:
- **Semantic Memory (MCP)**: The blackboard is not just a text file; it is a **Vector Space** where agents can query for relevant context.
- **Control Unit (The Orchestrator)**: An orchestrator agent (e.g., `HarmoniaConductor`) selects which specialist agent should act based on the "Current State" of the blackboard.
- **Conflict Resolution**: The blackboard acts as the single source of truth, preventing two agents from giving contradictory advice to the user.

## 3. Hybrid Models: Swarm-on-Blackboard

Modern research (e.g., *“LbMAS”*) suggests a hybrid approach:
- **Reactive Swarms**: Use fast **Message Passing** for low-latency, low-stakes coordination (e.g., formatting data).
- **Reasoning Checkpoints**: Swarms periodically "Checkpoint" their progress to a global **Blackboard** for high-level validation by the orchestrator and the user.

## 4. Coordination for Institutional Safety

Institutional environments require that agent interactions be auditable.
- **The Trace Record**: Sequential message passing creates fragmented traces. The Blackboard creates a **Unified History** where the evolution of a "Project Truth" is clearly visible.
- **State-Aware Governance**: The `WriteGate` can evaluate the "Blackboard State" rather than just individual requests, ensuring that the overall project trajectory remains safe.

## 5. Strategic Recommendation for Anigma

1.  **Blackboard-First Coordination**: Implement the **`AgentBlackboard`** as a Redis-backed semantic memory space where agents can share "Working Context."
2.  **Episodic Segmentation**: Use the episodic research to "fold" old blackboard states into long-term memory, keeping the active reasoning space clean and token-efficient.
3.  **Unified Trace**: Ensure that the **Observability Spine** captures the state of the blackboard at each agent "Turn," providing a complete provenance of how a decision was reached.

## Conclusion

Multi-agent coordination is the frontier of agentic AI. By adopting the **Blackboard Architecture** with hybrid reactive swarms, Anigma can provide the reasoning depth of a collaborative human team while maintaining the efficiency and safety of a governed institutional platform.