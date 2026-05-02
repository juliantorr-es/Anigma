# Backend Blind Spots Audit (2026-04-09)

> Historical architecture and delivery snapshot. `td` remains the source of truth for active sequencing, status, and what should be worked on next. If this document disagrees with `td`, trust `td`.

## Summary

The backend is no longer primarily blocked by package consolidation alone.

At this stage, the main risks are the things that usually hurt integrated systems after they start to "mostly build":

- semantic contract drift
- execution-state ambiguity
- overload behavior
- memory and context compaction behavior
- verifier coverage
- operability gaps
- end-to-end truth under long-running conditions

Most of the individual ingredients are already visible in the repo and in `td`, but they are not yet tied together as one final backend-hardening checklist.

## What Is Already Understood Well

The repo already has explicit workstreams for:

- lifecycle hardening
- contracts
- retries and idempotency
- backpressure
- integration tests
- operability surfaces
- logging
- observability
- database consolidation
- personal context memory
- long-run runtime architecture

That is good. The blind spots are not invisible. The risk is that they remain fragmented and never get treated as one integrated backend completion layer.

## Current Blind Spots

## 1. Semantic Integration Is Still More Dangerous Than Build Integration

Even after compile blockers clear, backend modules can still disagree on:

- payload semantics
- retry expectations
- ownership boundaries
- queue lifecycle
- source-of-truth assumptions
- what "completion" means

This is why contract verification is still one of the highest-value tasks left, even if the package graph looks cleaner.

## 2. Execution State Is Not Yet Canonical

The architecture has:

- jobs
- plans
- receipts
- request state
- memory
- queues

But it still lacks one obviously canonical execution-state spine that answers:

- what is running
- what subgoal is active
- what has been compacted
- what branch or retry path the run is on
- what state should be resumed next

This is now a backend concern, not just a long-run agent concern.

## 3. Contextum Still Sits Too Close To The Truth Boundary

The Contextum seam continues to matter because ingestion, retrieval, and personal context all touch core backend behavior.

As long as the database path and user-facing ingestion path are not fully real and canonical, other backend conclusions can be misleading.

## 4. Database Architecture Is Still Part Of Backend Reliability

This is not separate from backend integration anymore.

If database ownership, migration boundaries, or canonical-vs-legacy status remain ambiguous, then:

- runtime behavior stays harder to reason about
- observability stays noisier
- replay and debugging stay weaker
- retention and cleanup become risky

## 5. Backpressure Is Still More Policy Than Reality

The repo has open tasks for backpressure and retries, but the actual danger is this:

when the backend becomes real, overload and duplicate work will replace compile errors as the main failure mode.

Without one unified overload policy, different modules will fail differently and produce confusing symptoms.

## 6. Compaction And Forgetting Are Not Yet Backend Contracts

Compaction is currently discussed more in memory/runtime terms than as a backend-wide operational contract.

The backend still needs clear rules for:

- active-context compaction
- checkpointing before compaction
- derived-state expiration
- memory forgetting
- safe resumption after compaction or cleanup

## 7. Verifier Lanes Are Under-Specified

The architecture has receipts and evidence, but that does not automatically give you:

- stale-memory checks
- resume-safety checks
- retrieval package sufficiency checks
- safe-to-act verification after replans
- branch reconciliation checks

These should become explicit backend capabilities.

## 8. Integration Tests Still Need To Prove Useful Work

The backend still needs a smaller number of stronger tests that prove:

- real binaries start
- real workflows run
- state is persisted or resumed correctly
- degraded behavior is surfaced honestly
- simulated paths are not silently standing in for production behavior

## 9. Operability Still Needs A Practical User Surface

The backend will remain hard to debug until operators can easily answer:

- what is running
- what is blocked
- what is retried
- what queue is backing up
- what was compacted
- what changed
- what failed for a given run or correlation ID

The task exists in `td`, but the architecture should treat this as a core backend completion criterion.

## 10. The Final Risk Is Fragmentation

The biggest backend blind spot now is not one missing module.

It is the risk that:

- build work
- database work
- memory work
- runtime work
- observability work
- operability work

all progress independently without being judged against one final backend readiness checklist.

## Recommended Final Checklist

The backend should not be considered meaningfully integrated until all of the following are true:

- main binaries build and run
- shared contracts are verified across critical seams
- execution state has a canonical owner
- Contextum ingestion/retrieval path is real, not simulated
- database ownership is explicit and migration-safe
- retry and idempotency policy is enforced
- overload/backpressure behavior is explicit
- compaction and resume behavior are defined
- verifier lanes exist for stale or conflicting state
- integration tests prove useful backend work
- operability surfaces answer real debugging questions

## Bottom Line

What you are overlooking in the backend is not another missing module.

You are overlooking the need to treat the remaining work as **one backend hardening program** rather than as many adjacent fixes.

The repo now needs a final consolidation layer that says:

- these are the required backend truths
- these are the canonical owners
- these are the readiness gates
- and these are the things that must be true before the backend can be called genuinely integrated
