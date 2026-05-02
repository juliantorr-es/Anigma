> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Backpressure and Load Shedding

**Gap ID:** backpressure-load-shedding  
**Severity:** Critical  
**Scope:** Queue management, telemetry, ingestion

## Gap statement

Harmonia V3 lacks a formal policy for what happens when queues fill up. Without bounded queues and load shedding, the system can turn a temporary spike into a cascading failure.

## Research evidence

### Industry standards
- **Reactive Streams:** explicitly standardizes asynchronous streams with non-blocking back pressure and bounded queues.
- **OpenTelemetry sampling:** tail sampling can protect the telemetry pipeline, but it is stateful and can become a bottleneck itself.

### Official documentation
- **OpenTelemetry sampling docs:** large systems often need tail sampling, sometimes in combination with head sampling, to protect the pipeline from overload.
- **Reactive Streams spec:** fast producers must not overwhelm consumers; backpressure is the governing mechanism.

### Repo research
- `Hardware_Saturation_Strategies.md` calls out the need for streaming handshakes and bounded `AsyncStream` buffers.
- `sli-slo-error-budget-best-practices.md` frames reliability as a budgeted resource.

## Why it matters

When queues are unbounded:

- memory usage grows without limit
- latency rises nonlinearly
- telemetry and user work compete for the same resources
- failures become system-wide instead of isolated

## Recommended architectural response

Implement a multi-level backpressure policy:

1. **Soft pressure:** slow ingestion when queue depth crosses a warning threshold.
2. **Hard pressure:** reject or defer low-priority work when critical queues saturate.
3. **Load shedding:** drop best-effort telemetry or background work first.
4. **Telemetry protection:** sample more aggressively when export pressure rises.

Suggested policy hierarchy:

| Work class | Priority | Action under pressure |
|---|---:|---|
| User-facing orchestration | highest | protect, queue briefly |
| Execution work | high | defer with bound |
| Background analysis | medium | batch or slow |
| Telemetry / traces | low | sample, shed, or route to cold storage |

## Design constraints

- No queue may grow without a bound.
- Every producer must know how backpressure is signaled.
- Shedding must be observable and auditable.

## Acceptance criteria

- All major async streams have bounded buffers.
- Queue depth metrics exist and are alertable.
- The system can shed low-priority work safely.
- Telemetry pipelines degrade gracefully instead of failing catastrophically.