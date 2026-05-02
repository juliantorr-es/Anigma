> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Content-Addressed Artifact Storage (CAS)

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Context:** High-Scale AI Artifact Management

## Executive Summary

Institutional AI generates and consumes massive amounts of unstructured data (PDFs, ML Models, Video, Audit Logs). Research into **Content-Addressed Storage (CAS)** and **OCI Artifacts** suggests that Anigma should move from a path-based file system to a hash-based immutable storage system. This enables global deduplication, cryptographic integrity, and efficient distribution of large assets.

## 1. Industry Standards: OCI Artifacts & IPFS

### OCI (Open Container Initiative)
The industry standard for distributing large immutable artifacts (beyond just containers) is the **OCI Distribution Specification**.
- **Registry-as-CAS**: Tools like Docker and Helm use OCI registries to store "layers" by their SHA-256 hash.
- **Anigma Application**: Models (Llama, Stable Diffusion) should be stored as **OCI Artifacts**, allowing for standard distribution, versioning, and caching.

### Git LFS & IPFS
- **Git LFS**: De facto standard for research teams to track large model weights.
- **IPFS (InterPlanetary File System)**: Used in academic and decentralized research to ensure that datasets are tamper-proof across institutional boundaries.

## 2. Hashing: BLAKE3 vs. SHA-256

The choice of hash algorithm is critical for the **ArtifactAuthority**:
- **SHA-256 (Compliance)**: Required for NIST/FIPS compliance and regulatory audit receipts.
- **BLAKE3 (Performance)**: **Parallelizable**; can hash a 10GB model 10-20x faster than SHA-256 by utilizing all CPU cores.
- **Recommendation**: Use a **Hybrid Approach**. Store internal CAS IDs using **BLAKE3** for speed, but record the **SHA-256** in the final `EvidenceAuthority` receipt for compliance.

## 3. Deduplication for ML Models

Academic research (e.g., *RecD*) shows that model checkpoints and fine-tuned versions often share 90-990f their weights.
- **Block-Level Deduplication**: Achieving 10:1 to 50:1 storage savings by storing unique 4KB-128KB blocks rather than full files.
- **Magnitude-Aware Deduplication**: A 2025/2026 research trend where "Less Significant" weights are deduplicated more aggressively with negligible impact on accuracy.

## 4. CAS and Radical Transparency

CAS provides the "Cryptographic Spine" for Anigma:
- **Immutability**: Once an artifact (e.g., a PDF source) is stored, its ID (Hash) can never change.
- **Provenance Linkage**: An **Inference Receipt** points to the **Source Artifact Hash**, ensuring that the exact data used for a specific AI output is forever verifiable.

## 5. Strategic Recommendation for Anigma

1.  **Global Deduplication**: Implement **Variable-Size Chunking** (Rabin fingerprinting) in the `ArtifactAuthority` to deduplicate model weights and document revisions.
2.  **Tiered Hashing**: Use **BLAKE3** for the "Hot" ingestion path and **SHA-256** for the "Cold" governance path.
3.  **Local-First Cache**: Every institutional node should have a local **CAS Cache** that pulls OCI model layers from a central registry once and shares them across all projects.

## Conclusion

Content-Addressed Storage is the financial and technical key to sustainable institutional AI. By deduplicating artifacts at the block level and utilizing parallel hashing (BLAKE3), Anigma can handle the massive data volumes of modern AI without exponential storage costs.