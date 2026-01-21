# Learning & Reflection Loop

Anigma learns without spooking institutions by separating execution from adaptation.

## Deterministic core, governed learnings

The core stack (AnigmaCore + Harmonia + UI kernel) stays deterministic: same inputs yield same outputs, capability gating always runs, logs record provenance, and UI renderers stay native. The core records every run (inputs, schema version, runId, artifacts, capabilities) but never mutates itself while executing.

Learning happens in a separate reflection layer owned by Harmonia or a dedicated submodule. It consumes ledgered evidence (failure records, user corrections, telemetry aligned to privacy policies) and produces **versioned improvement artifacts**: rule updates, workflow patches, prompt tweaks, UI suggestions, ML models. Each artifact includes:

- Hashes of the inputs and runtime artifacts it touched.
- Classification of the mistake type (renderer failure, workflow failure, capability denial, content-quality issue).
- Explicit provenance (runId, schema version, capability context).
- Tests or validation scripts that prove the change improves the targeted behavior.

## Capability-led reflection

Capability requests form the hooks between execution and learning. The core emits structured events whenever a capability is requested, granted, denied, or compensated for. Reflection loops sample from these events to identify pain points (“replay failure after capability denied,” “user rewrote generated summary,” “secret write policy always fails on this host”) and propose targeted fixes.

These proposals are not auto-applied. They are staged artifacts that go through promotion gates: review, testing, policy approval, and audit logging. Only after passing those gates does an artifact change the governed system (new default, ML ranking model, workflow configuration).

## User signals & privacy-safe telemetry

Learning data arrives through explicit signals, not indiscriminate logging. The system tracks structural telemetry like “action undone within 10 seconds,” “capability denial due to policy,” “correction attached to runId.” Sensitive data stays out of the loop unless users explicitly opt into sharing, and even then it is hashed and scoped. That keeps learning practical without being creepy.

## Research-worthy guardrails

This setup is research-worthy because it fuses deterministic truth with controlled adaptation. Most systems either optimize for learning (and lose control) or optimize for control (and never improve). Anigma’s answer is: deterministic execution + ledgered evidence + a reflection layer that proposes versioned improvements that flow through governed promotion pipelines.

Self-improvement stays trustworthy when you stay painfully explicit about what kind of learning you’re doing:

* Improved defaults (versioned, revertible).
* Better suggestions (optional, ignorable).
* Higher-quality extraction/classification (artifact + eval).
* New capabilities (dangerous; must be capability-gated and reviewed like code).

Core = deterministic execution + ledgered evidence.  
Learning = offline/sidecar analysis + versioned proposals.  
Promotion = governed pipeline, not spontaneous mutation.

Documenting these contracts (schemas, capability events, artifact promotion flow, mistake taxonomy) and gating them via Docs/status-style validators keeps the loop honest. It also lets you explain to auditors “what changed, when, and based on what evidence,” which is the promised value of governance. Call this pattern **Evidence-First Self-Improvement** or **Ledger-Governed Learning** to reinforce that evolution remains auditable and controlled.
