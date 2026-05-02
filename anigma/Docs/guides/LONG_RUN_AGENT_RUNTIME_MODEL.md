# Long-Run Agent Runtime Model

This guide translates recent research on long-horizon agent systems into a concrete runtime model for Anigma.

`td` remains the source of truth for sequencing. This document defines the target shape.

The recent external signal is consistent:

- *MemGPT* ([arXiv, October 2023](https://arxiv.org/abs/2310.08560)) separates active context from longer-lived memory
- *E-mem* ([arXiv, January 2026](https://arxiv.org/abs/2601.21714)) argues that preserving reconstructable episodic context is critical for deep reasoning
- *Context-Folding* ([arXiv, October 2025](https://arxiv.org/abs/2510.11967)) shows gains from branching into sub-trajectories and folding them back into concise outcomes
- Anthropic memory docs ([docs](https://docs.anthropic.com/en/docs/claude-code/memory)) reinforce the split between active context and persisted memory
- OpenAI's in-house data-agent context architecture ([OpenAI, February 2026](https://openai.com/index/inside-our-in-house-data-agent/)) treats runtime context as a distinct layer in a broader context stack

## Core Principle

Long-running agents require both:

- memory
- execution state

These are not the same thing.

## Target Runtime Layers

### 1. Working Context

Active prompt-visible state for the current step or subgoal.

Keep this small. It should be aggressively curated and compacted.

It should also be hierarchical:

- parent plan summary
- active subgoal context
- immediate evidence packet
- unresolved risks and blockers

### 2. Execution State

Durable task-control state that survives long runs and compaction.

It should include:

- run ID
- subgoal tree
- parent and child links
- branch and retry history
- pending decisions
- checkpoint markers
- last successful state transition
- current task budget
- fold summaries for completed sub-trajectories
- compaction lineage linking each working-context rebuild to the prior checkpoint

### 3. Episodic Memory

Evidence-preserving history of what happened and what was observed.

This should link naturally into Contextum, artifact storage, and receipts.

### 4. Profile Memory

Higher-level durable facts and priors inferred from repeated evidence.

This should never be the only source of truth.

## Compaction Contract

Before context compaction, the runtime should:

1. persist current execution state
2. persist or update any durable notes worth carrying forward
3. mark a compaction checkpoint
4. rebuild the next working context from:
   - active subgoal
   - relevant parent plan state
   - required episodic evidence
   - profile facts
   - unresolved risks

Additional implication from recent work:

- compaction should preserve explicit outcome summaries for finished branches
- the runtime should be able to "fold" completed sub-trajectories into reusable summaries instead of only truncating them
- rebuild should preserve why the current subgoal exists, not only what evidence is nearby

## Memory Editing

The runtime should support explicit memory-editing operations:

- promote
- merge
- supersede
- tombstone
- conflict-mark
- forget

These should be evidence-backed and ideally auditable.

## Verification Lanes

Long-run agents should have targeted verification passes for:

- compaction safety
- stale-memory risk
- subgoal completion validity
- branch reconciliation
- retrieval package sufficiency
- checkpoint-to-checkpoint continuity
- folded-branch summary sufficiency

## Evaluation Targets

The runtime should be judged on:

- continuity through compaction
- resume-after-failure correctness
- replan quality
- stale-memory abstention
- goal preservation over many steps
- token and latency efficiency under long runs
- branch-and-fold correctness
- quality of parent/child state reinjection after compaction

## Architectural Direction For Anigma

The existing runtime, planning, and Contextum memory work should converge on:

- one canonical execution-state spine
- one compaction/checkpoint contract
- memory layers that remain grounded in source truth
- verifier lanes for long-horizon correctness

Recursive or hierarchical context modeling should plug into this structure as a working-memory strategy, not replace it.

## Additional 2026-04-10 Runtime Consequences

### A. Runtime context needs explicit layered packaging

The runtime should assemble working context from distinct layers rather than one flat prompt payload.

Suggested layers:

- parent plan summary
- active execution-state slice
- immediate evidence packet
- policy/guardrail state
- recent local interaction buffer

### B. Long runs need branch-and-fold semantics

Context-Folding strengthens the case for a runtime that can:

- branch into a sub-trajectory for a subtask
- checkpoint it independently
- return with an explicit fold summary
- reinject only the outcome and required residual state into the parent run

This is stronger than naive summarization because it preserves runtime structure.

### C. Checkpoints should preserve causal state, not only snapshots

For Anigma, checkpoints should preserve:

- current subgoal lineage
- why the subgoal is active
- unresolved decisions
- retry/rollback history
- safety or verifier state needed to continue responsibly

### D. Runtime evaluation should include hierarchical continuity

Anigma-specific long-run evaluation should include:

- whether parent goals survive child-task folding
- whether resumed runs keep the right causal lineage
- whether compacted runs preserve the right pending blockers and approvals
- whether token savings from folding or compaction degrade correctness
