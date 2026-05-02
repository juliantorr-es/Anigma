# Model & Run Specs

Harmonia treats every ML transform as a declared, governable contract. The runtime (MLX, Core ML, llama.cpp, etc.) is a permutation executor; Harmonia owns the ModelSpec/RunSpec and hashes them into artifact keys so cached outputs only match identical inputs, weights, and knobs.

## ModelSpec

ModelSpec answers “which exact weights/tokenizer/precision are we using?”

```json
{
  "id": "mlx:e5-large-v2",
  "weights_hash": "sha256:…",
  "tokenizer_hash": "sha256:…",
  "quantization": "int8",
  "precision": "fp16"
}
```

ModelSpec becomes part of the artifact key and is immutable for the artifact’s lifetime. Any backend update (new weights, tokenizer, precision) produces a new ModelSpec and therefore a cache miss.

## RunSpec

RunSpec answers “which preprocessing, decoding, and numeric parameters influence this run?”

```json
{
  "engine": "mlx",
  "engine_version": "0.22.0",
  "device": "mps",
  "batching": "auto",
  "cache": {
    "kind": "kv",
    "policy": "dynamic",
    "algorithm": "backend-default",
    "bits": null,
    "scope": "session"
  },
  "params": {
    "normalize": true,
    "max_tokens": 512
  }
}
```

RunSpec is CanonicalHash fodder (model_id + input_hash + RunSpec hash) for artifacts stored in Harmonia. If any knob changes (temperature, sampling, scheduling), caches miss intentionally, and governance can explain why a particular artifact is not reused.

## Artifact kinds

Harmonia catalogs artifact kinds (`embedding.v1`, `ocr.v2`, `latent_kv_cache`) so requests can declare intent. Deterministic transforms (embeddings, OCR post-processing, classification) reuse artifacts when ModelSpec/RunSpec/inputs match. Non-deterministic outputs (sampling with temperature >0) get labeled run-scoped or historical-only depending on policy; they never pollute deterministic caches.

## Latent & KV caches

Performance caches (KV caches, latent attention states) belong under the same envelope but are scope-limited (`ephemeral`/`session`). Harmonia stores them for reuse during a run, garbage collects aggressively, and never exposes them as durable truth. They accelerate inference while the governance rules prevent them from leaking across policies.

Cache compression is a RunSpec concern. If a backend uses quantized KV caches, offloaded caches, static caches, or a future TurboQuant-style algorithm, those knobs must be recorded in the RunSpec and included in the artifact/replay hash. This keeps "same model, different cache policy" from being treated as an equivalent run when output quality, latency, or memory behavior may differ.

## Training runs

Training emits governed artifacts too. Harmonia records:

- dataset_hashes (inputs, splits, augmentations)
- seed + optimizer/hyperparameters
- code_hash + environment fingerprint
- checkpoint/hash + metrics artifact

Training artifacts are versioned, comparable, and auditable even without perfect determinism. The run metadata belongs to Harmonia so it can answer “which dataset produced this checkpoint?”

## Storage guidance

Postgres stores the catalog/index (artifact metadata, policies, run graphs, reuse history). Large binary payloads (weights, caches, embeddings, checkpoints) live in object storage on disk. Hashes link Postgres rows to blobs so Harmonia keeps the truth while avoiding huge relational rows.

## Governance-enforced reuse

ModelSpec + RunSpec feed into HarmoniaArtifacts. Any reuse goes through the reuse gate, so engines never make policy decisions. Policy violations or dev escape paths are logged via the AuditLogSink and mark artifacts as session-only.

This makes ML transforms governed and explainable, keeps inference engines interchangeable, and ensures cached outputs always align with documented model + run configurations.
