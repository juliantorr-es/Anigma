# Phase 5 · Accessum Daemon & Persistence

Accessum now keeps every run in a durable, versioned ledger, exposes a contract-aware admin surface, and ships with a helper script that launchd can orchestrate for unattended operation.

## Persistence surface

- Runs are recorded in an Accessum ledger database under the Accessum runtime base directory (by default `~/Library/Application Support/Anigma/Accessum/accessum.db`, or whatever you set via `ANIGMA_ACCESSUM_BASE` / `--output-base`). Each row contains the `runId`, spec reference, artifact directory, replay command, metrics, and the full `trace.json` payload.
- The schema is versioned via SQLite’s `PRAGMA user_version`; migrations create `runs`, `steps`, `artifacts`, `replays`, `retention_events`, and `schema_migrations`, so schema evolution is auditable.
- The `metrics` field captures `totalDurationMs` and the number of steps, which helps correlate timing regressions with the trace data.
- If you need to replay a historical run, the same `runId` continues to point at `Artifacts/accessum/{runId}/trace.json` plus the ledger row that backs it.
- Retention is configurable via `accessum flow --retention-days 30` (default) and logs each cleanup inside `retention_events` so disk usage stays predictable.
- Audit this ledger with `accessum flow admin --stuck-minutes 5`, which emits a contract-versioned JSON envelope describing totals, statuses, stuck runs, and retention stats.

## Structured observability

- `Scripts/run_accessum_daemon.sh` runs the already-installed `accessum-flow` binary (override via `ACCESSUM_FLOW_BINARY`), rotates `Artifacts/accessum/daemon.log` once it exceeds ~5MB, and keeps the heartbeat `status.json` alongside the shared Application Support layout.
- The script still writes timestamped lifecycle messages so you can monitor whether the daemon is cycling or failing.
- Use this log together with `accessum flow admin` to correlate run failures with stuck jobs while keeping CLI output machine-readable.

## Admin & replay contract

- `accessum flow admin` emits a contract-versioned JSON envelope (same shape as the operator) that includes totals, status counts, stuck runs, retention stats, and the Application Support base path.
- Replay actions now log their verdicts in the `replays` table; `accessum flow --replay <runId>` records `"ok"` when everything matches and `"drift"` plus a detail string when hashes diverge.
- From a single command you can now ask “what ran,” “what stuck,” “what was pruned,” and “did the replay match?” without parsing human prose.

## Launchd packaging plan

1. Copy `Scripts/run_accessum_daemon.sh` into your Mac’s daemon directory or keep it next to the repo; it already seeds the necessary cache directories and exit codes nicely.
2. Create a launch agent such as `~/Library/LaunchAgents/com.anigma.accessum.plist` containing:

    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.anigma.accessum</string>
        <key>ProgramArguments</key>
        <array>
          <string>/Users/your-user/Developer/GitHub/Anigma/Scripts/run_accessum_daemon.sh</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>StandardOutPath</key>
        <string>/Users/your-user/Developer/GitHub/Anigma/Artifacts/accessum/daemon.log</string>
        <key>StandardErrorPath</key>
        <string>/Users/your-user/Developer/GitHub/Anigma/Artifacts/accessum/daemon.log</string>
      </dict>
    </plist>
    ```

3. Bootstrap the agent with:

    ```bash
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.anigma.accessum.plist
    ```

4. Use `launchctl log show --predicate 'sender == "accessum-daemon"' --style syslog` (or watch the `daemon.log`) to inspect lifecycle details.

5. When you ship, include the daemon script, the `accessum-flow` binary, and the `plist` in your installer so operations can drop them into place and enable the agent.

All persisted metadata, structured metrics, and logs point back to `Artifacts/accessum/{runId}/` plus the SQLite ledger, so replaying or debugging a run only requires that directory and the `runId`.
