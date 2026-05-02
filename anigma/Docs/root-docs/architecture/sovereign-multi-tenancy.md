# Sovereign Multi-Tenancy: Portable Evidence Atlases

## Status: 🏗️ STRATEGIC DRAFT
Defining the **Portable Personal Atlas** and **Gated Institutional Projections**.

## Overview
Anigma’s architecture supports **Sovereign Multi-Tenancy**, where the individual (student, employee, patient) owns their data and evidence, but the organization governs the "Context" and "Access Boundaries." Users can join an organization, process complex media (Video/Photo/Audio), and share their progress without compromising their personal sovereign data. When they leave, they take their **Personal Atlas** with them, leaving behind only the **Institutional Evidence Receipts**.

---

## 1. The Sovereign Storage Model

| Component | Owner | Storage Tier | Portability |
| :--- | :--- | :--- | :--- |
| **Personal Atlas** | Individual | Hot (Binary) | **Full** (Travels with User) |
| **Personal Evidence** | Individual | Warm (Relational) | **Full** (Travels with User) |
| **Institutional Context** | Organization | Hot/Warm | **None** (Stays with Org) |
| **Mission Receipts** | Both | Warm (Spine) | **Shared** (Immutable Proof) |

---

## 2. Gated Projections: Processing & Sharing

To process media and share progress without leaking raw personal data, Anigma uses **Gated Atlas Projections**.

### A. Local Saturated Processing (The "Hot" Sandbox)
A user processes a private video (e.g., a medical scan or a personal project).
1.  **Ingestion**: The **Diaplasion DSL** processes the video locally into a **Personal Atlas**.
2.  **Privacy**: The raw video and its high-res embeddings never leave the user's "Hot" storage tier.

### B. The "Progress Heartbeat" (The "Warm" Share)
The user wants to share "Progress" with a peer or organization.
1.  **Evidence Generation**: The user's Anigma generates a **SIMD-Blake3 Heartbeat** of the processing mission.
2.  **Gated Projection**: The user's Tier 2 runtime creates a **Filtered Projection Atlas**—a tiny, low-resolution subset of the data (or just the metadata) specifically pre-signed for the organization.
3.  **The Proof**: The organization sees that "90% of the video is processed and compliant" via the heartbeats, but they cannot see the raw pixels of the "Personal" frames.

---

## 3. Joining & Leaving an Organization

### A. Joining: The Treaty Handshake
1.  **Trust Link**: The User’s Anigma and the Org’s Anigma exchange **Root Identity Receipts**.
2.  **Atlas Mounting**: The Org’s **Institutional Atlas** is mounted as a "Read-Only Warm Layer" on the user's device via the `DSLMemoryBridge`.
3.  **Policy Sync**: The User’s Tier 1 logic now includes an "Institutional Module" that enforces the Org’s `WriteGate` rules for Org-owned projects.

### B. Leaving: The Graceful Decoupling
1.  **Unmounting**: The Institutional Atlas is unmounted and the local cache is purged.
2.  **Evidence Finalization**: A final **Multi-Instance Receipt** is signed by both parties, proving the user fulfilled their duties.
3.  **Sovereign Retention**: The user keeps their **Personal Atlas** (all their work, embeddings, and personal evidence) but no longer has access to the Org's private context.

---

## 4. Multi-Tenant DSL Scenarios

### 1. The Medical Resident (Video/Photo)
Processes 1,000 patient photos. The raw photos are stored in the Resident's **Sovereign Vault**. The Hospital's Anigma receives a **Saturated Audit Spine** proving every photo was correctly redacted and analyzed. If the Resident leaves the Hospital, they keep their "Learning Atlas" (the insights) but the Hospital keeps the "Compliance Spine."

### 2. The Creative Student (Audio/Video)
Edits a film project. The "Hot" render data stays on their MacBook. They share "Progress Heartbeats" with their professor. The Professor can see the **Composition Metadata** and the **Evidence of Work**, but doesn't need to host the gigabytes of raw 4K footage.

---

## 5. Implementation Requirements (Nexus Lane)
- **Feature: Portable Identity Receipts**: Tier 1 must support "Detachable Identity" modules.
- **Feature: Atlas Filtering DSL**: A specialized kernel to create "Low-Res/Filtered Projections" of a Hot Atlas for sharing.
- **Feature: Receipt Handover**: A protocol for signing "End-of-Tenancy" evidence spines.
