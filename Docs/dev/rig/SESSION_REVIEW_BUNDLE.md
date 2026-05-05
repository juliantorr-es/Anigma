# Rig Session Review Bundle

Rig Session Review Bundle is the uploadable, deterministic session artifact for review.

Commands:
- `python3 scripts/rig.py bundle session --task td-cleanup-005`
- `python3 scripts/rig.py bundle session --task td-cleanup-005 --latest-run`
- `python3 scripts/rig.py bundle session --task td-cleanup-005 --run-id <run_id>`
- `python3 scripts/rig.py bundle session --task td-cleanup-005 --out /Users/user/Developer/GitHub/Anigma_clean/Session-bundles/td-cleanup-005-session-review.zip`
- `python3 scripts/rig.py bundle session --task td-cleanup-005 --dry-run`
- `python3 scripts/rig.py bundle sessions`

Outputs:
- `Session-bundles/<task>-session-review.zip`
- `Session-bundles/<task>-session-review.manifest.json`
- `Session-bundles/<task>-session-review.summary.md`

Bundle rules:
- Deterministic archive ordering.
- Fixed ZIP timestamps.
- Read-only artifact collection.
- No `.git`, `__pycache__`, `.DS_Store`, `__MACOSX`, `*.pyc`, `DerivedData`, or unrelated `.build` junk.
- Modified files copied under `modified-files/<repo-relative-path>`.
- Oversized files become stub notes instead of bloating the zip.
- Manifest always records included and omitted files.

Review order:
- `README.md`
- `summary.md`
- `bundle-manifest.json`
- `patches/`
- `proofs/`
- `briefs/`
- `modified-files/`
