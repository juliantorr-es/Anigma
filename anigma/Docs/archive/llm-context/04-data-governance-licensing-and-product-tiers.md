# Anigma: Data Governance, Licensing, and Product Tiers

Anigma operates under a nuanced legal and data governance framework, balancing source-availability with commercial rights, and prioritizing user privacy and control over data.

## Licensing: Source-Available, Non-Commercial by Default

*   **License**: `Anigma-SA-NC` (Source-Available Non-Commercial License) (see Docs/legal/ANIGMA-SA-NC-LICENSE.md)
    *   **Nature**: Source-available, non-commercial by default. Not an OSI-approved open source license.
    *   **Granted Rights**: Limited, non-exclusive rights to access, review, build, install, run for personal, educational, research, or other non-commercial purposes. Limited modifications allowed, retaining license/attribution.
    *   **Restrictions**: Prohibits commercial use (revenue-generating, client work, displacing paid tools, SaaS/PaaS, resale, rebranding, bundling) without a separate written commercial agreement with the Licensor.
*   **Layered Licensing Posture**:
    *   This repository: Anigma-SA-NC.
    *   Open Core (future/parallel releases): Select components may be published under a FOSS license (e.g., AGPL). **Crucially, AGPL/GPL-licensed code may exist only in a separate distribution/release line, not as a dependency within this repository.** (feedback from review)
    *   Proprietary "Editions": Prebuilt binaries, integrations, advanced scouts/optimizers, hosted/orchestrator components remain commercial. (see Docs/legal/PRODUCT-TIERS.md)

## Data Governance: Local-First, Governed by Design

*   **Philosophy**: Local-first operation, governance & audit, controlled self-improvement. (see Docs/legal/DATA-GOVERNANCE.md)
*   **Data Categories**:
    *   **Runtime telemetry/logs**: Operational logs, performance metrics.
    *   **Governance traces**: Policy decisions, approvals/denials, tool usage summaries.
    *   **Self-improvement artifacts**: Aggregated stats, distilled patterns, anonymized traces, model deltas. (see Docs/legal/DATA-GOVERNANCE.md)
*   **Data Modes**:
    *   **Shared-learning mode**: Optional opt-in. Anonymized/pseudonymized self-improvement artifacts may be shared with Licensor to improve models. Subject to DPA, anonymization. May offer lower pricing/expanded features.
    *   **Strict-silo mode**: Default for regulated/academic environments. All self-improvement data stays local; no sharing. Typically higher pricing/support. (see Docs/legal/DATA-GOVERNANCE.md)
*   **Consent and Safety**: Sharing is always **opt-in** and requires a separate written agreement (e.g., Training Data Addendum). No PII or protected data may be shared without explicit, informed consent and legal review. Users can revoke sharing prospectively. (see Docs/legal/DATA-GOVERNANCE.md)

## Training Data Addendum (Draft)

*   **Purpose**: Supplements main agreement for sharing of training data. (see Docs/legal/TRAINING-DATA-ADDENDUM-DRAFT.md)
*   **Scope of Shared Artifacts**: Anonymized/pseudonymized traces, governance logs, aggregated stats, de-identified code, model deltas. Excludes PII and protected data without explicit approval.
*   **Licensor Obligations**: Use shared artifacts solely for improving Anigma, implement safeguards to avoid re-identification, comply with law/DPA.
*   **Rights Granted**: Customer grants Licensor non-exclusive, worldwide, royalty-free right to use shared artifacts to improve Anigma.
*   **Revocation**: Customer may revoke future sharing. Licensor not required to un-train existing models unless agreed. (see Docs/legal/TRAINING-DATA-ADDENDUM-DRAFT.md)

## Product Tiers

Anigma offers several tiers, each with specific allowed uses and shared-learning options. "Commercial use" includes any revenue-generating, cost-reducing, or paid service use. (see Docs/legal/PRODUCT-TIERS.md)

*   **Community Edition**: Free, non-commercial. For personal, educational use.
*   **Individual Non-Commercial**: For hobbyists, researchers in non-commercial contexts.
*   **Pro**: For freelancers, small businesses. Limited commercial use specified in agreement.
*   **Enterprise Non-Commercial**: For larger orgs (university, NGO) needing internal non-commercial use. Strict-silo is default.
*   **Commercial / OEM**: For bundling, SaaS/managed service, hosted offering, or large-scale commercial deployment. Requires signed contract.

## What an LLM Must Assume About Data & Licensing

*   **Default Non-Commercial**: Assume default non-commercial use. If asked to facilitate commercial activities, flag as potentially out of scope or requiring a commercial agreement.
*   **Data Privacy Default**: Operate in a strict-silo mode for data, assuming no data sharing with Licensor unless explicitly instructed otherwise with appropriate context of an existing "Shared-learning" agreement.
*   **No PII/Protected Data Sharing**: Absolutely do not handle or suggest sharing Personally Identifiable Information (PII) or protected data categories.
*   **Compliance**: Prioritize adherence to user consent, privacy, and licensing terms in all data-related operations.
*   **Auditability**: Assume all significant actions must be traceable and logged for audit purposes.

## Architectural Enforcement of Licensing Boundaries

The project's licensing and product tier posture is strategically sensible but requires architectural enforcement to prevent confusion and accidental "crossing the streams." (feedback from review)

*   **Mechanical Enforcement**: The boundaries between "source-available non-commercial," "future open core," and "commercial editions" should be mechanically enforced in the repo layout, build flags, and module boundaries.
*   **Build System Integration**: The build system should physically prevent or clearly delineate commercial-only components from non-commercial ones.
*   **Preventing Confusion**: This ensures that contributors, especially those under non-commercial licenses, do not accidentally include or contribute to commercial-only features, reducing the risk of licensing conflicts.
