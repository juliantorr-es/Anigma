# Backend Adapter Contract

Backends MUST expose stable contracts so that inference executors remain interchangeable.

Required capabilities:

1. Declare cache payload format version.
2. Provide deterministic serialization (or explicitly state instability).
3. Publish params that influence outputs/cache structure for inclusion in `params_hash`.
4. Never bypass the reuse gate. Internal caching is limited to the current session unless the artifact conforms to the envelope and hashing rules.

Adapters MAY store temporary acceleration files, but only envelope-compliant artifacts may be reused.

Adapters MUST document numeric stability guarantees. If kernels are not bit-stable, they MUST add a `numeric_mode` field to `params_hash` and mark `deterministic` accordingly.
