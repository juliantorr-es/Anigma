# Rig Local AI Capability Verification

## Files Created
- `scripts/rig_cli/commands_llm.py`
- `scripts/rig_cli/commands_embeddings.py`
- `scripts/rig_tools/mlx_local.py`
- `scripts/test_mlx_local.py`
- `Docs/dev/rig/MLX_LOCAL_MODELS.md`
- `Docs/schemas/rig.local_llm_summary.v1.schema.json`
- `Docs/schemas/rig.embedding_index.v1.schema.json`
- `Docs/proofs/rig-local-ai-capability-verification-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/schema_validation.py`
- `Docs/dev/rig/README.md`
- `scripts/rig_tools/session_bundle.py`

## Commands Run
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_mlx_local.py` -> `0`
- `.venv-rig/bin/python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_mlx_local.py` -> `0`
- `.venv-rig/bin/python scripts/test_mlx_local.py` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm status --backend mlx` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings status --backend mlx` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-0.6B-4bit` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm summarize --backend mlx --artifact .build/rig/results/latest.json` -> `0`
- `.venv-rig/bin/python scripts/rig.py llm summarize-session --backend mlx --task td-cleanup-005` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings build --backend mlx --model mlx-community/all-MiniLM-L6-v2-4bit` -> `0`
- `.venv-rig/bin/python scripts/rig.py embeddings query --backend mlx "RuntimeAuthority shutdown boundary"` -> `0`
- `.venv-rig/bin/python scripts/rig.py schema validate --artifact .build/rig/llm/latest-summary.json` -> `0`
- `.venv-rig/bin/python scripts/rig.py schema validate --artifact .build/rig/embeddings/index.json` -> `0`
- `.venv-rig/bin/python scripts/anigma_diagnose.py validate --task-id rig-local-ai-capability-verification --command true` -> `0`

## Environment
- Python executable: `/Users/user/Developer/GitHub/Anigma_clean/.venv-rig/bin/python`
- Python version: `3.14.4`
- `mlx`: available, version `0.31.2`
- `mlx_lm`: available, version `0.31.3`
- `mlx_embeddings`: available, version `0.1.0`
- `mlx_embedding_models`: available, version `0.0.11`

## Backend Selection
- Selected generation backend: `mlx_lm`
- Selected embedding backend: `mlx_embeddings`

## Generation Results
- `mlx-community/Qwen3-0.6B-4bit` smoke test: generated successfully
- `mlx-community/Qwen3-4B-Instruct-2507-4bit` smoke test: generated successfully
- `llm summarize --artifact .build/rig/results/latest.json`: generated advisory summary
- `llm summarize-session --task td-cleanup-005`: generated advisory session summary

## Embedding Results
- `embeddings build --model mlx-community/all-MiniLM-L6-v2-4bit`: generated index and vectors successfully
- `embeddings query --query "RuntimeAuthority shutdown boundary"`: returned deterministic ranked results

## Artifact Paths
- Summary JSON: `.build/rig/llm/latest-summary.json`
- Summary Markdown: `.build/rig/llm/latest-summary.md`
- Session summary JSON: `.build/rig/llm/td-cleanup-005-session-summary.json`
- Session summary Markdown: `.build/rig/llm/td-cleanup-005-session-summary.md`
- Embedding index JSON: `.build/rig/embeddings/index.json`
- Embedding vectors JSONL: `.build/rig/embeddings/vectors.jsonl`
- Embedding query results JSON: `.build/rig/embeddings/query-results.json`
- Embedding query results Markdown: `.build/rig/embeddings/query-results.md`

## Schema Validation
- `.build/rig/llm/latest-summary.json`: passed
- `.build/rig/embeddings/index.json`: passed

## Observations
- A local MLX model fetch/download occurred during the first generation and embedding runs.
- No cloud API call was required for the successful verification steps.
- Local AI output remains advisory only and non-authoritative.
- The embedding adapter now supports the installed `mlx_embeddings` package and retains a defensive fallback path for `mlx_embedding_models`.
- Production source changed: no.
- Git mutation occurred: no.
