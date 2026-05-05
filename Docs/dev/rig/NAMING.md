# Rig Naming Policy

Rig is the operator namespace for repo-local development tasks.

Canonical paths:
- `scripts/rig.py`
- `scripts/rig_cli/`
- `scripts/rig_tools/`
- `scripts/test_rig_*.py`
- `scripts/fixtures/`
- `Session-bundles/` for handoff review zips

Operator command:
- `python3 scripts/rig.py ...`

Legacy surfaces:
- `scripts/anigma_*.py` may remain as backend implementation files or compatibility wrappers.
- Preserve existing entrypoints when they are still referenced by profiles, proofs, or tests.

Case policy:
- Prefer lowercase `scripts/` for canonical Rig tooling.
- Use tracked uppercase `Scripts/` only for compatibility or legacy test entrypoints until they can be normalized safely.
- Do not rely on case-insensitive filesystem behavior.

Doctrine:
- Rig is the repo-local Anigma development harness.
- Anigma production/runtime code must not depend on Rig.
- Git, proofs, and JSON/JSONL artifacts remain canonical.
