# Anigma Agent Skill Pack

Status: operational guidance. TD remains the source of truth for live task status, blockers, dependency order, and review state.

Last reviewed: 2026-04-10

## Purpose

Anigma uses multiple coding agents with different strengths and limits. Copilot can advance larger implementation plans but may throttle. Vibe/Mistral is strong for focused work and review but should not be asked to parallelize internally. Gemini CLI is useful as a cheap scout, summarizer, and command runner, but should not be trusted as the final authority for architecture or completion.

The solution is not to make every agent smarter in isolation. The solution is to give every agent the same small set of reusable skills, output contracts, and stop conditions so their work composes through TD.

## Universal Rules For Every Agent

Every agent must follow these rules before using any specialized skill:

1. Run `td usage -q` at the start of a context.
2. Treat `td` as the source of truth over roadmap/status docs.
3. Start only tracked work with `td start <issue-id>` or tag a TD work session.
4. Read only the docs needed for the task; do not bulk-load historical status reports.
5. Search before adding new abstractions.
6. Make the smallest change that advances the TD acceptance criteria.
7. Verify with the narrowest meaningful build/test/lint command available.
8. Log material progress with `td log <issue-id> "<note>"`.
9. Submit implementation with `td review <issue-id>`.
10. Never approve work from the same session that implemented it.

## Agent Role Policy

| Agent | Best Use | Avoid |
| --- | --- | --- |
| Copilot | Roadmap-constrained implementation, repetitive mechanical edits, applying review feedback | Large ambiguous architecture decisions without TD acceptance criteria |
| Vibe/Mistral | One focused implementation task, strict diff review, bug finding, quality critique | Multi-track parallel work or broad repo archaeology |
| Gemini CLI | Cheap scouting, grep/read summaries, doc cross-reference checks, stale-status detection | Final architectural calls, approval decisions, or unsupervised sweeping edits |
| Codex | Integration planning, TD/documentation synchronization, policy updates, implementation/review where local context is needed | Bypassing TD or silently accepting other-agent assumptions |

## Skill Format

Each agent skill has:

- **Trigger:** When to use it.
- **Inputs:** What the agent must read or receive.
- **Procedure:** The minimum reliable sequence.
- **Output contract:** What the agent must leave behind.
- **Stop conditions:** When the agent must pause instead of improvising.

## Skill 1: TD Intake And Routing

**Trigger:** Start of every agent context or any request to "pick up work", "continue", "review tasks", or "what next".

**Inputs:**

- `td usage -q`
- `td show <issue-id>` for the selected issue
- Linked files from TD

**Procedure:**

1. Run `td usage -q`.
2. Prefer review work before new work if the user asks for queue health.
3. If implementing, select one issue and run `td start <issue-id>`.
4. Read the issue description, acceptance criteria, dependencies, blockers, and linked files.
5. State which TD item is being advanced.

**Output contract:**

- Selected TD ID.
- Why it is ready.
- Linked files read.
- Planned verification command.

**Stop conditions:**

- Issue is blocked.
- Acceptance criteria are missing or ambiguous enough that implementation would create churn.
- Current worktree changes conflict with the task scope.

## Skill 2: Codebase Orientation

**Trigger:** Before editing unfamiliar code, reviewing a subsystem, or assigning work to another agent.

**Inputs:**

- TD issue and linked files.
- `rg`/`fd` search results for relevant symbols.
- Current architecture docs if the change is architectural.

**Procedure:**

1. Find existing types/functions with `rg` before creating new ones.
2. Identify module boundary: app shell, domain module, AnigmaCore, DatabaseCore, daemon, CLI, capsule, or tests.
3. Check whether the code path is canonical or a duplicate/stub path.
4. Read the smallest set of files needed to understand ownership.
5. Record assumptions in TD if they affect implementation.

**Output contract:**

- Canonical module/path.
- Existing abstraction to extend.
- Duplicate/stub paths avoided.
- Risk or blocker if ownership is unclear.

**Stop conditions:**

- Multiple canonical candidates exist.
- The change would create a new framework instead of extending an existing one.
- A stub is being promoted without an explicit TD/task reason.

## Skill 3: Focused Backend Implementation

**Trigger:** Any backend code task in Swift modules, daemon workers, database actors, contracts, logging, jobs, workflows, or inference.

**Inputs:**

- TD acceptance criteria.
- Relevant contracts/ADRs.
- Existing tests or nearest test target.

**Procedure:**

1. Start the TD item.
2. Make a narrow patch in the canonical module.
3. Preserve actor isolation and Sendable/Codable requirements.
4. Use `os.log`/structured logging for backend diagnostics; do not add new `print` debugging in daemon/shared backend code.
5. Add or update tests when behavior changes.
6. Run focused validation.
7. Log what changed and what remains.
8. Move to review with `td review <issue-id>` only when acceptance criteria and verification evidence are present.

**Output contract:**

- Files changed.
- Behavior changed.
- Validation command and result.
- Remaining risks.
- TD review/handoff state.

**Stop conditions:**

- Build failures reveal unrelated broken modules that would broaden scope.
- Required public contract is missing.
- The task needs database migration policy or governance decision not present in TD.

## Skill 4: Build Failure Triage

**Trigger:** Build/test/lint failure, "unblock build", "fix compile", or downstream integration failure.

**Inputs:**

- Exact command run.
- Error log path or captured output.
- TD issue for the build blocker.

**Procedure:**

1. Preserve the failing command and first meaningful error.
2. Group errors by root cause, not by count.
3. If the failure is Signal 4 / SIGILL / illegal instruction during compilation, treat the triggering module's exposed compilation surface as the first suspect. Reduce what the module exposes to the compiler before adding more implementation.
4. Fix the earliest/root blocker first.
5. Prefer compatibility shims only when TD explicitly allows unblock/stub strategy.
6. Re-run the same command or the smallest narrower command.
7. Log before/after counts when available.

**Signal 4 surface-reduction rule:**

When a module triggers Signal 4 during compilation, the default response is to shrink the module's exposed compilation surface. Do not start by adding more types, more conditional branches, or broader imports.

Preferred interventions, in order:

- Remove duplicate source roots from the package manifest.
- Exclude example, archive, backup, generated, or stranded source files from the target.
- Split oversized files or type-checking hot spots behind narrower public contracts.
- Move implementation details behind internal/private boundaries.
- Replace cross-module wildcard exposure with minimal protocols or adapters.
- Build the smallest affected target after each reduction.

Only escalate to toolchain or dependency debugging after surface reduction fails to change the Signal 4 behavior.

**Output contract:**

- Root cause category.
- Files changed.
- Error count or target status before/after.
- Exposed compilation surface reduced, if Signal 4 was involved.
- Next blocker if still failing.

**Stop conditions:**

- Error stream indicates generated/duplicate source tree drift.
- Fix requires deleting or moving large source trees.
- More than one agent is touching the same module.

## Skill 5: Documentation And TD Sync

**Trigger:** Any roadmap, audit, status, architecture, or planning documentation change.

**Inputs:**

- Current TD state.
- Relevant docs.
- Current code evidence if documenting implementation state.

**Procedure:**

1. Check TD first.
2. Write docs as dated snapshots or policy, not live task truth.
3. Include "TD remains source of truth" in status-sensitive docs.
4. Update TD when docs introduce new work, acceptance criteria, or blockers.
5. Link changed docs to the TD issue when applicable.

**Output contract:**

- Docs changed.
- TD issues created/updated.
- Any status claims that must be re-verified later.

**Stop conditions:**

- Documentation would mark work complete without TD review/approval.
- Code evidence contradicts the intended status statement.

## Skill 6: Research To Roadmap

**Trigger:** Online research, architecture research, product research, or "how should Anigma use X?"

**Inputs:**

- Primary sources where possible.
- Existing roadmap/architecture docs.
- Relevant TD tracks.

**Procedure:**

1. Verify current facts with web sources when the topic is new/current.
2. Separate source claims from Anigma-specific inference.
3. Convert findings into architecture implications, risks, and evaluation gates.
4. Update docs with citations.
5. Create or update TD only for actionable work.
6. Avoid making research findings a blocker unless they materially block current implementation.

**Output contract:**

- Sources used.
- What applies to Anigma.
- What does not apply yet.
- TD/doc updates.

**Stop conditions:**

- Source is vendor marketing with no technical detail and no corroboration.
- Adoption would require unsupported runtime dependencies.
- Evaluation criteria are missing.

## Skill 7: Review And Approval

**Trigger:** `td usage -q` shows awaiting review, user asks to review work, or an agent produces a diff.

**Inputs:**

- TD issue.
- Linked files.
- Git diff.
- Tests/validation evidence.

**Procedure:**

1. Confirm review separation: do not approve work implemented by the same session.
2. Read TD acceptance criteria first.
3. Review diff for correctness, architecture drift, tests, logging, database migration risk, and docs/TD sync.
4. Reject if acceptance criteria are unmet or verification is absent for material behavior.
5. Approve only when implementation, evidence, and TD state align.

**Output contract:**

- Verdict: approve or reject.
- Findings with file/line references where possible.
- Required fixes if rejected.
- Residual risks if approved.

**Stop conditions:**

- Worktree contains unrelated changes that obscure the diff.
- No validation evidence for code behavior.
- Acceptance criteria changed after implementation without review.

## Skill 8: Agent Handoff

**Trigger:** End of context, throttle risk, agent switch, or task delegation.

**Inputs:**

- TD issue.
- Current diff/status.
- Validation output.

**Procedure:**

1. Run `git status --short`.
2. Summarize only task-relevant changes.
3. Record structured handoff with TD.
4. Include what was done, what remains, decisions, and uncertainty.
5. Name exact next command when useful.

**Output contract:**

- TD handoff or work-session handoff.
- Files touched.
- Validation result.
- Next safe action.

**Stop conditions:**

- No TD issue is associated with the work.
- Handoff would hide failed validation or unresolved blockers.

## Recommended Agent Dispatch

Use this pattern when several tools are available:

1. Gemini CLI scouts: searches code/docs, summarizes candidate files, checks TD/doc consistency.
2. Copilot implements: applies the smallest roadmap-constrained patch for one TD issue.
3. Vibe/Mistral reviews: critiques the diff strictly against acceptance criteria.
4. Copilot or Codex applies review fixes.
5. Different session approves through TD.

Do not ask multiple agents to edit the same files concurrently. Parallelism should happen across disjoint modules or as scout/review work around one implementation lane.

## Prompt Header For Non-Codex Agents

Paste this at the top of Copilot, Vibe, Gemini CLI, or other agent prompts:

```text
You are working in Anigma. TD is the source of truth.

Before acting:
1. Run `td usage -q`.
2. If implementing, run `td show <issue-id>` and `td start <issue-id>`.
3. Read `anigma/Docs/LLM/AGENT-SKILL-PACK.md`.
4. Use the relevant skill from that document.
5. Make the smallest change that satisfies TD acceptance criteria.
6. Run focused validation.
7. Log progress with `td log <issue-id> "<note>"`.
8. Submit with `td review <issue-id>` only when validation evidence exists.

Do not treat roadmap/status docs as current truth when they disagree with TD.
Do not approve work from the same session that implemented it.
```
