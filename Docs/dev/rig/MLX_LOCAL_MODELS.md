# MLX Local Models

Rig can optionally use local MLX models on Apple silicon for advisory summaries and retrieval assistance.

## Models

- Summary model: `mlx-community/Qwen3-4B-Instruct-2507-4bit`
- Summary fallback: `mlx-community/Qwen3-0.6B-4bit`
- Embedding model: `mlx-community/all-MiniLM-L6-v2-4bit`

Environment overrides:

- `RIG_MLX_SUMMARY_MODEL`
- `RIG_MLX_EMBEDDING_MODEL`

## Doctrine

- MLX output is advisory only.
- MLX output is not validation.
- MLX output must not decide pass/fail.
- MLX output must not mutate Git.
- MLX output must not overwrite proofs or canonical artifacts.
- Embeddings are retrieval accelerators only.

## Commands

- `python3 scripts/rig.py llm status --backend mlx`
- `python3 scripts/rig.py llm smoke --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python3 scripts/rig.py llm summarize --backend mlx --artifact .build/rig/results/latest.json`
- `python3 scripts/rig.py llm summarize-session --backend mlx --task td-cleanup-005`
- `python3 scripts/rig.py llm compress-proof --backend mlx --proof Docs/proofs/example.md`
- `python3 scripts/rig.py llm draft-commit-summary --backend mlx --task td-cleanup-005`
- `python3 scripts/rig.py embeddings status --backend mlx`
- `python3 scripts/rig.py embeddings build --backend mlx --model mlx-community/all-MiniLM-L6-v2-4bit`
- `python3 scripts/rig.py embeddings query --backend mlx "RuntimeAuthority shutdown boundary"`

## Artifacts

Summaries:

- `.build/rig/llm/latest-summary.json`
- `.build/rig/llm/latest-summary.md`
- `.build/rig/llm/<task>-session-summary.json`
- `.build/rig/llm/<task>-session-summary.md`

Embeddings:

- `.build/rig/embeddings/index.json`
- `.build/rig/embeddings/vectors.jsonl`
- `.build/rig/embeddings/query-results.json`
- `.build/rig/embeddings/query-results.md`

## Availability

If `mlx`, `mlx_lm`, or `mlx_embeddings` are missing, Rig reports `tool_missing` or `partial` cleanly and continues to operate with deterministic artifacts.
