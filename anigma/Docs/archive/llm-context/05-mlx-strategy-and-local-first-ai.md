# Anigma: MLX Strategy and Local-First AI

Anigma's core strategy for AI is built around leveraging Apple's MLX framework to enable powerful, local-first intelligence directly on user-owned Apple Silicon machines. This approach prioritizes privacy, security, and institutional control over AI capabilities. (see Docs/architecture/mlx-strategy.md)

## Why MLX and Apple Silicon are Central

*   **Local-First Intelligence**: Shift from cloud-based services to on-device AI tasks. Keeps sensitive information and processing local. (see Docs/architecture/mlx-strategy.md)
*   **Privacy and Security**: All MLX work runs locally on the player device, isolated from file I/O (MLX sees only `DialogueContext`, returns text). No network access is required for dialogue generation, making it compliant in offline or privacy-sensitive environments. (see Docs/Aerodrome9_Demo_Spec.md)
*   **Performance**: MLX provides fast on-device inference pipelines for LLMs, integrated into Swift via mlx-swift and underlying C++ runtime. (see Docs/Aerodrome9_Demo_Spec.md)
*   **Institutional Adoption**: Provides powerful AI without relying on external cloud providers, which aligns with institutional IT preferences (see ADR/0003-no-python-or-node-at-runtime.md) and allows for auditing and ownership. (see Docs/architecture/mlx-strategy.md, Docs/strategy/market-positioning.md)

## Planned MLX Usage Across Anigma

1.  **Diaplasion (Alt-Media Transformation)**: MLX evolves Diaplasion into an intelligence engine. (see Docs/architecture/mlx-strategy.md)
    *   **Semantic Navigation**: Generate per-chunk embeddings for semantic search (e.g., "Jump to where this form talks about appeal deadlines").
    *   **Local Summarization & Simplification**: Small LLMs generate low-reading-level versions, checklists, or risk summaries.
    *   **On-Device Document Q&A**: Local RAG pipeline using `ChunkedTextComponent` entities as context.
    *   **Layout Intelligence**: Vision models classify document regions for structured EPUB/Braille output.
2.  **Audio (Adaptive Intelligence)**: Infuse existing TTS with adaptive intelligence. (see Docs/architecture/mlx-strategy.md)
    *   **Multi-Voice Personas**: Classify tone/speaker to assign different voices.
    *   **Reading-Difficulty-Aware TTS**: Adjust speed/emphasis based on sentence complexity.
    *   **True Streaming & Interactive Reading**: MLX streams content just-in-time.
3.  **Local Dev & Coding Agents (Harmonia)**: Leverage powerful, private, on-device models for development tasks. (see Docs/architecture/mlx-strategy.md)
    *   **Local Code-Context Embedder**: Index entire monorepo for context, eliminating external vector databases.
    *   **"Governed Assistant" Sandbox**: Small local MLX models for low-risk tasks (refactoring, test generation), with governance enforcing "local-first" policy.
    *   **Offline Document Explainer**: Explain complex documents on-device for absolute privacy.
4.  **Governance & Watchdog Models**: Using local AI to govern and validate other AI systems. (see Docs/architecture/mlx-strategy.md)
    *   **Agent Output Rater**: Classify cloud model output for risk assessments (e.g., "Legally Ambiguous").
    *   **Compliance Tagger**: Automatically classify/tag documents (e.g., `Financial`, `Medical`) to enforce policies.
    *   **Accessibility Policy Checker**: Heuristic checks for accessibility issues (e.g., "Image missing alt-text").

## Local-First Reasoning: Security, Privacy, and Institutional Deployment

Anigma's MLX strategy directly addresses institutional needs:
*   **Data Stays Local**: No data leaves the user's device without explicit consent and separate agreements (see Docs/legal/DATA-GOVERNANCE.md). This is critical for PHI, PII, and other sensitive data.
*   **Air-Gapped Operation**: The ability to perform sophisticated AI tasks without network access (e.g., dynamic dialogue in Aerodrome-9 demo) enhances security and privacy. (see Docs/Aerodrome9_Demo_Spec.md)
*   **Institutional Ownership and Auditability**: Organizations can own, audit, and control their AI infrastructure, maintaining a complete forensic log of all AI decisions. (see Docs/architecture/mlx-strategy.md, Docs/strategy/market-positioning.md)
*   **Clustered MLX Across a Mac Mini Swarm**: Architecture designed to scale across private clusters of Apple Silicon machines, creating a private, air-gapped inference fleet managed by Anigma's governance. (see Docs/architecture/mlx-strategy.md)

## If you are an AI agent proposing ML architecture, stay within these constraints:

*   **Prioritize Local-First**: Solutions must default to on-device MLX on Apple Silicon.
*   **Avoid Cloud Dependencies**: Propose cloud models only when explicitly permitted by governance policies and for tasks that cannot be performed locally, with a clear justification.
*   **Ensure Governance & Auditability**: Every ML interaction must be capability-gated, logged, and auditable (input/output hashes, model version, policy decision). (see Docs/roadmap_foundational_desktop_ux.md)
*   **Respect Privacy**: Design for strict data silos and anonymization where applicable. Never propose sharing PII or protected data without explicit user consent.
*   **Adhere to Licensing**: Use open-weights models with clear, permissively-licensed terms. (see Docs/roadmap_foundational_desktop_ux.md)
*   **Budget & Performance**: MLX dialogue generation must run asynchronously and respect a budget per turn (token cap, hard timeout). (see Docs/Aerodrome9_Demo_Spec.md)
