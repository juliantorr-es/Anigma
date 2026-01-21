# Anigma: Overview and Constitution

Anigma is a Swift-based, Entity-Component-System (ECS) driven, job/workflow platform designed for institutional-grade autonomous automation systems. Its core thesis is to deliver local-first, AI-driven solutions for complex document workflows, with strong emphasis on accessibility and governance. (see Docs/Overview.md, Docs/AnigmaConstitution.md)

## Current architecture guidance

1.  **Platform Model** – Anigma is the truth (contracts, engines, artifacts); platforms are replaceable adapters (renderers, inference backends). The Platform Model doc defines the invariants, evidence, and validation gates that make this provable. (see Docs/architecture/platform-model.md)
2.  **UI Kernel** – A schema + reconciler + action runtime that keeps UI semantics, capability gating, and provenance governed while letting renderers render natively on each platform. (see Docs/architecture/ui-kernel.md, Docs/architecture/ui-schema.md)
3.  **Inference Contracts** – Cache artifacts, ModelSpec/RunSpec, reuse gate, and provider landscape docs show how Harmonia enforces governance around local ML/LLM inference so backends remain interchangeable. (see Docs/architecture/inference/overview.md)

## Core Values and Principles

1.  **Single ECS and Job Model**: AnigmaCore is the sole source for ECS primitives (EntityId, Component, System, World) and the Job/Workflow model. No module may define its own ECS framework. (see Docs/AnigmaConstitution.md, ADR/0001-single-ecs-in-anigmacore.md, ADR/0002-job-and-workflow-model.md)
2.  **Clean Boundaries**: A three-layer architecture (App Shells > Domain Modules > AnigmaCore) with strict dependencies prevents infrastructure duplication and circular dependencies. Domain logic stays in modules, UI in app shells, core is generic. (see Docs/AnigmaConstitution.md, ADR/0004-module-boundaries.md)
3.  **Actor-Based Concurrency**: `World` and `Scheduler` are actors for thread-safe management. Systems are stateless and async-safe. (see Docs/AnigmaConstitution.md, Docs/ImplementationRules.md)
4.  **Policy-Driven Governance**: All AI actions are evaluated against predefined policies. The system blocks by default, requires justification, and leaves a forensic trail. (see Docs/concepts/governance-model.md)
5.  **Local-First & Privacy**: Primary operation on user-owned machines, with local ML models. No user data leaves the device without explicit opt-in consent. (see Docs/legal/DATA-GOVERNANCE.md, Docs/architecture/mlx-strategy.md)
6.  **Accessibility-First**: Designed to meet WCAG 2.2 Level AAA standards, integrating Apple's Human Interface Guidelines (HIG). (see Docs/public/atlas/index.html)

## Hard Constraints

*   **No Python, No Node.js at Runtime**: The Anigma repository must not contain Python source files or require Python/Node.js at runtime. Shelling out to Python/Node is prohibited in production code. (see Docs/AnigmaConstitution.md, ADR/0003-no-python-or-node-at-runtime.md)
    *   **JS Exception**: JavaScript/TypeScript is permitted *only* for build-time projects producing static assets (e.g., Monaco editor bundle, admin dashboard). Node is *never* required on deployed machines. (see Docs/AnigmaConstitution.md, ADR/0003-no-python-or-node-at-runtime.md)
*   **Swift Only (Core)**: All runtime logic in the Anigma repo is exclusively Swift code. Permissively-licensed C/C++ libraries and MLX/MLXNN for on-device ML are allowed. (see Docs/AnigmaConstitution.md)
*   **License Allowlist**: Only MIT, Apache 2.0, BSD, ISC, Unlicense/CC0, Zlib licensed dependencies are permitted. AGPL/GPL is prohibited. (see Docs/AnigmaConstitution.md)
*   **ECS as Canonical Architecture**: All modules must conform to AnigmaCore's ECS and Job models. (see ADR/0001-single-ecs-in-anigmacore.md)
*   **Governance via ADRs and Documentation**: Major decisions require Architecture Decision Records (ADRs). `Docs/Roadmap.md` is the single source of truth for development plans. (see Docs/AnigmaConstitution.md)
*   **MLX-First Orientation**: Strong preference for MLX on Apple Silicon for on-device machine learning, avoiding cloud-based services. (see Docs/architecture/mlx-strategy.md)

## How to Think About Anigma in One Page

Anigma is a highly governed, local-first, Swift-based AI platform for institutions. It prioritizes secure, auditable, and accessible automation of complex document and code workflows. It achieves this through a unified ECS architecture, strict module boundaries, and a robust three-layer governance stack. It explicitly avoids runtime dependencies on Python or Node.js to ensure deployability in sensitive environments, relying on Apple Silicon's MLX for on-device intelligence. Every design and implementation choice is driven by principles of control, transparency, and user data privacy.
