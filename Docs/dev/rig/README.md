# Rig

Rig is the repo-local development harness for Anigma.

It is not the product runtime.
It is not `anigmad`.
It is not a public user-facing CLI.

Purpose:
- run atlas commands
- run audit lanes
- generate task briefs
- inspect Swift diagnostics
- analyze affected files/targets/profiles
- execute pipeline profiles
- inspect git hygiene
- plan deterministic git commits
- stage and commit from explicit plans
- package review bundles
- ingest Rig results into docs indexes
- validate Rig JSON contracts

Examples:
- `python3 scripts/rig.py atlas build`
- `python3 scripts/rig.py atlas query --target AnigmaDaemonCore --limit 5`
- `python3 scripts/rig.py audit state-flow --target AnigmaDaemonCore`
- `python3 scripts/rig.py swift diagnose-log --log .build/logs/swift-build.log`
- `python3 scripts/rig.py affected summary --task td-cleanup-005`
- `python3 scripts/rig.py brief generate --task td-cleanup-005 --template cleanup_singleton_triage --risk singleton_global_state --target AnigmaDaemonCore --limit 10`
- `python3 scripts/rig.py pipeline run --profile local-fast --task rig-cli-bootstrap`
- `python3 scripts/rig.py pipeline bundle --task rig-cli-bootstrap --latest-run`
- `python3 scripts/rig.py docs index-rig-results`
- `python3 scripts/rig.py docs table rig-run-index`
- `python3 scripts/rig.py docs table validator-registry-index`
- `python3 scripts/rig.py docs context-pack --task td-cleanup-005 --budget small`
- `python3 scripts/rig.py bundle session --task td-cleanup-005`
- `python3 scripts/rig.py db health`
- `python3 scripts/rig.py db query latest-runs`
- `python3 scripts/rig.py project architecture --mode advisory`
- `python3 scripts/rig.py project desired-state --target AnigmaDaemonCore`
- `python3 scripts/rig.py monitor snapshot`
- `python3 scripts/rig.py monitor runs`
- `python3 scripts/rig.py monitor tasks`
- `python3 scripts/rig.py monitor tail --run-id latest`
- `python3 scripts/rig.py monitor tui`
- `python3 scripts/rig.py schema list`
- `python3 scripts/rig.py schema validate --artifact .build/rig/results/latest.json`
- `python3 scripts/rig.py git plan-commit --task td-cleanup-005`
- `python3 scripts/rig.py git commit-message --task td-cleanup-005`
- `python3 scripts/rig.py git stage --task td-cleanup-005 --from-plan .build/rig/git/commit-plan-td-cleanup-005.json --confirm`
- `python3 scripts/rig.py git commit --task td-cleanup-005 --from-plan .build/rig/git/commit-plan-td-cleanup-005.json --dry-run`
- `python3 scripts/rig.py git task-status --task td-cleanup-005`
- `python3 scripts/rig.py notify status`
- `python3 scripts/rig.py notify send --title "Rig" --message "Test notification"`
- `python3 scripts/rig.py llm status --backend mlx`
- `python3 scripts/rig.py embeddings status --backend mlx`
- `python3 scripts/rig.py agent status`
- `python3 scripts/rig.py agent plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python3 scripts/rig.py agent validate-plan --plan .build/rig/agents/plans/<plan_id>.json`
- `python3 scripts/rig.py agent launch --from-plan .build/rig/agents/plans/<plan_id>.json --dry-run`
- `python3 scripts/rig.py loop status`
- `python3 scripts/rig.py loop plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python3 scripts/rig.py loop validate-plan --plan .build/rig/loop/plans/<plan_id>.json`
- `python3 scripts/rig.py loop run --task td-cleanup-005 --mode read-only --max-steps 5 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`

Zero-copy audit:
- If `scripts/anigma_zero_copy_flow_audit.py` exists, `rig.py audit zero-copy` delegates to it.
- If it does not exist yet, Rig reports that the command is not implemented yet.

Swift diagnostics:
- `rig.py swift build`, `rig.py swift test`, `rig.py swift diagnose-log`, `rig.py swift warnings`, and `rig.py swift xcodebuild` parse Swift compiler/test output into deterministic JSON and Markdown diagnostics.
- Missing optional tooling is recorded as `tool_missing` / `step_skipped` instead of crashing.

Affected analysis:
- `rig.py affected files`, `rig.py affected targets`, `rig.py affected risks`, `rig.py affected profiles`, and `rig.py affected summary` derive deterministic impact scope from git changes and atlas context.
- Outputs are written under `.build/rig/affected/`.

Docs indexes:
- `rig.py docs index-rig-results` ingests final Rig JSON results, pipeline manifests, step results, Swift diagnostics, affected analysis, cache metadata, and validator-registry gate results into stable JSON/CSV indexes under `Docs/indexes/`.
- `rig.py docs table <name>` points to the generated CSV for a given index.
- `rig.py docs context-pack` emits a compact Markdown context pack under `.build/rig/context-packs/`.
- Registry gate status is included in context packs and commit plans when available.
- `rig.py context build` emits deterministic task-scoped context packs under `.build/rig/context/` for planner and supervisor-loop use.
- Context packs preserve artifact paths, hashes, and omissions while staying advisory and non-authoritative.
- TurboQuant / PolarQuant KV-cache compression is a future seam only; Rig currently compresses artifact context, not model runtime memory.
- `rig.py queue ...` adds a durable checkpointed queue for bounded supervisor-loop jobs.
- Queue jobs and checkpoints are advisory and resumable, not authoritative state.
- `rig.py patch ...` adds a local patch proposal lane that can propose, check, and sandbox-apply advisory diffs without touching the main worktree.
- Patch proposals are advisory, sandbox-only in MVP, and non-authoritative.

Session review bundles:
- `rig.py bundle session` creates a deterministic review zip for a task/session.
- Output lands under `Session-bundles/` by default.
- Bundle contents are scoped, sorted, and read-only. The command excludes `.git`, `__pycache__`, `.DS_Store`, `__MACOSX`, `*.pyc`, `DerivedData`, and unrelated build junk.
- `--dry-run` writes the manifest and summary without creating the zip.
- `rig.py bundle sessions` lists the available session bundles.

Notifications:
- `rig.py notify test`, `rig.py notify status`, and `rig.py notify send` expose the optional macOS notification sink.
- Notifications are opt-in and only attach to final Rig results when `--notify` or `--notify-on` is provided.
- `osascript` is the default backend when available; `terminal-notifier` is optional; `none` is a no-op backend.

MLX local models:
- `rig.py llm ...` exposes advisory-only local summaries through `mlx_lm`.
- `rig.py embeddings ...` exposes optional local retrieval embeddings through `mlx-embeddings`.
- Both backends are optional and never decide pass/fail or mutate canonical artifacts.

Agent launcher:
- `rig.py agent ...` drafts advisory agent plans with local MLX summaries, validates them, and launches known external agents only through allowlisted templates.
- The planner is advisory only. It cannot execute subprocesses directly or invent shell commands.
- Agent run artifacts are captured under `.build/rig/agents/` and can be included in session bundles and monitor state.

Supervisor loop:
- `rig.py loop ...` runs a bounded advisory orchestration loop over allowlisted Rig actions only.
- Read-only mode permits inspection and validation steps only.
- The loop can draft a plan with MLX, validate it, execute only allowlisted Rig actions, and stop deterministically.

DuckDB index:
- `rig.py db init` creates the rebuildable `.build/rig/rig.duckdb` analytical index.
- `rig.py db ingest` rebuilds tables from existing artifacts.
- `rig.py db rebuild` drops and rebuilds the derived index.
- `rig.py db health` reports table counts and availability.
- `rig.py db query ...` exposes read-only analytical queries.
- DuckDB is optional; file artifacts remain canonical when it is missing.

Architecture projections:
- `rig.py project architecture` generates advisory projection records from atlas and Rig evidence.
- `rig.py project desired-state` summarizes desired-shape candidates per target.
- `rig.py project coupling` and `rig.py project overlap` generate evidence-backed hotspots.
- Projections are advisory only. They do not mutate code or become source of truth.

Monitor:
- `rig.py monitor snapshot` reads existing Rig artifacts and writes `.build/rig/monitor/state.json` plus `.build/rig/monitor/index.html`.
- `rig.py monitor runs` prints a compact run list from `.build/rig/results/*.json`.
- `rig.py monitor tasks` prints a compact task summary from Rig indexes and artifacts.
- `rig.py monitor tail --run-id latest` reads the latest event stream, or a specific `run_id` stream from `.build/rig/events/<run_id>.jsonl`.
- `rig.py monitor tui` launches a read-only Textual monitor only when `textual` is installed; otherwise it exits cleanly with `tool_missing` / `step_skipped`.
- Monitor reads artifacts only. It does not run agents, mutate Git, edit source, or supervise processes.

JSON contracts:
- `rig.py schema list` shows the current Rig schema families.
- `rig.py schema validate` validates Rig machine artifacts against versioned JSON Schema families.
- Validation writes JSON and Markdown summaries under `.build/rig/schema-validation/`.

Rule:
- Rig is allowed to know about Anigma.
- Anigma production/runtime code must not know about Rig.
