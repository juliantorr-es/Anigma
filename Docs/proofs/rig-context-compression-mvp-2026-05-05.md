# Rig Context Compression MVP Proof

## Files Created
- `scripts/rig_cli/commands_context.py`
- `scripts/rig_tools/context_compression.py`
- `scripts/test_context_compression.py`
- `Docs/dev/rig/CONTEXT_COMPRESSION.md`
- `Docs/schemas/rig.context_pack.v1.schema.json`
- `Docs/proofs/rig-context-compression-mvp-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/supervisor_loop.py`
- `scripts/rig_tools/agent_plan.py`
- `scripts/rig_tools/session_bundle.py`
- `scripts/rig_tools/monitor.py`
- `scripts/rig_tools/schema_validation.py`
- `Docs/dev/rig/README.md`

## Commands Run
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_context_compression.py`
- `python scripts/test_context_compression.py`
- `python scripts/rig.py context budget --task td-cleanup-005`
- `python scripts/rig.py context build --task td-cleanup-005 --purpose loop-planner --max-chars 16000`
- `python scripts/rig.py context build --task td-cleanup-005 --purpose agent-plan --max-chars 24000`
- `python scripts/rig.py context show --latest`
- `python scripts/rig.py loop plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python scripts/rig.py schema validate --artifact .build/rig/context/latest.json`
- `python scripts/rig.py schema validate --family rig.context_pack.v1`
- `python scripts/anigma_diagnose.py validate --task-id rig-context-compression-mvp --command true`

## Exit Codes
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_context_compression.py` -> `0`
- `python scripts/test_context_compression.py` -> `0`
- `python scripts/rig.py context budget --task td-cleanup-005` -> `0`
- `python scripts/rig.py context build --task td-cleanup-005 --purpose loop-planner --max-chars 16000` -> `0`
- `python scripts/rig.py context build --task td-cleanup-005 --purpose agent-plan --max-chars 24000` -> `0`
- `python scripts/rig.py context show --latest` -> `0`
- `python scripts/rig.py loop plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `python scripts/rig.py schema validate --artifact .build/rig/context/latest.json` -> `0`
- `python scripts/rig.py schema validate --family rig.context_pack.v1` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-context-compression-mvp --command true` -> `0`

## Context Pack Paths
- `.build/rig/context/td-cleanup-005-context-pack.json`
- `.build/rig/context/td-cleanup-005-context-pack.md`
- `.build/rig/context/latest.json`
- `.build/rig/context/latest.md`

## Packing Results
- Loop-planner build:
  - Input artifact count: `17`
  - Selected artifact count: `13`
  - Omitted artifact count: `4`
  - Char count: `16000`
  - Max chars: `16000`
  - Compression ratio: `0.424`
- Agent-plan build:
  - Input artifact count: `17`
  - Selected artifact count: `17`
  - Omitted artifact count: `0`
  - Char count: `20742`
  - Max chars: `24000`
  - Compression ratio: `0.265`

## Determinism
- Artifact ordering is deterministic.
- Hashes are recorded in the context pack JSON.
- Omitted artifacts include path, sha256, size, and reason.

## Planner / Loop Integration
- `scripts/rig.py loop plan ...` consumed the compressed context pack.
- The resulting loop plan listed `source_artifacts` as:
  - `.build/rig/context/latest.json`
  - `.build/rig/context/latest.md`
- `scripts/rig.py agent plan ...` also reads the compressed context pack when present.
- Session bundles include context pack JSON/MD when present.

## LLM / TurboQuant Statement
- MLX local summarization was not required for the default context-pack build path.
- Any optional MLX-derived section summaries are marked advisory.
- TurboQuant was **not** implemented.
- TurboQuant / PolarQuant KV-cache compression is documented only as a future experimental seam.

## Schema Validation
- `rig.context_pack.v1`: passed
- `.build/rig/context/latest.json`: passed

## Authority Statement
- Context packs are derived and advisory only.
- Source artifacts, proofs, JSON/JSONL contracts, schemas, and Git remain authoritative.

## Git / Source Mutation
- Production source changed: no
- Git mutation occurred: no

