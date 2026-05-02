# Long-Run Agent Architecture Audit (2026-04-09)

> Historical architecture snapshot. `td` remains the source of truth for active sequencing and blocker status. If this document disagrees with `td`, trust `td`.

## Summary

The current architecture has more of the right ingredients for long-running agents than a typical agent stack:

- governed runtime entrypoint
- evidence and receipt infrastructure
- personal context and provenance primitives
- job queues and request lifecycle tracking
- planning systems that already care about evidence and workflow boundaries

But it still lacks one crucial layer:

**a unified, persistent execution-state spine for long-horizon runs.**

That matters because the latest research on long-running agents increasingly converges on the same pattern:

- keep working context small and actively managed
- persist durable memory outside the active context
- represent execution state explicitly
- hierarchically organize long-horizon tasks around subgoals or plan trees
- preserve enough ground truth to recover from compaction, drift, and replan events

## External Research Signals

The following sources were used to shape this audit:

- *HiAgent: Hierarchical Working Memory Management for Solving Long-Horizon Agent Tasks with Large Language Model* ([arXiv, August 18, 2024](https://arxiv.org/abs/2408.09559))
- *LongMem: Augmenting Language Models with Long-Term Memory* ([arXiv, June 12, 2023](https://arxiv.org/abs/2306.07174))
- *MemGPT* ([arXiv, 2023](https://arxiv.org/abs/2310.08560))
- *MemMachine: A Ground-Truth-Preserving Memory System for Personalized AI Agents* ([arXiv, April 6, 2026](https://arxiv.org/abs/2604.04853))
- Anthropic's *Managing context on the Claude Developer Platform* ([September 29, 2025](https://claude.com/blog/context-management))
- Anthropic memory docs ([current docs](https://code.claude.com/docs/en/memory))
- OpenAI's Responses API computer-use and compaction announcement ([OpenAI, 2026](https://openai.com/index/equip-responses-api-computer-environment/))
- OpenAI and AWS stateful runtime announcement ([OpenAI, 2026](https://openai.com/index/introducing-the-stateful-runtime-environment-for-agents-in-amazon-bedrock/))

The main recurring findings from those sources are:

- hierarchical working memory beats flat transcript stuffing on long-horizon tasks
- memory and context management improve real long-run agent performance materially
- episodic ground truth should not be aggressively collapsed at ingest time
- execution state and task continuity are separate from long-term memory

## Current Repo Strengths

### 1. There is a runtime-centric architecture

[`PlatformRuntime.swift`](/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaCore/Sources/AnigmaCore/Runtime/PlatformRuntime.swift) is already positioned as the single integration layer for workflow execution, state mutation, and evidence recording.

That is good architecture.

### 2. There is already evidence-oriented planning

[`PlanCompiler.swift`](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/HarmoniaModule/Planning/PlanCompiler.swift) explicitly models plans as evidence-backed and governance-sensitive rather than purely heuristic.

That is a strong base for long-run reliability because it means plan creation is already treated as something durable and inspectable.

### 3. There are early request and run lifecycle structures

Examples:

- [`MCPRequestContext.swift`](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/AnigmaMCPModule/MCPRequestContext.swift)
- [`CLIDatabaseActor.swift`](/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaCLI/Database/CLIDatabaseActor.swift)

The CLI DB already stores:

- runs
- steps
- receipts
- worktree leases

This means the repo already understands that long-run operation requires durable run bookkeeping.

### 4. Personal context and provenance are stronger than average

The Contextum and document-truth work already gives the architecture a durable memory substrate with:

- source identity
- revision and freshness fields
- chunk lineage
- replay context
- evidence-linked ingestion

That is a meaningful advantage over most current agent stacks.

## What Is Missing

## 1. No unified persistent execution-state spine

This is the biggest gap.

The repo has:

- request lifecycle objects
- receipts
- plan evidence
- queues
- CLI run/step storage

But it does not yet clearly expose one canonical, governed store for:

- current plan tree
- subgoal lineage
- branch history
- rollback points
- active scratch state
- compaction checkpoints
- replan events
- resumable task state across daemon/app/CLI surfaces

Without that, long-run agents depend too heavily on:

- current transcript state
- ad hoc tool-side persistence
- receipts that prove what happened but do not fully reconstruct what should happen next

## 2. Context compaction is not yet a first-class contract

Recent platform practice from Anthropic and OpenAI treats context editing or compaction as a core runtime capability, not a cleanup trick.

The repo has memory-like pieces and planning pieces, but it does not yet obviously define:

- when active context should be compacted
- what must be preserved before compaction
- what becomes durable note or memory state
- how compaction boundaries are represented in receipts and run state
- how a run resumes coherently after compaction

## 3. Memory editing is under-specified

The personal context design is moving in the right direction, but the architecture still needs explicit operations for:

- promote
- merge
- supersede
- tombstone
- conflict-mark
- forget

Storing memory is not enough. Long-running systems degrade unless memory curation is an explicit subsystem.

## 4. Planning and execution are not yet fully joined

The repo has planning systems and execution systems, but the seam between them still looks weaker than it should be for long-run agents.

The architecture should make it easy to answer:

- what subgoal is currently active
- why this subgoal exists
- what evidence justified it
- what state was handed into it
- what outputs updated the parent plan
- what changed after failure or replan

That path is not yet obviously canonical.

## 5. Verifier lanes are still too implicit

The architecture has evidence and governance, but long-run agents also need explicit verifier passes for:

- state consistency after compaction
- retrieval package sufficiency
- stale-memory conflict detection
- branch-completion correctness
- safe-to-act decisions under incomplete evidence

Without verifier lanes, long runs tend to drift into locally coherent but globally wrong behavior.

## 6. Long-run evaluation is not yet the main target

The architecture should be tested for:

- resume-after-compaction correctness
- branch recovery after failure
- replan quality
- stale-memory abstention
- preservation of original goal through many substeps
- cost-bounded context survival

Those are different from ordinary retrieval or unit tests.

## Repo-Specific Interpretation

### What the architecture already supports well

- evidence-backed plan creation
- request/job lifecycle metadata
- durable receipts
- personal context provenance
- run/step storage in CLI surfaces

### What it does not yet support cleanly

- one canonical state store for long-running execution
- hierarchical subgoal state with durable parent-child relationships
- explicit compaction checkpoints
- memory editing and forgetting policy as runtime behaviors
- verifier lanes for long-horizon drift and resumption

## Recommended Architecture Shape

The repo should distinguish four state classes:

### 1. Working Context

Short-lived prompt-visible context.

Contains:

- current task slice
- active subgoal
- immediate observations
- current tool outputs

### 2. Execution State

Persistent task-control state.

Contains:

- run record
- subgoal tree
- branch history
- retries
- pending approvals
- rollback markers
- compaction checkpoints
- last known good state

This is the missing spine.

### 3. Episodic Memory

Durable ground-truth experience and source memory.

Contains:

- source snapshots
- chunk lineage
- conversations
- tool episodes
- retrieval evidence

### 4. Profile/Semantic Memory

Higher-level durable facts and preferences.

Contains:

- project summaries
- stable entities
- user preferences
- source trust priors
- derived but evidence-backed assertions

## Design Rules

1. Never use receipts as the only reconstruction mechanism for live execution state.
2. Never compact active context without recording a resumable checkpoint.
3. Never let summaries replace the underlying episodic evidence.
4. Every subgoal should have parent linkage and completion semantics.
5. Replanning should mutate execution state explicitly, not only generate a new transcript.
6. Memory promotion and forgetting should be governed operations, not incidental side effects.
7. Long-run evaluation must test continuity and recovery, not just one-shot correctness.

## Highest-Value Next Steps

1. Define a canonical execution-state schema.
2. Add a context compaction contract and checkpoint model.
3. Join plan generation and plan execution through durable subgoal state.
4. Define memory-editing operations and their evidence model.
5. Build long-run evaluations for compaction, resumption, and replan quality.

## Bottom Line

Your architecture is already better than average on evidence, provenance, and memory foundations.

What you are still overlooking is that long-running agents need a **state model**, not only a memory model.

Recursive or hierarchical context modeling absolutely helps. The research strongly supports that. But in your architecture it should sit on top of:

- persistent execution state
- explicit compaction checkpoints
- curated memory layers
- verifier lanes

Without those, recursive context modeling will improve prompt efficiency but not fully solve long-run reliability.
