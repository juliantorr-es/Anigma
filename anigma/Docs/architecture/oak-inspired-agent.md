# OAK-Inspired Agent Model

OAK is an agent architecture built from two principles: **options** (multi-step policies) and **knowledge** (learned transition models over those options). Anigma adopts the same idea but with governance baked in.

## What OAK means for Anigma/Harmonia

| OAK term | Anigma equivalent |
|----------|------------------|
| Perception | Deterministic state builders (session, job, tool, failure, trust) sourced from ledgered artifacts. Explicit, versioned features that the core records. |
| Option | A governed macro (job/workflow/tool) with name, termination rule, capability contract, and invariant logging. |
| Option model | Predictive layer over options (cost, time, failure probability, artifact diffs, trust impact). |
| Planning | Higher-level policy/scheduler that selects options based on state and their predicted models, with capability gating enforced by Harmonia. |

## Evidence-first learning

Anigma avoids on-the-fly mutation: the core stays deterministic and records everything. Harmonia-side reflection loops generate proposals (rule updates, workflow tweaks, new options, ML suggestion models) that remain versioned artifacts with hashes, diffs, tests, and provenance. Promotion is governed; nothing writes itself live.

Learning falls into four buckets:

1. Better defaults (versioned, rollback-safe).
2. Better suggestions (optional, ignorable).
3. Better extraction/classification (artifact + evaluation).
4. New capabilities (gated and reviewed like code).

## Play safely

Exploration runs on fixtures, synthetic tasks, or mirrored repos. It produces candidate options, capability tweaks, and metadata features, then emits ledger-backed proposals detailing what happened, why it matters, and what invariants changed.

## Reward as operational utility

The scalar reward becomes a utility score derived from logged signals (completion, invariant violations, user pain). The policy still tracks multiple metrics internally but uses a single combined score for planning.

## Governance payoff

This model keeps “learning” from spiraling into mysterious behavior. Every capability request, option approval, or suggestion is auditable via the ledger. Document it, gate it with Docs/status validators, and call it something like **Ledger-Governed Learning** or **Evidence-First Self-Improvement** so reviewers know it’s no longer wishful thinking.
