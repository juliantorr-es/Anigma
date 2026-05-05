# Git Hygiene Protocol

The Git Hygiene layer is read-only by default.

It answers:
- What branch am I on?
- Is the worktree dirty?
- What files changed?
- Are changed files in task scope?
- Are there untracked files?
- Are baselines changed?
- Are production files changed?
- Are proof files changed?
- What commit message should I use?

It does not:
- commit
- push
- pull
- rebase
- stash
- create branches
- mutate the index

Commands:
- `python3 scripts/anigma_git_hygiene.py status`
- `python3 scripts/anigma_git_hygiene.py scope --task td-cleanup-004 --allowed-path scripts --allowed-path Docs`
- `python3 scripts/anigma_git_hygiene.py diff-summary --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py precommit --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py commit-message --task td-cleanup-004`

Pipeline integration:
- The pipeline records git metadata in its run manifest.
- Read-only git hygiene can be used as a smoke step.
- Scope validation remains separate and authoritative for task boundaries.
