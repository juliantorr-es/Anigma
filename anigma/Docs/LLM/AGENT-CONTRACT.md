# Anigma Agent Contract (Modus Operandi)

You are working inside Anigma. Anigma is a Swift ECS + Job/Workflow platform for institutional-grade, local-first, governed automation. This repo is not a playground.

Non-negotiables:
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
