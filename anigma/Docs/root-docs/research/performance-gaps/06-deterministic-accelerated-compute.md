> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Deterministic Accelerated Compute

**Gap ID:** deterministic-accelerated-compute  
**Severity:** High  
**Scope:** GPU/ANE correctness, receipts, reproducibility

## Gap statement

Harmonia V3 wants accelerated compute, but acceleration can introduce nondeterminism through floating-point ordering, kernel variation, and device-specific optimizations. The system needs a deterministic mode for receipts, tests, and auditability.

## Research evidence

### Industry standards
- **Apple Core ML:** supports CPU, GPU, and Neural Engine execution with on-device optimization and model provenance.
- **Metal Performance Shaders:** kernels are tuned per GPU family, which implies device-specific execution details must be handled carefully.

### Official documentation
- **Core ML docs:** focuses on optimizing on-device performance across CPU/GPU/ANE.
- **Core ML conversion and packaging guidance:** supports reproducible model packaging and verification paths.

### Repo research
- `Hardware_Saturation_Gap_Analysis.md` identifies receipt determinism as a missing guard.
- `High_Performance_Inference.md` emphasizes provenance and inference receipts.

### Academic basis
- Parallel floating-point reductions are order-dependent.
- Reproducible numerical computing requires fixed reduction order, constrained precision, or explicit tolerance models.

## Why it matters

If accelerated compute is not deterministic enough:

- receipts become harder to trust
- tests become flaky across hardware generations
- regression detection becomes noisy
- audit trails lose meaning

## Recommended architectural response

Introduce a deterministic compute contract:

- stable seeds and explicit precision mode
- fixed reduction order for sensitive paths
- compare outputs with tolerance when exact equality is impossible
- route receipt-signing paths through deterministic fallbacks when required

Recommended modes:

| Mode | Purpose |
|---|---|
| Deterministic | receipts, tests, audits |
| Performance | normal end-user execution |
| Diagnostic | deep comparison and profiling |

## Design constraints

- Deterministic paths must be opt-in where they cost more.
- Receipts must record hardware, precision, and version metadata.
- Any nondeterministic path must be detectable in logs or tests.

## Acceptance criteria

- Deterministic mode exists for critical paths.
- Receipt output is stable across supported hardware where required.
- Test harnesses can compare accelerated and CPU fallback paths.
- Hardware-specific variation is captured in metadata.