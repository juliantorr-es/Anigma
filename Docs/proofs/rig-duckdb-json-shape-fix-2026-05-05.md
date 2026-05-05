# Rig DuckDB JSON Shape Fix Proof

## Root Cause

DuckDB ingest assumed every `.json` artifact decoded to a dict and called `.get("schema_version")` unconditionally. That crashed on top-level JSON arrays and also failed to distinguish invalid JSON from a legitimate JSON `null`/non-dict shape.

## Files Modified

- [`scripts/rig_tools/rig_duckdb.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/rig_duckdb.py)
- [`scripts/test_rig_duckdb.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/test_rig_duckdb.py)

## Commands Run

- `python3 -m py_compile scripts/rig_tools/rig_duckdb.py scripts/test_rig_duckdb.py scripts/rig.py scripts/rig_cli/*.py` -> `0`
- `python3 scripts/test_rig_duckdb.py` -> `0`
- `python3 scripts/rig.py db rebuild` -> `0`
- `python3 scripts/rig.py db ingest` -> `0`
- `python3 scripts/rig.py db health` -> `0`
- `python3 scripts/rig.py --json db query latest-runs` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-duckdb-json-shape-fix --command true` -> `0`

## DuckDB Versions

- DuckDB Python package version: `1.4.4`
- DuckDB CLI version: not separately queried; Python package is the operational dependency used by Rig

## Live Ingest Results

- DB path: `.build/rig/rig.duckdb`
- Manifest path: `.build/rig/rig-duckdb-manifest.json`
- Table counts after ingest:
  - `runs`: `40`
  - `events`: `1748`
  - `affected`: `1`
  - `diagnostics`: `2`
  - `registry_gate`: `10`
  - `commit_plans`: `1`
  - `cache_metadata`: `3`
  - `artifacts`: `943`
- `db health` reported `db_exists: true`
- `db query latest-runs` returned rows

## JSON Shape Handling

- JSON object artifacts handled: `423`
- JSON array artifacts handled: `176`
- Invalid JSON artifacts skipped: `0` in the current live scan
- Invalid JSON is reported as an omitted artifact entry and a warning when encountered, but it does not abort ingest

## Validation Outcome

- `db ingest` no longer crashes on top-level JSON arrays.
- Ingest continues across mixed JSON shapes.
- Non-DB failures are still reported normally.

## Canonicality

- Production source changed: `no`
- Git mutation occurred: `no`
- DuckDB remains a derived analytical index; canonical truth remains JSON/JSONL/proofs/Git.
