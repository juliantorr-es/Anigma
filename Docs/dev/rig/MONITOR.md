# Rig Monitor

Rig Monitor is the local read-only view over durable Rig artifacts.

Purpose:
- inspect task/run progress
- inspect latest events
- inspect affected scope
- inspect Swift diagnostics
- inspect schema validation status
- inspect cache metadata
- inspect git and commit-plan status
- inspect registry-gate outputs

Commands:
- `python3 scripts/rig.py monitor snapshot`
- `python3 scripts/rig.py monitor runs`
- `python3 scripts/rig.py monitor tasks`
- `python3 scripts/rig.py monitor tail --run-id latest`
- `python3 scripts/rig.py monitor tui`

Snapshot:
- Reads existing Rig artifacts only.
- Writes `.build/rig/monitor/state.json`.
- Writes `.build/rig/monitor/index.html`.
- Uses Python stdlib only.
- No network service.
- No external CDN, CSS, or JS.

TUI:
- Uses `textual` only if installed.
- If `textual` is missing, exits cleanly with `tool_missing` / `step_skipped`.
- Read-only.
- Refresh key: `r`
- Quit key: `q`

Safety:
- No Git mutation.
- No source mutation.
- No agent start/stop.
- No process supervision.

