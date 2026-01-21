# Agent Operating Instructions

This repo enforces a governed workflow. Tools are the only way to mutate the tree—they emit receipts, `nextTool` guidance, and ledger entries that the plugin checks before allowing writes. The canonical reference for every helper is `agent_tools.md`, which contains each tool's verbatim code plus the receipts it emits, what it does, and why it exists.

## Pipeline
1. **Pre-flight**: Run `repo_clean_check` (and optionally `swiftpm_log`/`gates`) so the agent knows the branch, forbidden paths, and clean state. Inspect the files you intend to edit with `inspect_repo` so an inspection receipt is written before you touch anything.
2. **Patch creation**: Use `generate_patch` (with a normalized unified diff) → `propose_patch` (citing `phaseId` and `acceptanceRefs` from `Docs/governance/phases/*.md`) → `validate_patch`. Each tool writes a receipt and, when successful, returns a `nextTool` hint; follow the hints. `validate_patch` must pass `git apply --check` and your configured gates before `apply_patch` becomes available.
   - If any validation/apply step fails, run `diagnose_patch_failure` immediately so you know whether to re-inspect files, regenerate the patch, or rerun the gates before trying again.
3. **Application**: Only the Integrator session runs `apply_patch`, and it must be the same patch hash that just validated. The plugin enforces the inspect→generate→propose→validate→apply chain plus phase contracts, so never try to skip a step or forge receipts.
4. **Post-apply**: Use `quarantine_patch` or `rollback_last_apply` if something goes wrong, then let the Integrator run `commit_changes` once gates, receipts, and forbidden path checks stay green.

## Tool highlights
- Run `swiftpm`/`swiftpm_log` for builds/tests so you get log tail diagnostics without flooding the context window.
- For long-lived artifacts, run `binary_build_preflight` first, then `build_binary` once the preflight returns `ok: true` (preflight writes its own log, so you can prove it succeeded).
- Docs work should happen through `docs_patch` or `inspiration_patterns`, which both run in detached worktrees and emit patch hashes you apply via the normal pipeline.
- `generate_patch` now normalizes any fenced or indented diffs, insists the ---/+++/@@ headers start at column 1, and returns `nextTool` hints plus troubleshooting messages when it still rejects a patch, so let it do the sanitizing for you instead of manually reformatting.
- When you need to experiment, spin up a scratch worktree with `worktree_create`, run your commands via `scratch_worktree`, capture the diff, and clean up with `worktree_remove`.
- The plugin blocks `apply_patch` if receipts are missing, if the phase contract gate fails, or if base file hashes change. Treat the plugin's errors as machine-enforced policy, not optional guidance.

Consult `agent_tools.md` whenever you need the precise enforcement details. Your job is to keep the receipts chain honest—let the tools do the heavy lifting and never invent your own patch formatting or gate bypass.
