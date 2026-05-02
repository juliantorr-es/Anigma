# ADR: External CLI Wrappers for Anigma CLI (2025-12-30)

## Context
- External agent CLIs (Codex, Claude, Gemini) can provide capabilities, but must run under Anigma governance.
- Unwrapped CLIs might execute commands directly or leak secrets; wrappers must enforce sandboxing and approval.

## Decision
- All external CLIs run only through orchestrator-managed wrappers; direct invocation is prohibited.
- Wrappers force non-interactive/script modes and capture machine-readable output when available (JSON/event streams); otherwise, hash stdout/stderr and record exit code.
- Sandbox defaults: read-only unless policy grants mutations; shell/file/network access requires approvals and RepoIdentity gate success.
- Approvals: defaults require approval for any mutating or networked action; run-mode flags cannot bypass policy.
- Redaction: inputs/outputs are redacted for secrets before storage; suggested commands are treated as data until approved and executed via orchestrator.
- Receipts: each wrapper call records tool name/version, arguments, sandbox mode, approval decision, model/engine id (if applicable), request/response hashes, and any produced artifacts.
- Override knobs: policy can set allowed CLIs, permitted flags, and maximum wall time; environment variable `ANIGMA_EXTERNAL_CLIS_ENABLE=true|false` (default true) to disable integrations globally.

## Consequences
- External CLI usage is auditable and policy-controlled; unexpected shell access is blocked by default.
- Additional wrapper maintenance required to track CLI output schemas and update hashes.
- Operators can disable integrations if stability or security issues arise.

## Compatibility and migration
- Existing local tools remain unaffected.
- Introducing wrappers requires policy entries per CLI and receipt schema alignment; runs fail closed if wrappers are not configured.
- Disabling integrations falls back to core Harmonia/MLWorker toolchain.

## Acceptance and rollback criteria
- Acceptance: Praxis/Surface tests show wrappers running in non-interactive mode, respecting sandbox/approval defaults, emitting receipts with hashed outputs, and redacting secrets.
- Rollback: disable integrations via `ANIGMA_EXTERNAL_CLIS_ENABLE=false` and remove policy entries; core CLI continues to function without external CLIs.
