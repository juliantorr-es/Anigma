# Git Hygiene Bootstrap

Date: 2026-05-05

## Outcome
- Git hygiene layer created: yes
- Git mutation occurred: no
- Production source changed: no

## Files Created
- `scripts/anigma_git_hygiene.py`
- `scripts/test_anigma_git_hygiene.py`
- `Docs/git/GIT_HYGIENE_PROTOCOL.md`

## Files Modified
- `scripts/anigma_pipeline.py`
- `scripts/anigma_result_contract.py`
- `Docs/schemas/anigma-pipeline-result.schema.json`
- `Docs/pipeline/README.md`
- `Docs/pipeline/profiles/local-fast.yaml`

## Commands Run
- `python3 -m py_compile scripts/anigma_git_hygiene.py scripts/test_anigma_git_hygiene.py scripts/anigma_pipeline.py scripts/anigma_result_contract.py scripts/anigma_validate_scope.py`
- `python3 scripts/test_anigma_git_hygiene.py`
- `python3 scripts/anigma_git_hygiene.py status`
- `python3 scripts/anigma_git_hygiene.py diff-summary --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py precommit --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py commit-message --task td-cleanup-004`
- `python3 scripts/anigma_pipeline.py run --profile local-fast --task git-hygiene-bootstrap`
- `python3 scripts/anigma_diagnose.py validate --task-id git-hygiene-bootstrap --command true`

## Sample Git Status Summary
- branch: `main`
- head: `c7a0cd06dbdc4e85303e7ab4a5288e25a75a0e66`
- dirty: `true`
- changed files: `168`

## Sample Diff Summary
- production_source: `64`
- scripts: `30`
- docs: `15`
- proofs: `50`
- baselines: `1`
- atlas: `1`
- pipeline: `1`
- unknown: `6`

## Sample Commit Message
- `td-cleanup-004: align production source, update proof, refresh atlas, reconcile baselines`

## Pipeline Manifest Git Metadata
- branch: `main`
- head: `c7a0cd06dbdc4e85303e7ab4a5288e25a75a0e66`
- dirty: `true`
- staged_files: present
- unstaged_files: present
- untracked_files: present
- baseline_files_changed: present
- production_source_changed: true
- proof_files_changed: present

## Notes
- Git hygiene is read-only and never writes to the index.
- The cleanup-review profile still fails on scope validation because the current worktree is intentionally dirty outside the allowed task scope.
- The new pipeline manifest now includes git evidence alongside step results.
