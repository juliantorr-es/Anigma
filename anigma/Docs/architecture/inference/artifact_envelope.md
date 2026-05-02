# Inference Artifact Envelope

This spec defines the metadata envelope that every inference-related artifact (cache, intermediate, or truth output) MUST carry. The envelope MAY live in `meta.json`, MAY be embedded as a header, and MUST be emitted as a job log event.

## Required fields

1. `artifact_type` – stable string (e.g., `kv_cache`, `latent_kv_cache`, `context_pack`, `prefill_state`, `embedding_batch`, `token_alignment`).
2. `format_version` – semantic version of the payload layout.
3. `producer` – component/plugin identity and version.
4. `created_at` – RFC 3339 UTC timestamp.
5. `model_id` – unique model + revision hash (weights/manifest hash if local).
6. `input_hash` – canonicalized input hash (incorporating prompt expansions, retrieved context, tool outputs, modalities, redactions).
7. `params_hash` – hash of all decoding/rendering/kernel parameters (sampling, temperature, top_p, backend mode, numeric stability settings).
8. `code_hash` – hash of producing code bundle (or `unknown` if unavailable, in which case scope drops to session-only reuse).
9. `deterministic` – boolean.
10. `reproducible` – boolean; if false, include `non_repro_reason`.
11. `scope` – one of `ephemeral`, `session`, `project`, `global`.
12. `ttl_seconds` – required for `ephemeral`, strongly recommended for `session`.
13. `artifact_hash` – content hash of the payload bytes.
14. `byte_size` – payload size in bytes.
15. `content_encoding` – required when compressed or chunked.

## Optional helpers

- `input_summary` – minimal, non-sensitive facts (token count, context length, modality flags).
- `capability_tier` – allowed reuse semantics (`local_only`, `project_shareable`, `exportable`).
- `privacy_boundary` – `project_id`, `compartment_id`, `data_classification`.

## Integrity rule

If another job reuses the artifact, Anigma MUST prove that `model_id`, `input_hash`, `params_hash`, and `code_hash` still match current execution needs. Reuse without that proof is forbidden.

Example envelope:

```json
{
  "artifact_type": "latent_kv_cache",
  "format_version": "1.0.0",
  "producer": { "component": "AnigmaInferenceEngine", "version": "0.9.3", "plugin": null },
  "created_at": "2025-12-13T08:12:00Z",
  "model_id": "mlx:deepseek-r1-q4@sha256:9b6d…",
  "input_hash": "sha256:2f41…",
  "params_hash": "sha256:8a0c…",
  "code_hash": "sha256:0c2f…",
  "deterministic": true,
  "reproducible": true,
  "scope": "session",
  "ttl_seconds": 86400,
  "artifact_hash": "sha256:44dd…",
  "byte_size": 73400320,
  "content_encoding": "zstd-chunked",
  "input_summary": { "token_count": 48219, "context_policy": "sliding_window_64k" },
  "privacy_boundary": { "project_id": "proj_7c1a…", "compartment_id": "default", "data_classification": "private" }
}
```
