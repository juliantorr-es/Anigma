# Rig MLX Local Models Bootstrap

## Root Cause
The initial MLX implementation had two issues:
1. `scripts/test_mlx_local.py` fixture data included a hidden `.DS_Store` file, but the embedding document collector did not exclude hidden files by path component.
2. `scripts/rig_tools/mlx_local.py` did not bound the subprocess fallback path for `mlx_lm.generate`, so long model loads could hang instead of failing cleanly.

Both issues were fixed before completion.

## Files Created
- `scripts/rig_cli/commands_llm.py`
- `scripts/rig_cli/commands_embeddings.py`
- `scripts/rig_tools/mlx_local.py`
- `scripts/test_mlx_local.py`
- `Docs/dev/rig/MLX_LOCAL_MODELS.md`
- `Docs/schemas/rig.local_llm_summary.v1.schema.json`
- `Docs/schemas/rig.embedding_index.v1.schema.json`
- `Docs/proofs/rig-mlx-local-models-bootstrap-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/schema_validation.py`
- `Docs/dev/rig/README.md`
- `scripts/rig_tools/session_bundle.py`

## Commands Run
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_mlx_local.py` -> `0`
- `python3 scripts/test_mlx_local.py` -> `0`
- `python3 scripts/rig.py llm status --backend mlx` -> `0`
- `python3 scripts/rig.py embeddings status --backend mlx` -> `0`
- `python3 scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-0.6B-4bit` -> `0`
- `python3 scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `python3 scripts/rig.py llm summarize --backend mlx --artifact .build/rig/results/latest.json` -> `0`
- `python3 scripts/rig.py llm summarize-session --backend mlx --task td-cleanup-005` -> `0`
- `python3 scripts/rig.py embeddings build --backend mlx --model mlx-community/all-MiniLM-L6-v2-4bit` -> `0`
- `python3 scripts/rig.py embeddings query --backend mlx "RuntimeAuthority shutdown boundary"` -> `0`
- `python3 scripts/rig.py schema validate --artifact .build/rig/llm/latest-summary.json` -> `0`
- `python3 scripts/rig.py schema validate --artifact .build/rig/embeddings/index.json` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-mlx-local-models-bootstrap --command true` -> `0`

## Environment / Availability
- Python executable: `/Applications/Xcode.app/Contents/Developer/usr/bin/python3`
- `mlx`: available
- `mlx_lm`: available
- `mlx_embeddings`: unavailable
- Default summary model: `mlx-community/Qwen3-4B-Instruct-2507-4bit`
- Fallback summary model: `mlx-community/Qwen3-0.6B-4bit`
- Default embedding model: `mlx-community/all-MiniLM-L6-v2-4bit`

## Validation Results
- Smoke test with `mlx-community/Qwen3-0.6B-4bit`: generated successfully.
- Smoke test with `mlx-community/Qwen3-4B-Instruct-2507-4bit`: generated successfully after a long local model fetch/load.
- `llm summarize` wrote advisory summary artifacts.
- `llm summarize-session` wrote advisory session summary artifacts.
- `embeddings build` returned clean `tool_missing` because `mlx_embeddings` is not installed.
- `embeddings query` returned clean `tool_missing` because no embedding index exists yet.
- Schema validation passed for:
  - `.build/rig/llm/latest-summary.json`
  - `.build/rig/embeddings/index.json`

## Artifact Paths
- Summary JSON: `.build/rig/llm/latest-summary.json`
- Summary Markdown: `.build/rig/llm/latest-summary.md`
- Session summary JSON: `.build/rig/llm/td-cleanup-005-session-summary.json`
- Session summary Markdown: `.build/rig/llm/td-cleanup-005-session-summary.md`
- Embedding index JSON: `.build/rig/embeddings/index.json`
- Embedding vectors JSONL: `.build/rig/embeddings/vectors.jsonl`
- Embedding query results JSON: `.build/rig/embeddings/query-results.json`
- Embedding query results Markdown: `.build/rig/embeddings/query-results.md`

## Notes
- MLX output is advisory only and non-authoritative.
- No cloud API call was required for the final successful commands.
- A local model fetch/download occurred during the first 4B smoke run.
- The subprocess fallback now has a timeout, so long-running MLX loads fail cleanly instead of hanging.
- Production source changed: no.
- Git mutation occurred: no.
