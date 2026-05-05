# Anigma Pipeline

The pipeline is the stable front door for repeatable Anigma work.

It owns:
- run manifests
- step result envelopes
- scope validation
- known blocker classification
- artifact and proof bundling
- profile execution

Backend scripts remain directly runnable and continue to own their own domain logic.

Use:
- `python3 scripts/anigma_pipeline.py run --profile local-fast --task pipeline-bootstrap`
- `python3 scripts/anigma_pipeline.py run --profile cleanup-review --task td-cleanup-004`
- `python3 scripts/anigma_pipeline.py run --profile backend-regularization --task td-cleanup-004 --target AnigmaDaemonCore`
- `python3 scripts/anigma_pipeline.py run --profile daemon-runtime --task td-cleanup-004`

Git hygiene:
- `python3 scripts/anigma_git_hygiene.py status`
- `python3 scripts/anigma_git_hygiene.py scope --task td-cleanup-004 --allowed-path scripts --allowed-path Docs`
- `python3 scripts/anigma_git_hygiene.py diff-summary --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py precommit --task td-cleanup-004`
- `python3 scripts/anigma_git_hygiene.py commit-message --task td-cleanup-004`
