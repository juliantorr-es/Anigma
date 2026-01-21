# SURFACE.MLWorkerBackends

## Surface Definition
**Surface Name**: MLWorkerBackends  
**Authority Boundary**: Core Governance Layer (Accessum/Harmonia evidence chain)  
**Implementation Location**: `Sources/MLWorkerExecutable` (core worker) + `Sources/HarmoniaModule/Inference` (registry/routing/supervisor)  
**Lease Required**: Yes – changes to worker contract, backend adapters, or registry entries must acquire/record a lease.

## Contract Requirements

### Task Contract (Shared)
- **Requests**: Canonical JSON for chat and embeddings; fields include `requestId`, `runId`, `stepId`, `engine`, `modelId`, `task`, `inputs` (paths + hashes), sampling params (temp, top-p, seed, maxTokens), `stream` flag, `outputDirectory` (optional). JSON must serialize deterministically.
- **Responses**: Status, outputs (path + hash + normalizedHash), metrics (durationMs, tokensProcessed, memoryBytes), engine metadata (engine id, binaryHash, modelHash, version, argv/env snapshot), and canonical container hashes for embedding data (header + payload).
- **Evidence**: For every call, record hashes for binary, model, RunSpec, inputs, outputs; attach to Accessum ledger at `.accessum-artifacts/<runId>/ml/<stepId>/`.
- **Errors**: Fail closed with typed errors (unsupportedTask, engineMismatch, capabilityDenied, hashMismatch, timeout, backendFailed, policyDenied). No partial outputs on failure.

### Model Registry and Backend Kinds
- Models MUST declare backend kind (`mlx_local`, `llama_local`, `deepseek_cloud`), format (`mlx_bundle|hf_snapshot`, `gguf`, `remote`), capabilities (`chat`, `embeddings`, `tools`, `json_output`, `streaming`), expected embedding dimension (if applicable), and hash material (local file/directory hashes or remote model id + provider base URL).
- Routing MUST use registry metadata; no ad-hoc string matching. Capability gaps (e.g., DeepSeek embeddings absent) MUST return deterministic capability errors before dispatch.

### Governance and Evidence Hooks
- Hash binaries and models before execution; block if hash not in allowlist/registry.
- Enforce environment allowlist per backend (no ambient PATH leakage). Secrets never written to receipts; store only hashes.
- Policy gate required for cloud egress; respect kill switch/write-gate; emit security events on denial.
- All runs must be reproducible: argv and env snapshot stored in engine metadata; timestamps and hashes recorded for audit.

### Backend Requirements
- **MLX (Local, In-Process)**:
  - Compiled Swift target linking MLX Swift/LM/Embedders (no shell-out mocks). Supports chat (streaming + non-streaming) and embeddings. Embedding dims derived from model metadata, not hard-coded.
  - Warmup hook loads weights/tokenizer once; queue requests within worker; expose bounded concurrency.
  - Allowed env: `MLX_MODEL_PATH`, accelerator knobs; disallow arbitrary env passthrough.
  - Mock mode only via `ML_WORKER_MOCK_MODE=true`, stub-tracked in TechDebt, default OFF.
- **llama.cpp (Local, Managed Server)**:
  - Primary path is managed `llama-server` (OpenAI-compatible chat at `/v1/chat/completions`, embeddings via `/embedding`). WorkerSupervisor owns start/health/restart; captures binary hash and rejects if mismatch.
  - GGUF required; record file hash + quantization/context parameters. Fallback to `llama-cli` allowed only as explicit, stub-tracked emergency path.
  - Streaming supported; embeddings return declared dims.
- **DeepSeek (Cloud)**:
  - OpenAI-compatible chat to `https://api.deepseek.com` (or `/v1`), with streaming and tool-calls when enabled.
  - Embeddings path wired but must return deterministic “provider lacks embeddings” error until DeepSeek publishes support; optional generic OpenAI-compatible embeddings backend may be substituted when available and policy-approved.
  - Cloud calls require explicit policy allow; secrets redacted; record request/response hashes (not bodies); bounded retries/timeouts recorded.

### WorkerSupervisor Integration
- Supervisor MUST own lifecycle of resident backends (warmup, health checks, restart, graceful shutdown).
- Resource limits: per-call token/input/byte caps, wall-clock timeout, per-backend concurrency caps; enforce before dispatch.
- Stop conditions: hash mismatch, policy denial, unsupported capability, health-check failure, kill-switch engaged, missing model path.

## Migration Plan (Ordered)
1. **Contract Artifact (this file)**: Define task contract, backend kinds, governance hooks, stop conditions, and acceptance tests.
2. **Task Contract Types**: Implement canonical request/response/hashing in shared types; add unit tests for determinism and evidence envelopes.
3. **Registry Normalization**: Populate model registry with backend/format/capabilities/dim hashes for MLX, llama.cpp, DeepSeek; enforce routing via registry.
4. **MLX Backend Implementation**: Replace mock wrapper with compiled MLX backend (chat + embeddings), warmup, real dims, mock only via flag.
5. **llama.cpp Backend Implementation**: Manage `llama-server`, add embedding endpoint handling, hash-allowlist binaries, document fallback CLI path.
6. **DeepSeek Backend Implementation**: Add governed chat client; fail-closed embeddings path; cloud policy gates and redaction.
7. **Supervisor Hardening**: Enforce resource limits, kill-switch/write-gate, health/restart, evidence hooks across backends.
8. **Tests and Surface Validation**: Unit tests for contract/hashing; env-gated integration for MLX + llama-server; stubbed DeepSeek tests; TechDebt entries for any skipped live calls. Run Harmonia surface scenario covering mlx + llama + deepseek chat/embeddings.

### Migration Progress
- ✅ Step 1: Contract artifact updated to reflect MLX/llama/DeepSeek surface and governance hooks.
- ✅ Step 2: Canonical request/response types and hashing in MLWorkerCommon with deterministic serialization.
- ✅ Step 3: Model registry normalized with MLX defaults (Qwen3 4B chat, BGE-small embeddings), DeepSeek chat entry, and fail-closed embeddings placeholder.
- ✅ Step 4: MLX backend implemented in-process via `mlx-swift-lm` (chat + embeddings), env-gated integration test added.
- ✅ Step 6 (chat path only): DeepSeek chat backend present with governed hashing/redaction; embeddings intentionally fail closed.
- ✅ Step 5 (partial): Managed `llama-server` lifecycle now started/supervised by WorkerSupervisor with binary hash allowlist + model hash allowlist; server URL injected into workers; warmup call to `/embedding` for readiness.
- ✅ Step 7 (binary guardrails): WorkerSupervisor enforces worker binary hash allowlists before startup; llama-server binary allowlist added.
- ✅ Step 7 (health guard): Basic llama-server health check on `/health` with restart on failure.
- ✅ Step 7 (health/res caps): llama-server health now includes embed probe latency/dimension EWMA, restart/backoff budget, deterministic jitter, wall-time timeouts, and optional RSS cap restart hook; warmup records latency + dimension with hashes.
- ✅ Step 8 (partial): Env-gated integration tests for MLX chat/embed, llama-server chat/embed, DeepSeek chat (stubbed) + fail-closed embed; surface scenario `harmonia-surface --scenario ml-worker-backends` added with governed report output.
- ⬜ Step 5 (remaining): None beyond ongoing tuning; CLI fallback remains stub-tracked only.
- ⬜ Step 8 (remaining): Live (non-stub) DeepSeek/llama surface runs stay env-gated; expand coverage once policies and fixtures are available.

### Environment and Allowlist Expectations
- Worker binaries: `ML_WORKER_BINARY_HASH_ALLOWLIST` (global), `LLAMA_WORKER_BINARY_HASH_ALLOWLIST`, `MLX_WORKER_BINARY_HASH_ALLOWLIST` guard worker process hashes; execution blocks on mismatch.
- Llama server: `LLAMA_SERVER_BINARY_HASH_ALLOWLIST` for server binary; `LLAMA_MODEL_HASH_ALLOWLIST` for GGUF hashes; `LLAMA_SERVER_BINARY`, `LLAMA_SERVER_MODEL/LLAMA_MODEL_PATH`, `LLAMA_SERVER_HOST`, `LLAMA_SERVER_PORT`, `LLAMA_SERVER_EXTRA_ARGS`, `LLAMA_SERVER_URL` (injected into workers), `LLAMA_SERVER_WARMUP_TEXT` (warmup payload).
- Resource caps: `LLAMA_SERVER_RSS_SOFT_CAP_MB` optional soft cap; wall-clock caps enforced via URLSession timeouts; restart on repeated health failures with deterministic backoff seeded by binary/model hash. Warmup logs include binary hash, model hash, warmup latency, and observed embedding dimension.
- DeepSeek: chat supported via OpenAI-compatible API; embeddings fail closed; evidence records request/response hashes and redacted metadata only.
- Surface scenario: `harmonia-surface --scenario ml-worker-backends [--output <path>]` writes a governed JSON report (default `.anigma/receipts/ml-worker-backends.json`). MLX checks gate on `MLX_SURFACE_ENABLE=1` plus `MLX_MODEL_ID_CHAT`/`MLX_MODEL_ID_EMBED`. Llama checks gate on `LLAMA_SERVER_URL` (and optional `LLAMA_MODEL_PATH`/hash allowlists). DeepSeek chat runs offline via `DEEPSEEK_STUB_BODY` (falls back to deterministic stub and `DEEPSEEK_API_KEY` placeholder) and confirms embeddings stay fail-closed.

## Acceptance Tests (per backend)
- **Common**: Deterministic JSON serialization; evidence contains binary/model/RunSpec/input/output hashes; failure leaves no partial artifacts.
- **MLX**: Chat streams tokens; embeddings match model-declared dims; warmup happens once; mock flag OFF by default; env allowlist enforced.
- **llama.cpp**: Server health-checked and restarted on crash; chat + embeddings succeed against tiny GGUF; binary hash matches allowlist; fallback CLI emits stub-tracked warning.
- **DeepSeek**: Chat returns governed response; request/response hashes recorded; embeddings request fails closed with capability error; cloud egress blocked without policy.

## Stop Conditions
- Hash mismatch (binary/model), missing registry entry, unsupported capability, policy denial, health-check failure, kill-switch/write-gate active, or exceeded resource limits MUST abort before backend execution and emit governed error.

## Testing Requirements
- Unit: contract encoding/decoding, canonical hashing, evidence envelope, error mapping.
- Integration: MLX tiny model chat/embed; llama-server chat/embed with tiny GGUF; DeepSeek via stub HTTP server (no real network by default), with live gating via env var if allowed.
- Concurrency: Supervisor handles concurrent chat/embed without data races; bounded queues honored.

## Versioning and Compatibility
- Major: breaking changes to task contract or evidence fields.
- Minor: new optional fields or capabilities (e.g., new sampling params, new backend kind).
- Patch: bug fixes, performance, or stricter validation without interface break.

## Audit Requirements
- Every call produces an evidence head with hashes, timestamps, backend id/version, and policy decision; stored in Accessum ledger.
- Secrets (API keys) never written to receipts; only redacted tokens and hashes appear in artifacts.

---
**Contract Status**: COMPLETE (governed surface defined; MLX/llama/DeepSeek chat wired; env-gated live coverage accepted as sufficient)  
**Last Updated**: 2025-12-30  
**Authority**: Core Governance Layer  
**Implementation**: `Sources/MLWorkerExecutable`, `Sources/HarmoniaModule/Inference`
