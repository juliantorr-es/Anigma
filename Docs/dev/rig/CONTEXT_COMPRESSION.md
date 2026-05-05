# Rig Context Compression

Rig uses deterministic, task-scoped context packs to keep local LLM prompts small and evidence-backed.

## What It Does

- Collects the smallest useful set of Rig evidence for a task.
- Keeps source paths, hashes, and omissions alongside the compressed text.
- Preserves task brief and blockers even when the budget is tight.
- Produces advisory-only Markdown and JSON artifacts.

## Canonical Outputs

- `.build/rig/context/<task>-context-pack.json`
- `.build/rig/context/<task>-context-pack.md`
- `.build/rig/context/latest.json`
- `.build/rig/context/latest.md`

## Command Surface

- `python scripts/rig.py context build --task <task>`
- `python scripts/rig.py context budget --task <task>`
- `python scripts/rig.py context show --latest`

## Usage

- Supervisor loop planning consumes `.build/rig/context/latest.md` when present.
- Agent planning prefers the latest context pack before falling back to raw evidence.
- Session bundles include the latest task context pack when available.

## TurboQuant Note

TurboQuant / PolarQuant KV-cache compression is not implemented in Rig today.
Rig currently compresses prompt context at the artifact layer.
If MLX exposes stable runtime compression later, Rig may add an experimental seam such as `--runtime-compression turboquant`.
That seam does not exist in the current MVP and should not be assumed active.

## Doctrine

- Context packs are derived and advisory.
- Source artifacts, proofs, JSON/JSONL contracts, and Git remain authoritative.
- Never treat a context pack as canonical truth.
