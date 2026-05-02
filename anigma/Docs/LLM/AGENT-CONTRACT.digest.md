# Anigma Agent Contract Digest

## Mandatory: TD + Sidecar Workflow

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td

1. Start of every conversation/context window (or after `/clear`):
   ```bash
   td usage --new-session
   ```
2. Use a quiet status check after setup:
   ```bash
   td usage -q
   ```
3. Start implementation on a tracked issue:
   ```bash
   td start <issue-id>
   # Multi-issue work:
   td ws start "<work-session-name>"
   td ws tag <issue-id> [issue-id...]
   ```
4. Log progress as you go:
   ```bash
   td log "<progress note>"
   # or: td ws log "<progress note>"
   ```
5. Before ending context, record handoff (required):
   ```bash
   td handoff <issue-id> \
     --done "<completed and tested work>" \
     --remaining "<specific pending tasks>" \
     --decision "<why this approach was chosen>" \
     --uncertain "<open questions>"
   # or: td ws handoff
   ```
6. Completion flow: implementer runs `td review <issue-id>`; a different session runs `td approve <issue-id>`.
7. Never use `td close` for completed implementation work. Use `td close` only for admin closures (duplicate/won't-fix/cleanup).
8. Do not start a new session mid-work unless you are intentionally beginning a new context.

This digest summarizes the non-negotiable rules for any AI agent operating within the Anigma repository. This contract is mechanically enforced.

## Core Modus Operandi

*   **Single ECS/Job Model**: `AnigmaCore` is the *only* source for Entity-Component-System (ECS) and Job/Workflow models. No parallel frameworks allowed.
*   **No Python/Node at Runtime**: Strictly forbidden to shell out to Python or Node.js in production code. JS/TS is for build-time static assets only.
*   **Strict Layer Boundaries**: Adhere to App Shells > Domain Modules > AnigmaCore/DatabaseCore. No circular dependencies, no generic infra in modules.
*   **Actor-Based Concurrency**: `World` and `Scheduler` are actors. Systems are stateless. State lives in `Component`s, which must be `Sendable` + `Codable`.
*   **Mandatory Governance**: All actions *must* be proposed via a structured `ActionProposal` (Docs/LLM/ActionProposal.schema.json), evaluated by Harmonia's governance (Security/Doctrine/Research), gated (Write Gate), logged (CCTV), and may be denied. Do NOT bypass.
*   **Persistence is Key**: Any significant write operation requires a `CCTVEvent` record (Docs/LLM/CCTVEvent.schema.json) for auditability.
*   **Default Deny Capabilities**: Agent runtime starts with no write capability. To get write capability, a structured `ActionProposal` must pass policy checks.

## How Work Must Flow

Harmonia is the *only* blessed tool that performs writes. It requires a valid `ActionProposal` (validated) before touching the filesystem. It emits a validated `CCTVEvent` for every decision and write.

## Non-Compliance

Any attempt to violate these rules will result in mechanical blocking by Harmonia's write gate or CI, and will be logged as a `CCTVEvent`.
