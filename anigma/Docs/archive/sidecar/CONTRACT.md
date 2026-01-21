# Anigma Sidecar Daemon Contract (anigmad)

Contract Status: APPROVED

This document is the production contract for the Anigma Sidecar Daemon ("anigmad"). It defines the stable API surface, determinism guarantees, security model, storage model, and operational expectations. If implementation diverges from this contract, the implementation is wrong.

## Purpose

anigmad is a local-first, open-source background service that exposes governed, deterministic capability execution to multiple client applications (CLI, GUI, web) on the same machine. The host application remains a coordinator and UX surface. anigmad is the capability reactor.

## Non-Goals

anigmad does not promise kernel-level security, physical tamper resistance, or side-channel resistance. It does not promise perfect GPU policing in the initial production release. It does not promise zero-downtime upgrades in the initial production release.

## Process Model

anigmad is a coordinator process plus isolated worker processes.

The coordinator owns the gRPC server, capability token minting and validation, request validation, job queueing, resource accounting, receipt generation, vault operations, and telemetry emission.

Workers execute heavy or crash-prone operations. Workers are invoked as subprocesses with a minimal environment. Workers communicate with the coordinator via stdin/stdout using a deterministic job protocol. Worker failures must not crash the coordinator.

## IPC and Transport

Default transport is gRPC over a Unix domain socket (UDS). TCP is optional and off by default.

UDS default path is per-user.

On macOS, the default socket path is:
  ~/Library/Caches/anigma/anigmad.sock

On Linux, the default socket path is:
  $XDG_RUNTIME_DIR/anigmad.sock
If XDG_RUNTIME_DIR is not set, fallback to:
  ~/.cache/anigma/anigmad.sock

When TCP is enabled, the daemon binds to 127.0.0.1 only. TCP is never enabled silently.

## Authentication and Authorization

Default authentication is capability tokens minted by the daemon. Tokens are scoped. Tokens expire. Tokens are bound to a client identity.

The daemon provides an OpenSession endpoint that returns a capability token with an explicit scope set. The coordinator validates token scope for every request and enforces per-scope quotas.

JWT is not used in the default mode. mTLS is not used in the default mode. Both may exist as optional modes later, but are out of scope for the minimal vertical slice.

## Job-Oriented API

The public API is job-oriented, not tool-oriented. Clients request outcomes (job kinds), not direct tool execution.

A JobSpec contains:
  kind: a stable job kind identifier (string)
  config: deterministic config encoding (canonical JSON or canonical CBOR)
  inputs: artifact references (content-addressed)
  requested_outputs: optional hints, not directives that weaken determinism

The daemon maps a job kind to an internal worker implementation. Tools and versions are recorded in receipts, not embedded in the API contract.

## Determinism and Receipts

Determinism is non-negotiable.

Every operation that mutates state, produces artifacts, or consumes artifacts must produce a receipt.

A receipt must include, at minimum:
  request id and nonce
  client identity
  capability scope used
  input artifact hashes
  normalized config hash
  toolchain identity (tool name, version, build hash or package hash)
  resource limits applied
  start and end timestamps
  output artifact hashes
  parent receipt hash (for chaining)
  policy decisions applied (allow/deny + reason code)

Receipts are stored in a content-addressed receipt store and are chain-verifiable across restarts.

If an operation fails, a failure receipt is still emitted. Failure receipts include captured stderr/stdout references as artifacts when safe and allowed by policy.

## Vault and Storage

Artifacts are content-addressed and stored in a per-user vault.

Default paths:
  Vault:    ~/.anigma/vault
  Receipts: ~/.anigma/receipts
  DB:       ~/.anigma/anigma.db
  Logs:     ~/.anigma/logs

All returned artifact references are content hashes. Retrieval is by hash. Listing is paginated.

Disk quota is enforced by the coordinator against the vault. When quotas are exceeded, ingestion fails deterministically with a documented error code. Optional GC may exist later, but is not required for the minimal vertical slice.

## Governance Enforcement

The daemon must enforce governance policies via GovernanceCore. Policy enforcement is applied at request validation time and again at execution time when necessary.

In the minimal vertical slice, governance enforcement may be limited to a strict allowlist of operations plus basic quota enforcement, but receipts must still record policy decisions.

## Resource Management

The coordinator enforces resource limits honestly and incrementally.

In the initial production release:
  concurrency limits per client
  concurrency limits per job kind
  worker subprocess count limits
  rlimits for worker subprocesses (CPU time, address space where feasible, open files)
  disk quota enforcement on the vault

GPU scheduling exists as a coordinator policy, not as an OS-level guarantee in the initial release. The daemon may limit concurrent GPU jobs to reduce contention.

## Stability Requirements

Cursed input survival is required. The daemon must not crash when processing malformed PDFs, malformed media, or malformed documents. Jobs may fail, but failures must be contained to workers and must emit failure receipts.

Worker crashes must be detected and recovered without daemon restart.

## Observability

The daemon emits telemetry events to TelemetryCore. Telemetry emission must not block request handling. Telemetry retention is governed by policy.

Logs are local by default. Remote log shipping is out of scope for the minimal vertical slice.

## Versioning and Compatibility

The gRPC API is versioned via a semantic API version reported by GetStatus. Backward-incompatible changes require a major version bump.

Job kinds are versioned. A job kind identifier is stable. Configuration schema versioning is explicit in the config object and is hashed as part of determinism.

## Minimal Vertical Slice Acceptance

The implementation is considered minimally correct only when all steps below succeed with receipts and chain verification.

The minimal slice is:
  start daemon with UDS transport
  open session and mint capability token
  ingest artifact and emit receipt
  submit job kind artifact.copy
  execute job in worker subprocess
  store output artifact and emit receipt
  retrieve output artifact by hash
  verify receipt chain across daemon restart

If any step succeeds without a receipt, the step fails the contract.
