# Memory Budget Policy

Anigma treats memory usage as a policy configuration, not a hidden heuristic. The inference engine MUST log its budget decisions so performance debugging stays evidence-based.

## Budget inputs

- `available_memory` or configured cap.
- `per_job_cap`.
- `per_session_cap`.
- `max_context_length`.
- `max_concurrency`.

## Budget outputs

- Selected backend (MLX, Core ML, llama.cpp, etc.).
- Model variant or quantization level.
- Cache strategy (full KV, compressed, sliding window, chunked context).
- Fallback behavior (truncate, summarize, refuse, offload).

## Events

Each run records a `memory_decision` event containing:

- configured caps.
- estimated cache growth per token.
- chosen cache strategy.
- enforced context length.
- allowed concurrency.

Failures due to memory MUST include predicted-vs-actual comparisons.
