# Governance and Provenance

Governable systems define invariants, not vague guidelines. This document describes the **capability model**, **policy gates**, **required log fields**, and **failure modes** that keep Anigma accountable.

## Capability model

- Capabilities are explicit grants: read disk, write disk, network access, external service calls, compute-heavy jobs, personal data access, export, policy override, etc.
- Every request for an action includes:
    1. Capability token.
    2. Scope (artifact/job/workflow).
    3. User intent payload (UI node, action label, inputs).
    4. Audit context (renderer ID, trust level, policy mode).
- The engine authorizes requests via policy. If denied, it emits a rejection event with reason codes and guidance the renderer shows. If approved, the engine executes a job, writes DTM deltas, and logs provenance.

## Policy gates and invariants

- Policy gates evaluate trust scores, provenance, workflow risk, and external conditions.
- Example invariants:
    - “Every disk-write action logs capability token + scope + UI node + job ID.”
    - “Accessibility exports block when alt text or reading order invariants fail unless an explicit, logged policy exception is granted.”
    - “Deleted artifacts require explicit governance approval and produce a tamper-evident record.”
- Policy decisions carry metadata: gate name, evaluated inputs, risk score, actor (human or automation), timestamp.

## Provenance requirements

- Every change to the DTM or projection includes:
    - Originating job ID.
    - Input artifact hashes.
    - Triggering UI node or automation rule.
    - Policy evaluation summary.
    - Capability token/scope.
    - Downstream event links (what consumed this change).
- Provenance lives in structured logs and DTM annotations so questions like “why did this output exist?” resolve to receipts instead of vibes.

## Failure and audit modes

- Renderers and jobs must surface failures with policy context (which gate failed, what mitigations exist).
- Critical failures produce incident reports with reproducible steps: DTM versions, job graphs, policy gates, and remediation actions.
- Audit mode runs periodic checks: schema validators, capability counts, policy gate coverage. Results are versioned and stored alongside governance docs.

## Worked example

Input: remediation UI action “Approve alt text fix.”

1. Renderer sends request with action node ID, capability token `write:alt-text`, and DTM/analysis context.
2. Engine evaluates policy gate `alt-text-review`. Trust mode is `strict`, so the action is allowed only after provenance for the selected artifact is verified.
3. Job runs, writes DTM delta, and emits event linking to the renderer request, policy decision, and job ID.
4. Logs now contain the full chain—renderer node, capability, policy evaluation, job, DTM change—so auditors can replay or verify the change.

Fixtures: a sample log record in `Docs/fixtures/governance/remediation-log.json` demonstrates the required fields and JSON shape so CI can validate new actions against the governance schema.
