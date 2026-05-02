# Harmonia ML Runtime Bridge

Harmonia is the governance checkpoint for every ML-ish artifact. The **Harmonia ML Runtime Bridge** defines the interfaces for 1) runs, 2) artifacts, 3) hash computation, 4) reuse decisions, and 5) logging. Every embedder, OCR worker, LLM call, vector indexer, KV cache, and UI schema snapshot must pass through this API so the chaos never leaks beyond the boundary.

## Artifact Request API

Backends request artifacts like this:

```
{
  "artifact_kind": "embedding.v1",
  "input_hash": "...",
  "model_spec": { ... },
  "run_spec": { ... },
  "scope": "run",
  "policy": {
    "trust_mode": "strict",
    "capability": "write:embedding"
  }
}
```

Harmonia validates the request, canonicalizes `model_spec/run_spec`, and consults the ArtifactReuseGate. The bridge returns either:

- **Hit:** `artifact_hash`, provenance, scope, log event.
- **Miss:** reason code (`HASH_MISMATCH`, `SCOPE_VIOLATION`, `NON_DETERMINISTIC`, etc.), logged for audit.

Hits allow callers to read artifacts from the Harmonia ArtifactStore; misses trigger the backend to recompute and store a new artifact via `ArtifactStore.store(payload, envelope)`.

## Scope tiers

- **Session:** Ephemeral helpers (KV cache, partial attention states, temp tensors). TTL is short, scope is session, and reuse is limited to the current execution. Logs mark these as non-durable.
- **Run:** Reproducible transform outputs tied to one pipeline run (draft summaries, intermediate extractions). Can be compared across runs but not promoted to project truth without approval.
- **Durable:** Project-wide truth (final transcripts, canonical embeddings, published UI schema). Reuse requires governance approval and may trigger stricter policy gates.

Backends declare the desired scope per request; Harmonia enforces it and logs scope transitions in the AuditLogSink.

## Hashing + catalog

Harmonia computes canonical hashes for inputs, ModelSpec, RunSpec, and params. Hashes live in Postgres as the artifact catalog/provenance graph/audit log. Payload bytes live in content-addressed object storage on disk (see `Docs/architecture/inference/storage_layout.md`). The catalog stores metadata, pointers, sizes, policy decisions, and scope info.

## Governance logging

Every request emits audit entries:

- `artifact_request` (includes intent, trust mode, capability, requested scope).
- `reuse_hit`/`reuse_miss` (with reason).
- `artifact_store` (metadata + provenance).
- `policy_violation` when scope or reuse is denied.

This keeps even “vibe coding” from contaminating determinism because every deviation is logged and fences scope.

## Conclusion

The Harmonia ML Runtime Bridge is the border checkpoint. Backends “produce bytes and declare knobs,” Harmonia enforces policy, scope, reuse, hashing, and logging, and the rest of the repo stays sane. Add the bridge as the module that all ML runners import so they cannot bypass governance without compiling under a conspicuous escape flag.
