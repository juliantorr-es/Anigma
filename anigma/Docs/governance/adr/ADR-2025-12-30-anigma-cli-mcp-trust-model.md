# ADR: MCP Trust Model for Anigma CLI (2025-12-30)

## Context
- MCP provides a transport but not a trust model; consent, authorization, and least privilege must be enforced by Anigma CLI.
- External MCP servers can expose tools with side effects; default-deny posture is required to prevent privilege creep.

## Decision
- Default-deny all MCP servers; allowlisting requires pinned hash/signature + policy entry specifying allowed tools, scopes, and quotas.
- Per-call requirements: explicit scope (read/search/write), quota counters (per run and per wall-clock window), approval decision, and receipt logging (request/response hashes, server identity, tool name).
- Redaction: retrieved content is treated as untrusted; outputs are redacted for secrets before storage or downstream calls.
- Execution sandbox: all MCP tool executions run under orchestrator sandbox; shell/file/network capabilities exposed by MCP must be explicitly scoped and approved.
- Override knobs: policy config can set default quotas, allowed scopes per server, and per-agent allowlist; disable MCP entirely via `ANIGMA_MCP_ENABLE=false` (default true).

## Consequences
- Operators gain clear control over which MCP servers are usable and under what limits.
- Receipts provide audit trails per server/tool, aiding incident response and revocation.
- Additional policy configuration surface is required, but prevents silent privilege escalation.

## Compatibility and migration
- Existing non-MCP tools remain unaffected.
- Introducing MCP servers requires populating allowlist entries with hashes/signatures and quotas; runs fail closed if configuration is missing.
- Revocation is handled by removing allowlist entries or rotating hashes; receipts provide evidence for cleanup.

## Acceptance and rollback criteria
- Acceptance: Praxis tests confirm default-deny behavior; allowlisted MCP server executes within scope/quota and emits receipts; redaction is applied to retrieved content.
- Rollback: if MCP paths introduce instability, disable via `ANIGMA_MCP_ENABLE=false` and remove allowlist entries; CLI continues with local tools only.
