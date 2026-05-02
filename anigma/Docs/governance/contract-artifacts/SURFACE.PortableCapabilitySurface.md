# SURFACE.PortableCapabilitySurface

## Surface Definition

**Surface Name**: PortableCapabilitySurface  
**Authority Boundary**: Core Governance Layer (ContractsCore) + Capability Modules (providers)  
**Implementation Location**: `Sources/ContractsCore/PortableCapabilities/`  
**Lease Required**: Yes – required for cross-module adoption/migration

## Surface API

### Provider Spine (Tier 1/2 boundary)

- `CapabilityProvider` – provider metadata + availability contract (no platform imports)
- `CapabilityProviderRegistry` – runtime provider registry with explicit selection policies

### Capability Contracts (Tier 1 interfaces)

- `PDFRenderingProviding` – pages-to-bitmap, metadata, text extraction, selection/annotation geometry
- `PDFSurgeryProviding` – merge/split/linearize/encrypt/decrypt/validate via `PDFSurgeryRequest`
- `GitProviding` – clone/fetch/status/diff/log + workspace-oriented operations (structured results)
- `TextShapingProviding` – shaping + fallback description for deterministic text layout
- `CompressionProviding` – compress/decompress via algorithm id (`CompressionAlgorithm`)

### Data Model Constraints

- All request/response models are `Sendable` + `Codable`
- Geometry uses canonical `BoundingBoxRef` where applicable
- No C headers, build flags, or platform conditionals in Tier 1 contracts

## Concurrency Model

- Providers are `Actor`-isolated (`CapabilityProvider` refinement).
- `CapabilityProviderRegistry` is an `actor` and resolves providers using explicit selection policy:
  - `.requireDefault`, `.defaultOrBestAvailable`, `.bestAvailable`
- Capability calls are `async` and must not leak non-Sendable OS objects across boundaries.

## Stop Conditions

- Registry resolution fails with deterministic errors when:
  - no providers are registered
  - a named provider id is missing
  - no providers are available under the requested selection policy
- Providers fail with `CapabilityError` for unsupported operations or invalid inputs.

## Acceptance Tests

1. Registry tests validate:
   - default provider selection
   - best-available fallback when default is unavailable
   - deterministic error cases for missing providers
2. All new API types compile under Swift 6 strict concurrency.

## Migration Plan

1. Phase 1/2 (this surface): land contracts + provider spine only (no native deps).
2. Phase 3+: add platform providers (PDFKit/CoreText on Apple; permissive libs elsewhere) behind these protocols.
3. Phase 3+: incrementally swap call sites to resolve providers from the registry.

---

**Contract Status**: ACTIVE  
**Last Updated**: 2026-01-01  
**Authority**: Core Governance Layer + Capability Modules

