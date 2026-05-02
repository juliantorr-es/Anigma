# Anigma Constitution: Saturated Autonomy

> Last updated: 2026-04-16

This document defines the fundamental principles governing the Anigma platform. It establishes **Saturated Autonomy** as the primary architectural and operational model for institutional AI. Changes to this Constitution require a Saturated ADR.

---

## 1. The Anigma Identity: Saturated Autonomy

**Anigma** is a hardware-first, institutional-grade AI platform built for **Theoretical Peak Performance** on Apple Silicon. It operates as an autonomous **Mission Engine**, designed to eliminate the six systemic walls (Coordination, Serialization, Governance, Evidence, I/O, and Scheduling) that starve high-performance execution.

- **AnigmaCore** is the **Decoupled Saturation Lane (DSL)** spine: Saturated mission descriptors, hardware-native evidence (SIMD-Blake3), and binary atlases (SoA).
- **The Three-Tier Architecture** (ADR-0006) defines the strict isolation and trust model:
  - **Tier 1 (Governance)**: Proactive logic, pre-signed mission signing, constitutional treaties.
  - **Tier 2 (Platform)**: Executive branch, mission dispatch (Saturated Command Queue), atlas mapping (DSLMemoryBridge).
  - **Tier 3 (Capabilities)**: Saturated extensions, autonomous hardware missions, federated evidence.

---

## 2. Core Architectural Pillars

### 2.1 The Saturated Mission Model
Anigma executes AI operations as autonomous **Hardware Missions**.
- **Mechanism**: Fused Megakernels and Persistent State.
- **Enforcement**: Missions operate within **Pre-Signed Mission Descriptors** issued by Tier 1.
- **Proof**: All missions must generate **In-Kernel Heartbeats (SIMD-Blake3)** for high-assurance evidence.

### 2.2 Binary Atlas & SoA Standard
High-throughput data must follow the **Structure of Arrays (SoA)** standard to eliminate the **Serialization Wall**.
- **The Hot Tier**: Heavy data (vectors, tensors, media) is stored in **Binary Atlases (.atlas)**.
- **Zero-Copy**: Data flows from Disk to GPU/ANE registers via memory-mapped projections (mmap) with zero CPU cycles.

### 2.3 Governed Autonomy
We prioritize proactive, pre-signed governance over real-time, CPU-bound checks.
- **Principle**: The hardware (DSL) is the primary executor; the CPU (Tier 2) is the mission orchestrator.
- **The Kill Bit**: All DSLs must monitor a shared-memory **Hardware KillBit** for instant emergency termination.

### 2.4 Privacy-Bound Autonomy
Privacy and regulated-decision constraints are part of mission authority, not post-hoc documentation.
- **Purpose Binding**: Mission descriptors must carry data class, allowed purpose, retention, training/eval permission, jurisdiction, and regulated-decision classification when they touch personal, sensitive, or regulated data.
- **Evidence Minimization**: Immutable evidence proves what happened using descriptor hashes, redacted metadata, and governed payload references; raw sensitive payloads must not be written directly into immutable logs.
- **Regulated Decisions**: Missions whose outputs can substantially affect a person in employment, education, finance, housing, insurance, legal, government-service, healthcare, biometric, child-directed, or similar contexts require impact assessment, human oversight, explanation, and appeal metadata before publication.

---

## 3. Sovereign Multi-Tenancy

Anigma is a platform for **Sovereign Individuals** operating within **Institutional Contexts**.
- **Sovereignty**: Users own their **Personal Portable Atlases** and take them with them when they leave an organization.
- **Nexus Sync**: Instances coordinate via **Federated Evidence Spines**, syncing hardware heartbeats and pre-signed missions with sub-millisecond latency.
- **Treaties**: Cross-instance interactions are governed by **Pre-Signed Multi-Instance Treaties**.

---

## 4. Language and Runtime Constraints

### 4.1 Swift and Metal (Core)
The Anigma repo contains **Swift (Tier 2/3)** and **Metal/C++ (DSL)** for all runtime logic.
- **Strict Concurrency**: All Swift code must conform to Swift 6 strict concurrency rules.
- **Metal Fusion**: All high-performance compute must be implemented as fused **Megakernels**.

### 4.2 No Python, No Node at Runtime
The following are **permanently prohibited** in the Anigma repo:
- Python source files (Runtime dependency, deployment complexity).
- Node.js runtime requirements.
- AGPL/GPL-licensed code (Institutional license incompatibility).

---

## 5. Lab vs Production

### 5.1 Lab Repositories
External repositories are **lab/R&D** artifacts. They may contain Python, experimental code, or legacy "Coordination-Bound" patterns.

### 5.2 Using Lab Code
The rule is: **"Interpret and re-design for Saturation," not "copy and adapt."**
- Extract requirements and algorithms.
- Re-implement as fused, saturated missions in the AnigmaCore model.

---

## 6. Visualization & Atlas Maintenance

**Anigma Atlas** (`Docs/Atlas/anigma-atlas.html`) is the interactive visual representation of the Saturated Platform.
- It must accurately reflect the Saturated Baseline and the DSL lanes.
- Built at development time using static asset generation.

---

**Anigma Constitution: Performance is our Law. Sovereignty is our Goal. Saturation is our Method.**
