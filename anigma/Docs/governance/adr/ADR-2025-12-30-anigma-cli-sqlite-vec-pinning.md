# ADR: sqlite-vec Pinning for Anigma CLI (2025-12-30)

## Context
- Hybrid retrieval requires vector search; sqlite-vec is zero-dependency but pre-v1 and subject to breaking changes.
- The CLI must remain deterministic and auditable; vector extension builds must be reproducible across machines.

## Decision
- Adopt sqlite-vec as the default vector extension, pinned to a specific version tag/commit recorded in this ADR and in build scripts.
- Build path is deterministic: vendored source or fixed archive hash stored under `Tools/Vendor/sqlite-vec/` with recorded SHA256; build flags include `SQLITE_ENABLE_COLUMN_METADATA` and `SQLITE_ENABLE_JSON1` matching DatabaseCore.
- Loading policy: extension is loaded only when hash/version matches the pinned value; otherwise CLI falls back to lexical-only mode and emits a receipt warning.
- Compatibility checks: migrations detect extension availability and dimension support; vector tables are created only when extension is present and version matches.
- Override knob: environment variable `ANIGMA_SQLITE_VEC_ENABLE=true|false` (default true) to allow operators to disable vector search explicitly; disabling forces lexical-only retrieval and skips vector migrations.

## Consequences
- Deterministic builds support audit trails and offline verification.
- Operators can disable vector search without breaking lexical retrieval.
- Additional CI coverage needed to verify both vector-enabled and vector-disabled paths.

## Compatibility and migration
- Existing DBs without vector tables continue to operate; migrations add vector tables conditionally.
- If pinned version changes, migrations must include compatibility notes and optional re-embedding guidance.
- Fallback behavior avoids runtime failure by reverting to lexical-only when the extension is missing or mismatched.

## Acceptance and rollback criteria
- Acceptance: pinned sqlite-vec hash is documented; build/verify scripts confirm hash; Surface/Praxis tests pass with vector enabled and disabled; receipts log vector availability state.
- Rollback: if sqlite-vec proves unstable or unmaintainable, remove extension loading and drop vector tables while preserving lexical indexes; document degraded mode.
