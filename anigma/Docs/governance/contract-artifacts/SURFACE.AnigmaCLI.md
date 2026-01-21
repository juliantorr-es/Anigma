# Summary (verbatim)

Background & intent

  - You provided a contract for a governed Anigma CLI that owns orchestration, policy,
    receipts, worktree lifecycle, local DB/indexing, and hybrid search. Existing repo hints:
    legacy Harmonia CLI design doc (Docs/HarmoniaCLI-Overhaul.md), Praxis/RepoIdentity gates
    (Sources/PraxisCore/RepoIdentityGate/*.swift, Sources/HarmoniaCLI/
    RepoIdentityCommand.swift), worktree tooling in agent tools (agent_tools.md,
    opencode.json), prior CLI governance mentions in WARP.md, and DB/index scaffolding with
    FTS5 in Sources/HarmoniaModule/Tools/CodeIndexStore.swift plus schema files (Sources/
    DatabaseCore/Schema_*.sql) and native SQLite contract (Docs/governance/contract-
    artifacts/NativeDeps/NATIVE.SQLite.md). No existing “Anigma CLI” contract artifact;
    vector extension not yet referenced.

  Key decisions / options

  - Surface contract: Add a governed contract artifact describing the CLI verbs (interactive
    TUI vs run-mode), receipts, worktree lifecycle, loop-breakers, and approval defaults;
    align with existing Praxis/RepoIdentity gates to avoid a parallel surface.
  - State store: Reuse existing DatabaseCore + GRDB/FTS5 patterns; introduce a pinned
    sqlite-vec ADR + migration path rather than a new DB layer. CodeIndexStore.swift can
    evolve to hold vector tables/hybrid queries instead of creating another store.
  - Worktrees and leases: Build on current worktree gate/tests (PraxisCore) and agent_tools
    conventions; add lease metadata in the session DB (createdAt, lastUsedAt, runId, TTL,
    lock) and housekeeping routines surfaced as CLI commands.
  - Tool routing and MCP: Use existing ToolOrchestrator patterns (HarmoniaModule) and
    agent_tools allowlist approach; default-deny MCP servers with hash/signature
    allowlisting and receipts per call.
  - Engine backends: Route through MLWorker surfaces already used by Harmonia; wrap external
    CLIs (Codex/Claude/Gemini) as governed tools with forced non-interactive modes and
    approval defaults.
  - Hooks: Mirror Claude-style lifecycle hooks at orchestrator layer (pre-prompt, policy
    preflight, pre-tool, post-tool, stop/cleanup) and record in receipts.
  - Loop breakers: Implement orchestrator-level counters (steps, tool calls, wall/time,
    tokens/spend, repeated calls, “no novelty”) with stop receipts.

  Risks & mitigation

  - Drift from existing Harmonia CLI surface: anchor new commands in the existing Praxis/
    RepoIdentity/Stack patterns to avoid duplicating gateways.
  - SQLite-vec pre-v1 instability: pin version via ADR, include migration/compatibility
    checks, and add a deterministic build path.
  - Worktree safety: enforce lock/respect porcelain list; require approvals for removing
    unmerged worktrees; ensure housekeeping never touches protected leases.
  - MCP trust: default deny + allowlist by hash/signature; explicit scopes/quotas to prevent
    privilege creep.
  - Evidence correctness: receipts must capture tool calls, retrieved chunks, model/binary
    hashes; ensure dry-run emits receipts without mutation.

  Next steps (governed commands only)

  1. Identify current repo identity/status to anchor work: Scripts/harmonia.sh repo-identity
  2. Capture pipeline health before design landing: Scripts/harmonia.sh pipeline-status
  3. Draft SURFACE contract artifact (no code edits) in governance docs worktree via
     inspect-only session: Scripts/harmonia.sh session start --label "cli-contract-planning"
     then craft doc manually (no apply).
  4. Generate ADR stubs (DB schema/migrations, sqlite-vec pinning, MCP trust model, worktree
     TTL/cleanup, external CLI approvals) using docs_patch pipeline: harmonia cmd run
     docs_patch --arg path="Docs/governance/adr/" --arg label="cli-adr-stubs"
  5. Outline orchestrator/TUI/run-mode command spec and hook taxonomy in Docs/HarmoniaCLI-
     Overhaul.md via governed patch chain: harmonia cmd run generate_patch --arg
     phaseId="anigma-cli-surface" --arg acceptanceRefs="contract-surfaces" → propose_patch →
     validate_patch → Integrator apply_patch.
  6. Plan DB/index migrations and vector extension integration with praxis tests: Scripts/
     harmonia-surface.sh --suite database-core (once specs are written).
  7. Define housekeeping/loop-breaker test specs and receipts: harmonia cmd run praxis --arg
     suite="cli-loop-breakers"

  No code edits were made. rg findings that shaped this plan: Harmonia CLI design doc (Docs/
  HarmoniaCLI-Overhaul.md), governance mandates in WARP.md/AGENTS.md, worktree gates/tests
  (Sources/PraxisCore/RepoIdentityGate/*.swift, Sources/HarmoniaCLI/
  RepoIdentityCommand.swift), FTS5/index store scaffolding (Sources/HarmoniaModule/Tools/
  CodeIndexStore.swift, Sources/DatabaseCore/Schema_*.sql), native SQLite contract (Docs/
  governance/contract-artifacts/NativeDeps/NATIVE.SQLite.md), and agent worktree tooling
  (agent_tools.md, opencode.json).

# SURFACE Contract: Anigma CLI (Harmonia-Orchestrated Developer CLI)

## Purpose and scope
- Governed developer CLI that owns orchestration, policy evaluation, evidence/receipts, worktree lifecycle, local DB/indexing, and hybrid retrieval.
- Leverages Harmonia CLI patterns (Praxis, RepoIdentity, Stack) instead of introducing a parallel gateway.
- Excludes model training, background daemons that mutate repos silently, or permissive “YOLO shell” modes without policy and receipts.

## Command surface
- **Interactive TUI (`harmonia` front-end mode)**: Presents project identity, active run, worktree status, approvals queue, recent tool actions, loop-breaker counters, index status, and receipts tail. Must emit receipts for session start/stop and each tool call surfaced in UI.
- **Run mode (`harmonia run`-style)**: Non-interactive execution for plan-only, exec-only, or plan+exec. Must support dry-run that emits plan + receipts without filesystem/network/git mutation. Exit codes reflect success/failure; receipts written to deterministic path per runId.
- **Session management**: Start/show/close sessions bound to worktree leases; RepoIdentity gate must pass before mutating commands execute.
- **Housekeeping commands**: List/prune worktrees, show leases, lock/unlock worktrees, dry-run cleanup. Removal of unmerged or unlocked-but-dirty worktrees requires explicit approval flag.
- **Index commands**: Trigger incremental indexing, show index status (commit, chunk/embedding counts), and inspect cached parameters (chunking, models, hashes).
- All commands routed through orchestrator; agents cannot invoke tools directly.

## Orchestration invariants
- Orchestrator is the sole executor of capabilities; agents only request.
- Capability calls must pass policy/approval checks before execution.
- Every capability invocation produces a receipt containing request hash, response hash, tool metadata, stop reason if any.
- External CLIs (Codex/Claude/Gemini) are executed only via governed wrappers with forced non-interactive modes and sandbox/approval defaults.

## Policy and approval defaults
- Default posture: deny tool execution unless allowlisted by policy and approved for the current mode (plan/build/run-mode).
- MCP servers: default-deny until allowlisted by hash/signature + policy config; scopes/quotas must be declared.
- Shell/FS mutations: require approval and run inside the orchestrator sandbox with RepoIdentity gate verified.
- Networked inference: requires explicit backend selection and spend/time budget; logs are redacted and hashed.

## Evidence and receipts
- Each run produces: RunSpec hash, input hash, tool call receipts, retrieved chunk hashes, model/binary hashes, diff hash (if any), stop reason, environment summary (redacted), worktree identity, index snapshot identity.
- Tool receipts include request/response hashes, parameters schema id, approval decision, sandbox flags, wall time, token/spend usage.
- Retrieval receipts include chunk paths, source commit, chunking parameters, embedding model id/hash/dimension, and index snapshot id.
- External CLI receipts capture structured events when available; otherwise capture stdout/stderr hashes + exit code.
- Receipts are written to local DB and mirrored to per-run artifact directory for offline verification.

## Git worktree lifecycle and leases
- Creation: every mutating run executes in a dedicated worktree created by orchestrator; inventory uses the documented `git worktree list --porcelain` format (label + space + value, blank line between worktrees) for deterministic parsing across Git versions.
- Lease record stored in session DB: worktreePath, repoRoot, baseCommit, branchName, runId, createdAt, lastUsedAt, intendedTTL (default 72h), locked (bool), protectedReason, mergedStatus (enum: unknown/merged/unmerged), removalEligibility (enum: safe/approval-required/forbidden).
- Locks: locked worktrees are never pruned; unlocking requires explicit command + approval.
- Housekeeping: runs on startup and via explicit command; prunes stale administrative entries, removes eligible clean worktrees, and requires approval for unmerged/degraded worktrees. Always respects locks and RepoIdentity gate.
- Removal: uses `git worktree remove`; force removal requires approval and is disallowed for locked worktrees.

## Local DB and indexing scope
- Reuse DatabaseCore with GRDB + FTS5; no new database layer introduced.
- Vector search via allowlisted SQLite extension (default sqlite-vec), pinned version with deterministic build path; migrations include compatibility checks.
- Stored data: runs, steps, receipts, tool calls, prompts (redacted), retrieved chunks (hashed), index metadata (commit, chunk params, model ids/hashes), worktree leases.
- Hybrid retrieval is the default: lexical (FTS5/BM25) candidates blended or reranked with vector scores. Deterministic ordering is enforced with explicit `ORDER BY rank`/`bm25()` and stable tie-breaks; no reliance on implicit planner order.
- Indexing is incremental: unchanged files at same commit are not re-embedded.
- Vector availability is checked at startup: if sqlite-vec version/schema does not match the pinned version, the system falls back to lexical-only retrieval and emits a receipt warning; vectors never fail silently.

## Tool routing and capability layer
- Tool requests flow: agent → orchestrator policy → receipt issued → tool executes.
- ToolRegistry/ToolOrchestrator patterns are reused; no parallel runtime.
- MCP: default-deny until allowlisted by hash/signature; each call includes scope, quota, and receipt.
- External CLIs: wrappers enforce non-interactive/script modes, sandbox, approvals, and event capture to receipts.

## Loop breakers and stop conditions
- Limits: maxSteps (default 50), maxToolCalls (default 100), maxWallTime (default 30m), maxTokens (backend-provided), maxSpend (backend budget), repeated-identical-call threshold (default 3), no-novelty window (default 3 consecutive steps with no new files read/diffs/evidence).
- On trigger: orchestrator emits stop receipt with triggering condition, counters, and last action; run terminates cleanly.

## Hook taxonomy (orchestrator-level)
- Pre-prompt: sanitize/redact, apply prompt-injection guards; cannot grant new permissions.
- Policy preflight: evaluate policy, budgets, worktree lease validity; may reject/require approval.
- Pre-tool: last-mile check for scope/sandbox; may downgrade/deny.
- Post-tool: capture evidence, redact outputs, hash artifacts, enqueue receipts.
- Stop/cleanup: emit stop receipts, release leases, schedule housekeeping.
- Hooks cannot bypass RepoIdentity/Stack gates or mutate tool permissions outside policy.

## Acceptance tests (Praxis/Surface expectations)
- Praxis: RepoIdentity gate rejects worktrees under `.opencode/worktrees` unless allowlisted and leased; acceptance requires receipts logging gate decision.
- Praxis: worktree inventory uses `git worktree list --porcelain`; parser handles label/value lines and blank separators; inventory feeds lease metadata and housekeeping decisions.
- Surface: `harmonia run --dry-run` emits plan + receipts and leaves filesystem/git untouched.
- Surface: interactive TUI displays approvals queue and reflects receipt stream for tool calls; closing TUI emits stop receipt.
- Surface: housekeeping dry-run lists worktrees with lease metadata, respects locks, and marks removalEligibility correctly.
- Surface: loop-breaker test hits repeated-call threshold and run stops with stop receipt containing counters.
- Praxis: MCP call without allowlist is denied with policy receipt; allowlisted MCP call records scope/quota in receipt.
- Praxis: index command on unchanged commit reuses embeddings (no new rows) and returns hybrid search results consistent across repeated runs; lexical ordering is stable with explicit `ORDER BY rank`/`bm25()` and documented tie-breaks.
- Surface/Praxis: vector extension version/schema checked; if mismatched or disabled, retrieval falls back to lexical-only and receipts record the downgrade (no silent vector miss).

## Definition of done (Phase 1: contract + scaffolding alignment)
- SURFACE.AnigmaCLI contract artifact exists and governs CLI surface.
- ADRs for surface/receipts, DB/indexing, sqlite-vec pinning, MCP trust, worktree leases/housekeeping, external CLI wrappers exist with explicit defaults.
- HarmoniaCLI-Overhaul.md points to this contract and reaffirms Praxis/RepoIdentity authority.
- No new binaries or DB layers introduced; plans align with existing DatabaseCore and ToolOrchestrator patterns.
- Acceptance tests listed above are expressible in Praxis/Surface suites and attached to run-mode/TUI behaviors.
- Implementation sequence is honored: (1) executable Praxis/Surface acceptance suites (default always-on + env-gated ML backends), (2) DatabaseCore migrations for runs/steps/receipts/tool calls/leases with FTS5 BM25 hybrid queries, (3) pinned sqlite-vec integration with version/schema checks and lexical fallback, (4) incremental indexer wiring, (5) TUI polish.
