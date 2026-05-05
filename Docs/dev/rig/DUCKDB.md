# Rig DuckDB Index

Rig DuckDB is a local analytical index over existing Rig artifacts.

Doctrine:
- Git remains source of truth.
- JSON/JSONL/Markdown/CSV artifacts remain canonical evidence.
- DuckDB is rebuildable and derived.
- Deleting `.build/rig/rig.duckdb` must not lose canonical information.

Commands:
- `python3 scripts/rig.py db init`
- `python3 scripts/rig.py db ingest`
- `python3 scripts/rig.py db rebuild`
- `python3 scripts/rig.py db health`
- `python3 scripts/rig.py db query latest-runs`
- `python3 scripts/rig.py db query task --task td-cleanup-005`
- `python3 scripts/rig.py db query diagnostics --target AnigmaDaemonCore`
- `python3 scripts/rig.py db query registry-gate`
- `python3 scripts/rig.py db query commit-plans`

Monitor:
- `python3 scripts/rig.py monitor snapshot --from-db`
- `python3 scripts/rig.py monitor tui --from-db`
- If `duckdb` is missing, commands exit cleanly with `tool_missing` / `step_skipped`, and monitor falls back to files.

Concurrency:
- `db ingest` and `db rebuild` are the only write paths.
- A simple lock file guards concurrent writers.
- Monitor reads only.

