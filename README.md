# Anigma

Anigma is a governance-first, autonomous orchestration platform designed for document processing, cognitive workflows, and local-first data integrity.

## Status

- **Maturity**: Experimental / Research
- **Verification**: P0-003 (Polytropos Phase 0) verified.
- **Validation**: Note that `validate_tiers.py` currently reports 7 architectural boundary violations tracked as P1 debt.

## Core Principles

- **Chain of Evidence**: Git history is treated as verifiable evidence for all cognitive and structural changes.
- **Cognitive Transparency**: Architecture is defined through canonical doctrines in `Docs/`.
- **Local-First**: Orchestration occurs on local machines, with auditable data integrity.

## Documentation

See the [Canonical Doctrine Index](Docs/architecture/DOCTRINE_INDEX.md) for architectural references and system-wide design principles.

## Governance & Debt

Anigma uses a tiered architecture. Known tier-boundary violations are tracked in `Docs/` as architectural debt. PostgreSQL integration requires a local instance.

## License

Anigma is provided under the terms of the repository LICENSE file.
