> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Distributed Identity & Principal Propagation

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Context:** Zero Trust Institutional Identity

## Executive Summary

In a networked, multi-tenant AI environment, identity must be verifiable, immutable, and propagated across service boundaries without trust-loss. Research into **Zero Trust Architecture (ZTA)** and **SPIFFE/SPIRE** indicates that Anigma should move away from static API keys toward a model of **Dynamic Workload Identity** where every agent, service, and user principal is cryptographically verified for every operation.

## 1. Industry Standards for Identity

### Workload Identity (SPIFFE/SPIRE)
The industry standard for service-to-service authentication is the **Secure Production Identity Framework For Everyone (SPIFFE)**.
- **SVID (SPIFFE Verifiable Identity Document)**: Every process (the Daemon, the App, the ML-Worker) is issued a short-lived, rotated SVID (X.509 certificate).
- **No Secrets**: Services authenticate via mTLS based on their identity, eliminating the need for hardcoded `.env` secrets or API keys.

### User Principal Propagation (JWT + OIDC)
For human users, **OAuth 2.0 / OpenID Connect (OIDC)** remains the gold standard.
- **Token Exchange (RFC 8693)**: The backend (Sidecar) should exchange the external user token (e.g., from an institutional OIDC provider) for a scoped, internal "Downstream Principal Token" that contains the `ProjectID` and `TrustTier`.

## 2. Academic Research on Identity Propagation (2024-2026)

Recent studies (e.g., *“Zero Trust Implementation in AI-SaaS Ecosystems”*) highlight:
- **NHI (Non-Human Identity) Governance**: AI agents now outnumber humans in microservices. The research recommends treating agents as "Identified Principals" with **Just-in-Time (JIT)** privileges.
- **Unbiased Trust Scores**: Future systems should incorporate a "Confidence Score" into the identity token based on behavioral telemetry (e.g., "Is this agent behaving according to its governance policy?").
- **Cryptographic Envelopes**: Embedding identity directly into async event payloads (e.g., on a Redis Pub/Sub bus) to ensure that even asynchronous tasks remain auditable and verifiable.

## 3. Identity vs. Performance

- **The Token Tax**: Parsing large JWTs for every call can add latency.
- **Pattern Solution**: Use "Token-Aware Sidecars" (like Envoy) to validate tokens at the edge and then propagate a lightweight, bit-packed **Principal Context** to the internal authorities (Tier 2).

## 4. Strategic Recommendation for Anigma

1.  **Workload Identity**: Implement **SPIRE** for the Anigma Daemon and ML-Worker to ensure they can securely communicate without pre-shared secrets.
2.  **Principle-Aware Concurrency**: Flow the **`Principal`** from the `SidecarBridge` into the Swift `@TaskLocal` context, ensuring that every database write or inference call is automatically tagged with the originator.
3.  **Institutional Federation**: Support OIDC federation so institutions can map their existing LDAP/ActiveDirectory groups directly to Anigma **`TrustTiers`** and **`ProjectIDs`**.

## Conclusion

Identity in Anigma is not just about "Logging In." It is the cryptographic thread that links a specific human or agent to an **Inference Receipt**. By adopting SPIFFE and OIDC-based token exchange, Anigma ensures that its "Radical Transparency" goal is backed by industry-standard Zero Trust security.