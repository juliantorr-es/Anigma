# Anigma Platform Model

Anigma is the truth. Platforms are adapters.

## Truth vs adapters

Truth = contracts, engines, artifacts you version/test/replay/audit without caring which OS you run on.  
Adapters = renderers, inference backends, storage targets, device-specific UIs that translate truth into native execution.

Truth includes:

- Job/run schema, ledger semantics, capability model.
- UI schema, provenance hooks, action runtime contracts.
- Artifact formats (GGUF/ONNX/CoreML/etc.), deterministic hashing, replay pathways.
- Governance invariants (stable runId, capability gating, audit trails, retention controls).

Adapters include:

- UI renderers (SwiftUI/AppKit, COSMIC/libcosmic, WinUI/Avalonia, terminal shells).
- Compute backends (MLX, llama.cpp, MLC LLM, ONNX Runtime, Core ML).
- Platform plumbing (windowing, file pickers, audio/IME, sandboxing).

Engines consume truth contracts, produce artifacts, and never import platform APIs. Adapters consume engine outputs and implement the platform mechanics.

## Capability-gated UI

The UI schema expresses declarative nodes with capability requirements. Renderers map nodes to native controls but ask the kernel/writer for permission before acting. Capability gating ensures privileged actions exist in the schema yet only run when approved. The schema node, capability, implementation, and ledger entry become verifiable evidence.

## Determinism + replay

A portable system must replay. Ledger-backed runs, content hashes, and artifact provenance let you reproduce work on any platform, even if adapters behave differently internally. Replays must validate hashes before side effects. Non-deterministic adapters log “non_repro_reason” and scope outputs accordingly.

## Documentation pattern

For every truth claim provide:

1. The invariants (what must remain true).
2. The evidence commands/paths/logs that back it.
3. The validation hook (CI gate, Docs/status stamp) showing “last verified.”

Example invariant: “No action runs unless capability gate + audit event exist.” Evidence: CLI command to trigger policy check, artifact path in Docs/status, log sample with actionId/capability.

## Enforcement

- Engines compile without importing platform UI frameworks.
- Renderers depend only on schema + action/api bridges.
- Backends register through capability discovery, not hardcoded conditionals.
- Docs/status validator ensures referenced paths/commands exist and records `last_verified`.

## Outcome

Anigma becomes a platform-agnostic truth layer. Platforms are runtime choices, not rewrite taxes. Call it the “Platform Model” and document the contracts, adapters, invariants, and evidence so every change must produce verifiable artifacts before landing.
