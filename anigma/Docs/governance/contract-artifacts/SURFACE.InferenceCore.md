# SURFACE: InferenceCore (InferencePlane)

## Authority Boundary
- **Authority owner**: Host/daemon (governed runtime).
- **Client boundary**: Capability modules request inference via contract interface.
- **Storage**: No direct storage access; all inputs/outputs are passed by value.

## Surface API
- **Protocol**: `InferencePlane`
- **Request**: `InferenceRequest` (task kind, input, model id, options, correlation id)
- **Response**: `InferenceResponse` (output, usage, metadata)
- **Errors**: `InferenceError` (unavailable, invalidRequest, executionFailed)

## Concurrency Model
- `InferencePlane` is `Sendable`.
- Implementations must be actor-isolated or explicitly thread-safe.
- No shared mutable state without actor isolation.

## Stop Conditions
- Requests rejected when inputs exceed configured limits.
- Implementations must fail closed on unknown task kinds.
- Errors must be deterministic and classification-stable.

## Acceptance Tests
- `InferencePlane` round-trip returns output for valid requests.
- Invalid requests return `InferenceError.invalidRequest`.
- Unknown task kind returns `InferenceError.invalidRequest`.
- Concurrency: multiple concurrent requests do not race or corrupt state.

## Migration Plan
- Phase 1: Introduce `InferenceCore` target and adapter in `AnigmaCore`.
- Phase 2: Update AI nodes to use `InferencePlane` instead of placeholder logic.
- Phase 3: Extend clients and ML worker adapters to satisfy `InferencePlane`.
