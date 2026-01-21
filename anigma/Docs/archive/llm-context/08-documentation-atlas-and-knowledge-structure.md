# Anigma: Documentation, Atlas, and Knowledge Structure

The Anigma project maintains a comprehensive and well-structured documentation system designed for clarity, maintainability, and accessibility, catering to various audiences and learning styles.

## Documentation Structure

The Anigma project maintains a comprehensive and well-structured documentation system designed for clarity, maintainability, and accessibility, catering to various audiences and learning styles. The goal is to ensure every major concept has exactly one canonical definition, with other documents linking to it.

*   **`ADR/`**: **Architecture Decision Records**. Records significant architectural decisions and their rationale, including alternatives considered and consequences. (see Docs/ADR/0000-template.md)
*   **`architecture/`**: High-level summaries of key architectural aspects, such as the governance machine and MLX strategy. (see Docs/architecture/governance_summary.md)
*   **`Atlas/`**: Contains the source (`anigma-atlas.md`) and generated output (`anigma-atlas.html`) for the interactive Anigma Atlas.
*   **`concepts/`**: Explanations of fundamental concepts like Entity-Component-System (ECS) and the Governance Model. (see Docs/concepts/ecs.md)
*   **`guide/`**: Practical guides for setting up and running the Anigma ecosystem (e.g., `getting-started.md`).
*   **`legacy/`**: Archive of superseded documentation from original project repositories, for historical reference only. (see Docs/legacy/README.md)
*   **`legal/`**: Documents covering licensing, data governance, product tiers, and training data agreements.
*   **`public/`**: Contains deployed assets for the documentation site, including the accessible `atlas/index.html`.
*   **`releases/`**: Release notes for specific project versions.
*   **`strategy/`**: Documents outlining market positioning and strategic goals.
*   **Top-level `.md` files**: Provide overarching context and specific guidelines (e.g., `AnigmaConstitution.md`, `Roadmap.md`, `ImplementationRules.md`, `LLM-Guidelines.md`, `TechDebt.md`).

## The Atlasum Visual Atlas Engine

**Atlasum** is the engine that generates the "Anigma Atlas," an interactive mind map providing a spatial and interactive representation of the platform's complex structure. (see ADR/0006-atlasum-visual-atlas-engine.md)

*   **Source**: The atlas is defined in `anigma-atlas.md` using Markmap-compatible Markdown. (see Docs/Atlas/anigma-atlas.md)
*   **Output**: A self-contained, interactive HTML file (`anigma-atlas.html`) that uses Markmap for rendering. This file is then deployed as `Docs/public/atlas/index.html`. (see Docs/Atlas/anigma-atlas.html, Docs/public/atlas/index.html)
*   **Purpose**: Serves as a visual navigation aid for understanding the platform structure, linking to actual documentation for deeper exploration. It is *not* a source of truth; text documentation remains authoritative. (see ADR/0006-atlasum-visual-atlas-engine.md)
*   **Accessibility**: Includes features like skip links, keyboard navigation, and high contrast/color scheme support.
*   **Integration**: Designed with JavaScript hooks for future embedding into the Ergasterion IDE via WKWebView.

## The "Legacy" Strategy

The `Anigma/Docs/legacy/` directory is an archive of documents from original project repositories (Harmonia, Apertum Accessum, Outlineum, AltMedia Engine) that have been superseded by canonical Anigma documentation. (see Docs/legacy/README.md)

*   **Purpose**: To preserve historical context, algorithm references, and design considerations from past projects.
*   **Rule: "Do not copy; extract insights"**: Developers are encouraged to study patterns, learn algorithms, and extract requirements from legacy code, but *must not* copy code directly or translate line-by-line. Re-implementation in fresh Swift, fitting the AnigmaCore model, is required. (see Docs/legacy/README.md)
*   **Status**: These documents are ARCHIVED and no longer authoritative.

## Guidance: Where to Look First in the Docs

*   **For High-Level Principles / Core Values**: `Docs/AnigmaConstitution.md`, `Docs/Overview.md`
*   **For Core Development Plan / Milestones**: `Docs/Roadmap.md`
*   **For Practical Coding Rules / Best Practices**: `Docs/ImplementationRules.md`
*   **For Understanding AI Governance / Agent Behavior**: `Docs/LLM-Guidelines.md`, `Docs/concepts/governance-model.md`, `Docs/workflow-anigma-first.md`
*   **For Architectural Decisions / Rationale**: `Docs/ADR/`
*   **For Technical Debt / Incomplete Features**: `Docs/TechDebt.md`
*   **For AI Integration Strategy (MLX)**: `Docs/architecture/mlx-strategy.md`
*   **For Market / Business Strategy**: `Docs/strategy/market-positioning.md`, `Docs/legal/PRODUCT-TIERS.md`
*   **For Legal / Data Privacy Terms**: `Docs/legal/` folder (e.g., `DATA-GOVERNANCE.md`, `ANIGMA-SA-NC-LICENSE.md`)
*   **For Visual Exploration of Architecture**: `Docs/Atlas/anigma-atlas.html` (or `Docs/public/atlas/index.html`)
*   **For Swift 6 Migration Specifics**: `Docs/Swift6Migration_Pipeline_Status.md`

## Canonical Definitions and Linking

The documentation structure is clean, but the next step is ensuring every major concept has exactly one canonical definition. All other mentions should link back to this authoritative source. This prevents conceptual drift and maintains a "single entry path" for understanding core ideas. (feedback from review)
