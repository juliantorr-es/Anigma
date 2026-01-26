# Vertical Slice Golden Corpora

This directory stores versioned golden corpora for the vertical slice pipeline.

## Update Policy

- Update goldens only when output changes are intentional and documented in the PR.
- Regenerate corpora by re-running the vertical slice test harness, then replace the files in the active version folder.
- Bump the corpus version (new `vN` folder + updated manifest) whenever the output schema or semantics change.
- Keep the request fixture and output snapshot in sync; never update one without the other.
