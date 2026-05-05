# Rig MLX Local AI Verification

## Files Created
- `Docs/proofs/rig-mlx-local-ai-verification-2026-05-05.md`

## Files Modified
- `scripts/rig_tools/mlx_local.py`
- `scripts/rig_cli/commands_llm.py`
- `scripts/rig_cli/commands_embeddings.py`
- `scripts/test_mlx_local.py`

## Commands Run
- `.venv-rig/bin/python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_mlx_local.py` -> `0`
- `.venv-rig/bin/python scripts/test_mlx_local.py` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm status --backend mlx` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings status --backend mlx` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-0.6B-4bit --max-tokens 60` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit --max-tokens 60` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings smoke --backend mlx --model mlx-community/all-MiniLM-L6-v2-4bit` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings build --backend mlx --model mlx-community/all-MiniLM-L6-v2-4bit --limit 25` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings query --backend mlx "RuntimeAuthority shutdown boundary" --top-k 5` -> `0`
- `.venv-rig/bin/python scripts/rig.py schema validate --artifact .build/rig/llm/latest-summary.json` -> `0`
- `.venv-rig/bin/python scripts/rig.py schema validate --artifact .build/rig/embeddings/index.json` -> `0`
- `.venv-rig/bin/python scripts/anigma_diagnose.py validate --task-id rig-mlx-local-ai-verification --command true` -> `0`

## Environment
- Python executable: `/Users/user/Developer/GitHub/Anigma_clean/.venv-rig/bin/python`
- Python version: `3.14.4`
- `mlx`: `0.31.2`
- `mlx_lm`: `0.31.3`
- `mlx_embeddings`: `0.1.0`
- `mlx_embedding_models`: `0.0.11`

## Selected Backends
- Generation backend: `mlx_lm`
- Embedding backend: `mlx_embeddings`

## Generation Results
- `Qwen3-0.6B-4bit` smoke test: passed
- `Qwen3-4B-Instruct-2507-4bit` smoke test: passed
- Summary artifact generation: passed
- Session summary generation: passed

## Embedding Results
- Embedding smoke: passed
- Vector count: `2`
- Dimension: `384`
- Embedding build: passed
- Build document count: `25`
- Build vector count: `25`
- Query top result:
  - `Docs/proofs/td-cleanup-006-batch-005-runtime-lifecycle-repair.md`
  - score `0.400506`

## Artifact Paths
- Summary JSON: `.build/rig/llm/latest-summary.json`
- Summary Markdown: `.build/rig/llm/latest-summary.md`
- Session summary JSON: `.build/rig/llm/td-cleanup-005-session-summary.json`
- Session summary Markdown: `.build/rig/llm/td-cleanup-005-session-summary.md`
- Embedding smoke JSON: `.build/rig/embeddings/smoke.json`
- Embedding smoke Markdown: `.build/rig/embeddings/smoke.md`
- Embedding index JSON: `.build/rig/embeddings/index.json`
- Embedding vectors JSONL: `.build/rig/embeddings/vectors.jsonl`
- Embedding query JSON: `.build/rig/embeddings/query-results.json`
- Embedding query Markdown: `.build/rig/embeddings/query-results.md`

## Schema Validation
- `.build/rig/llm/latest-summary.json`: passed
- `.build/rig/embeddings/index.json`: passed

## Observations
- A local Hugging Face model fetch/download occurred during the first smoke/build runs.
- No cloud API call was made beyond the local package/model fetch path.
- All local AI outputs remain advisory only and non-authoritative.
- The embedding adapter selected the backend that produced vectors in validation (`mlx_embeddings`), with `mlx_embedding_models` left as fallback/status-only unless needed.
- Production source changed: no.
- Git mutation occurred: no.
