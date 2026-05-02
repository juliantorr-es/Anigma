# Privacy, Compliance, and Regulated Decisioning Spine

**Status:** Canonical design track, not implemented
**TD:** td-cbe207
**Last reviewed:** 2026-04-19

TD is the source of truth for live task status, blockers, dependency order, and review state. This document is the canonical architecture reference for privacy and regulated-decision constraints on missions, evidence, memory, connectors, and agent actions.

## Purpose

Anigma's mission model must treat privacy and regulated decisioning as runtime boundaries, not documentation-only policies.

The canonical framing is:

```text
Capsules define capabilities.
Missions authorize bounded execution.
Evidence proves what happened.
Privacy constraints define what must never happen.
Regulatory gates decide when a result may affect a person.
```

This design applies to:

- mission descriptors
- payload artifacts
- immutable receipts and evidence chains
- embeddings and binary atlases
- institutional memory and personal context
- connector ingestion
- external model/tool providers
- operator review and verifier lanes

## Non-Goals

- This document is not legal advice.
- This document does not claim current implementation compliance.
- This document does not make every low-risk internal task a regulated mission.
- This document does not replace product-specific counsel review before regulated deployment.

## Core Risk

Immutable evidence is valuable for auditability, but it can become a privacy liability if it contains raw prompts, PII, PHI, secrets, embeddings that reveal source text, customer documents, or regulated decision factors.

Therefore:

- immutable logs must store references and redacted metadata, not raw sensitive payloads
- raw payloads must live in governed, encrypted artifact stores with retention and deletion semantics
- deletion must preserve non-identifying audit facts through tombstones or key destruction
- embeddings and atlases must be treated as sensitive derived data when their source is sensitive

## Mission Privacy Contract

Every mission descriptor that touches user, customer, employee, patient, tenant, applicant, or regulated business data must carry privacy and purpose metadata.

Required descriptor fields:

```text
privacy_class:
  public | internal | confidential | personal | sensitive | regulated

data_subject_scope:
  none | user | customer | employee | child | patient | applicant | tenant | mixed

allowed_purpose:
  search | retrieval | summarization | audit | support | evaluation | training | decision_support | regulated_decision

training_allowed:
  true | false

eval_allowed:
  true | false

retention_class:
  transient | short | audit | legal_hold | subject_to_deletion

redaction_required:
  true | false

export_allowed:
  true | false

jurisdiction:
  US | CA | CO | EU | HIPAA_adjacent | financial | employment | custom

regulated_decision_class:
  none | recommendation_only | decision_support | substantial_factor | automated_decision

human_review_required:
  true | false

appeal_or_review_path:
  none | operator_review | user_appeal | compliance_review
```

These fields are policy inputs. The signing authority must fail closed when required fields are absent for sensitive or regulated data.

## Data Movement Rule

Mission data categories are not interchangeable.

```text
runtime_input
retrieval_memory
evaluation_data
training_data
telemetry
audit_evidence
support_export
regulated_decision_record
```

Moving data from one category to another requires a governed transition with:

- source category
- destination category
- purpose
- actor/principal
- policy decision
- retention effect
- data subject impact
- receipt or tombstone reference

Examples:

- Runtime input must not become training data unless `training_allowed=true` and consent/policy permits it.
- Audit evidence must not contain raw sensitive payloads merely because a run is high assurance.
- Evaluation data derived from customer content must carry provenance, minimization, and deletion propagation rules.

## Privacy-Preserving Evidence

Immutable evidence may include:

- mission ID and descriptor hash
- policy decision ID and reason code
- redacted data class and purpose fields
- payload reference ID
- encrypted payload hash or keyed digest
- output artifact hash
- verifier result hash
- deletion tombstone reference
- legal hold marker

Immutable evidence must not include:

- raw PII, PHI, secrets, credentials, or customer documents
- raw prompt/tool transcripts for sensitive missions
- full embedding vectors when source data is personal or regulated
- direct identifiers when a stable pseudonym or scoped reference is sufficient

The evidence spine proves that governed processing occurred. It is not a dumping ground for the processed data.

## Data Subject Rights

The runtime must support data rights workflows for personal and regulated data:

- access/export
- correction
- deletion
- retention expiry
- processing restriction
- opt-out where applicable
- legal hold
- deletion proof

For immutable ledgers, deletion means:

1. remove or crypto-shred raw payloads and derived payload artifacts where allowed
2. remove or rebuild affected embeddings/atlases when source deletion requires it
3. preserve a non-identifying tombstone that proves the deletion workflow ran
4. prevent deleted payload references from being rehydrated into prompts, evals, or training sets

## Regulated Decision Gate

Missions must classify whether their output can affect a natural person or business in a regulated or consequential context.

Decision classes:

```text
none
recommendation_only
decision_support
substantial_factor
automated_decision
```

Regulated contexts include, at minimum:

- employment or employment opportunities
- education enrollment or opportunities
- financial, lending, credit, or tenant screening
- housing
- insurance
- legal services
- essential government services
- healthcare or PHI-adjacent workflows
- biometrics, voice, face, or child-directed processing

If a mission is `substantial_factor` or `automated_decision`, the runtime must require:

- impact assessment reference
- human oversight assignment
- explanation or reason-code strategy
- appeal or review path
- data provenance and quality statement
- post-deployment monitoring plan
- incident/escalation path

Absent these fields, the signing authority must deny the mission.

## External Providers

Any external model, API, or tool provider that receives non-public data must have a provider record covering:

- allowed data classes
- no-training or training permission terms
- retention and deletion terms
- region and subprocessors
- security baseline
- breach/incident notice path
- audit/export support
- model/provider version identity

Provider terms are part of mission admission. A provider that cannot satisfy the mission privacy contract is not eligible for that mission.

## Verifier Lane Requirements

The privacy verifier lane must fail or warn on:

- raw sensitive payloads in immutable receipts
- missing purpose or privacy class on sensitive missions
- training/eval use without permission
- cross-tenant or cross-project retrieval
- deletion not propagating to embeddings, atlases, memories, or eval data
- regulated decisions without human review or impact assessment references
- external provider use without eligible provider terms
- connector scopes broader than the mission purpose requires

Privacy findings must map into the evaluation matrix as first-class safety/compliance findings, not as advisory notes.

## Regulatory Anchors

These anchors are included so architecture work reserves the right hooks. Current legal interpretation must be verified before regulated deployment.

- California privacy and ADMT rules: CPPA announced final regulations covering cybersecurity audits, risk assessments, and automated decisionmaking technology, with rules effective January 1, 2026 and additional compliance time for some requirements. See https://cppa.ca.gov/announcements/2025/20250923.html.
- Colorado Anti-Discrimination in AI Law: applies to high-risk AI systems used for consequential decisions in specified areas and goes into effect June 30, 2026. See https://coag.gov/ai/.
- EU AI Act high-risk deployer obligations: include human oversight, monitoring, logs, relevant input data, incident handling, information to affected persons, and DPIA alignment where applicable. See https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-26.
- FTC privacy commitments: AI providers must honor privacy/confidentiality promises and avoid undisclosed data reuse for training or other purposes. See https://www.ftc.gov/policy/advocacy-research/tech-at-ftc/2024/01/ai-companies-uphold-your-privacy-confidentiality-commitments.
- NIST AI RMF: use as the baseline risk-management vocabulary for trustworthy AI design, development, use, and evaluation. See https://www.nist.gov/itl/ai-risk-management-framework.

## TD Implementation Track

Canonical TD epic:

- `td-cbe207`: Privacy, Compliance, and Regulated Decisioning Spine

Initial child work:

- `td-71c1ee`: Define mission data classification and purpose limitation contract
- `td-872ee7`: Implement privacy-preserving evidence and deletion semantics
- `td-f4c4aa`: Build regulated decision gate and impact-assessment registry
- `td-ea4f03`: Add privacy verifier lane for mission and memory invariants

Implementation note:

- Canonical mission privacy contract types live in `ContractsCore` and are referenced by mission descriptors and evidence receipts such as `CathedralMission` and `CathedralFusedKernelReceipt`.

Related existing work:

- `td-dd97e2`: Enforce connector least-privilege privacy contract
- `td-623e0d`: Candidate Lane: Censor DSL (Governed Privacy & PII Redaction)
- `td-d5735e`: Enforce connector privacy scopes

## Acceptance Standard

This spine is not implemented until:

- descriptor schemas include privacy, purpose, retention, provider, and regulated-decision fields
- signing/admission gates fail closed for missing privacy metadata
- evidence storage excludes raw sensitive payloads by construction
- deletion workflows handle payloads, derived embeddings, memory, eval data, and tombstones
- regulated-decision missions require assessment, human oversight, explanation, and appeal metadata
- verifier lanes can prove the above in repeatable tests
