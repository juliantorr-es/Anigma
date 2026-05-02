# Anigma Agent Contract (Modus Operandi)

## Mandatory: TD + Sidecar Workflow

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td

Agents should also read [AGENT-SKILL-PACK.md](./AGENT-SKILL-PACK.md) when work involves implementation, review, research, documentation synchronization, build triage, or handoff. The skill pack defines reusable procedures and output contracts so Copilot, Vibe/Mistral, Gemini CLI, Codex, and future agents compose through the same TD workflow.

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

You are working inside Anigma. Anigma is a Swift ECS + Job/Workflow platform for institutional-grade, local-first, governed automation. This repo is not a playground.

Non-negotiables:
- **Saturation First**: Every patch or proposal must prioritize **Hardware Saturation**. Any introduction of synchronous CPU-GPU waits or non-SoA data layouts is a regression.
- AnigmaCore is the only ECS and Job/Workflow model. Do not create parallel ECS or pipeline frameworks.
- No Python or Node.js at runtime. Do not shell out to python/node in production code. JS/TS is build-time only.
- Follow strict boundaries: App Shells > Domain Modules > AnigmaCore/DatabaseCore. No circular dependencies. No generic infra in modules.
- World and Scheduler are actors. Systems are stateless. State lives in components. Components must be Sendable + Codable.
- Governance is mandatory. Actions are proposed, evaluated (Security/Doctrine/Research), gated (Write Gate), logged (CCTV), and may be denied.

Before you change anything:
- Read Docs/AnigmaConstitution.md, Docs/ImplementationRules.md, Docs/Roadmap.md, and relevant ADRs.
- Search the codebase for existing abstractions. Prefer convergence. No reinvention.
- If your change is architectural, write/update an ADR before code.

How work must flow:
- Use the Harmonia governed path for changes where applicable. Do not bypass blockages.
- If blocked, read the CCTV/governance status and address the reason (research debt, doctrine violation, security tier).
- Track stubs and incomplete work via STUB_TRACK + Docs/TechDebt.md.

Output discipline:
- Every meaningful change must leave audit-friendly breadcrumbs: rationale, references (ADR/doc), tests, and updated debt tracking if needed.
