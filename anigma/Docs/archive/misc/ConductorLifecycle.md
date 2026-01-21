# Conductor Lifecycle Guarantees

The Conductor only “waits” when the world has produced observable receipts. To keep the orchestrator running end-to-end and avoid silent, forever‑blocked waits, follow this small state machine:

1. **Start the subagent via `task` (the wrapper invocation).** Use the `.opencode/tool/task.ts` helper so every invocation expands to `node Scripts/subagent_wrapper.js --session "$SESSION" --subagent "<role>" --ledger ".opencode/ledger/workflow.jsonl" --statusFile ".opencode/runtime/status/$SESSION-<role>.json" --timeout 600000 -- "<command>"`. The wrapper writes `subagent.started` immediately, runs the command with `cwd`/`env`/`ledger` locked down, and then emits either `subagent.completed` or `subagent.failed`. If the command is missing, fails to start, crashes instantly, or is terminated because it exceeded `--timeout`, it still writes a deterministic failure receipt so the Conductor can react without guessing.
2. **Require the receipt before waiting.** Before entering any “waiting-for-artifact” loop, the Conductor must confirm that `subagent.started` exists for that session. If `started` never appears within a short deadline (10 s by default), emit `subagent.failed(launch_failed_no_start)` and either retry once or mark the workflow as errored for downstream reporting.
3. **Bound the wait.** Once `started` exists, the Conductor waits for `subagent.completed` / `subagent.failed` within a longer deadline (configurable per team). If the deadline passes without completion, write a `subagent.failed(timeout)` receipt and proceed (abort, retry, or skip, depending on policy).
4. **Heartbeat for observability.** The wrapper already updates `.opencode/runtime/conductor.status.json` with `{state, waitingFor, sessionID, subagent, updatedAt}` on each transition. Review that file before opening a ticket—if it shows “waiting for scout” with a deadline, the conductor is alive and obeying the deadline rather than magically stalled.

This is the “antidote”: the Conductor never trusts silence. Every launch is observable, every waiting loop has a deadline, and the ledger captures the reason for failure. Build your workflow tooling (subagent runners, ledger inspectors, dashboards) around these receipts and the heartbeat file instead of guessing what “stuck” might mean.

## Enforcement

`Scripts/check-subagent-launch.sh` runs a simple grep over `Sources/` and `.opencode/` to ensure only the wrapper (`Scripts/subagent_wrapper.js`) and canonical tool (`.opencode/tool/task.ts`) mention `subagent_wrapper`. Run it in CI so that any drift away from the wrapper path fails fast and the invariant “started before waiting” stays enforced.
