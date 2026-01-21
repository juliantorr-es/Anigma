# Reuse Gate

Before any artifact reuse, the engine MUST validate:

1. `artifact_type` matches the request.
2. `model_id` matches exactly.
3. `input_hash` matches exactly.
4. `params_hash` matches exactly.
5. `scope` permits reuse in the current context.
6. `ttl_seconds` has not expired (if present).
7. The artifact respects privacy, project, and compartment policies.

Failures invalidate the artifact and trigger recomputation or fallback.

Every reuse decision emits log events:

- `reuse_attempt` noting `(model_id, input_hash, params_hash)`.
- `reuse_hit` with `artifact_hash`.
- `reuse_miss` with stable reason code (`MODEL_MISMATCH`, `INPUT_MISMATCH`, `PARAMS_MISMATCH`, `SCOPE_VIOLATION`, `PRIVACY_VIOLATION`, `EXPIRED`, `HASH_INVALID`).

Enforced gate prevents “search-before-create” leaks, keeping cache reuse governed like any other capability.
