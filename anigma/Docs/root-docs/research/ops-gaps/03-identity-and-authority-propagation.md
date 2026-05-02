> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Identity and Authority Propagation

**Gap ID:** identity-authority-propagation  
**Severity:** High  
**Scope:** Workload identity, user identity, delegation

## Gap statement

Identity is partially covered, but the system still lacks a complete propagation model for service identity, human identity, delegation, and authority context across boundaries.

## Research evidence

### Industry standards
- **SPIFFE/SPIRE** provide workload identity via short-lived SVIDs.
- **RFC 8693** defines OAuth 2.0 token exchange for delegation and impersonation.
- **W3C Trace Context** and **W3C Baggage** standardize propagation of context metadata.
- **OpenTelemetry** uses those standards for correlation across logs, metrics, and traces.

### Repo research
- `Distributed_Identity_Propagation.md` recommends SPIFFE + OIDC + token exchange.
- `Telemetry_Trace_Patterns.md` and `governance-and-authority-patterns.md` already tie identity to observability and policy.

## What industry does

Modern systems split identity into layers:

- **Workload identity** for services and agents
- **User principal** for humans and delegating callers
- **Propagation context** for request lineage and tenancy

## Recommended solution

Implement a **Principal Context** object carried through every boundary:

- `principal_id`
- `tenant_id`
- `trust_tier`
- `delegation_chain`
- `traceparent`
- `baggage`

Rules:

- use SPIFFE/SPIRE for service-to-service identity
- use OIDC for humans
- use RFC 8693 token exchange at trust boundaries
- strip or minimize identity context when crossing best-effort telemetry paths

## Design constraints

- Identity must be verifiable, not implicit.
- Authority must be versioned and auditable.
- Context must survive async hops without becoming a secret leak.

## Acceptance criteria

- Every request has a principal context.
- Every service can verify workload identity.
- Delegation is explicit and reversible.
- Audit logs can explain who acted, through what authority, and on which resource.