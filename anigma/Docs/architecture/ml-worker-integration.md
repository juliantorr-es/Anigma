# ML Workers in Harmonia

The ML worker pattern keeps Harmonia the deterministic orchestrator while MLX and llama.cpp do the noisy, warm, long-lived inference work in separate processes.

## Key principles

- **Artifact references, not raw bytes.** Harmonia always passes artifact paths plus content hashes to workers; workers return paths plus hashes and metadata. This keeps the ledger honest and makes replay deterministic.
- **Workers speak NDJSON.** Each worker accepts newline-delimited JSON requests and emits newline-delimited JSON progress/event/responses. A request carries `runId`, `stepId`, `engine`, `task`, `inputs`, and `options`; a response carries outputs, metrics, engine metadata, and an optional error payload. A `requestId` allows Harmonia to retry safely.
- **Two engines under one interface.**
  * **`llama`** already exposes `llama-server` with OpenAI-compatible endpoints. The supervisor can keep it alive and talk HTTP, while the rest of the code sees the unified worker contract.
  * **`mlx`** needs a persistent worker so the first-call compilation cost is amortized. The worker preloads models, warms up with a dummy request, and exposes the same NDJSON contract.

## WorkerSupervisor responsibilities

1. Manage process lifecycle (spawn/restart/backoff, health checks).
2. Maintain a small pool of warm workers per engine.
3. Route `MLTaskComponent` requests to the right engine based on `engine`/`task`.
4. Expose `dispatch(request:) async throws -> MLWorkerResponse`.

## ECS integration

1. `MLTaskComponent` describes the work (engine, task kind, artifact inputs, options, determinism expectations).
2. `MLWorkerDispatchSystem` finds entities with tasks, calls the supervisor, and attaches `MLResultComponent` that records outputs, hashes, metrics, engine metadata, and structured errors.
3. Workers remain optional steps—if a worker fails, the system logs it, writes a failure row in the ledger, and lets downstream systems fall back to non‑ML paths.

## First use case: Embeddings

Start by wiring embeddings. The worker reads Diaplasion chunk artifacts, produces an embedding artifact (float32 bytes with canonical serialization), and returns `outputContentHash` plus engine metadata. The ledger stores the embedding hash, so replay can confirm determinism when temperature=0.

When embeddings work reliably, the same worker protocol can power classification, summarization, reranking, and eventually chat.
