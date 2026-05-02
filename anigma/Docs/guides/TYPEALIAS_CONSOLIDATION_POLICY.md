# Typealias Consolidation Policy

Status: planning and execution policy. TD remains the source of truth for live task status, blockers, and approval.

Last reviewed: 2026-04-10

Baseline: `TYPEALIAS_AUDIT.md`

## Summary

The typealias audit found 300 typealias definitions across 237 unique alias names. This is not inherently bad. Typealiases are useful when they clarify a role, bridge platform-specific APIs behind a deliberate abstraction, or satisfy generic/protocol requirements.

The risk is semantic drift: the same alias name meaning different things across modules, or bridge aliases hiding that a shared contract lives in the wrong module.

For Anigma, typealias drift is a backend stabilization issue because it:

- hides real dependency boundaries
- creates misleading public surfaces
- lets modules appear compatible when they are not
- makes static plugin contracts harder to define
- increases integration risk during de-stubbing and backend wiring
- can increase exposed compilation surface when aliases force large module imports

## Research Backing

Swift's API Design Guidelines emphasize clarity at the use site and role-based naming. Generic names such as `Input` and `Output` are acceptable only when the surrounding generic/protocol context makes their role unambiguous. When a module exports `Input` for unrelated domain concepts, it violates the clarity goal.

Swift typealiases are aliases, not new nominal types. They do not create new semantic boundaries or protocol conformances. Therefore, aliases should not be used as a substitute for real contracts, domain DTOs, or new nominal types when identity matters.

SwiftPM target boundaries are Anigma's practical enforcement tool. If a module introduces an alias only to avoid importing a large implementation target, that is a signal to move the shared type into a smaller contract target rather than preserve the alias.

For heterogeneous `Codable` values, the Swift community guidance is that dynamic data must be expressed through a deliberate JSON/AnyCodable-style representation. Multiple `AnyCodable` aliases to different implementations create data-contract ambiguity and should converge on one low-level representation.

## Swift Guideline Compliance Gap

This audit should be treated as Swift API-design remediation, not just cosmetic cleanup.

| Swift principle | Current Anigma gap | Required correction |
| --- | --- | --- |
| Clarity at the point of use | `Input` and `Output` mean different domain types across `RendererKit`, `HarmoniaModule`, and `AnigmaCore` | Replace public generic aliases with domain-specific DTO names or scoped associated types |
| Promote clear usage, omit only needless words | `AnyCodable` points to different implementations in `DocumentRenderKit` and `AnigmaDaemonCore` | Establish one canonical dynamic payload type for serialized/wire boundaries |
| Share behavior through contracts instead of concrete coupling | High fan-out modules depend directly on concrete feature implementations | Move shared behavior to lightweight protocol/contract targets and invert dependencies |
| Compensate for weak type information | Aliases such as `ErrorCode = Int32` and `ErrorCode = amfp_error_t` preserve weak primitive semantics | Introduce nominal structs/enums for domain errors, security-sensitive identifiers, and persistence keys |
| Design boundaries holistically | `HarmoniaV2Surface` and bridge aliases such as `AuditLog = AuditLogManager` expose implementation funnels as APIs | Split contracts from implementations and retire bridge aliases into the correct contract owner |

The practical rule is: if an alias makes a signature shorter but forces the reader to chase the module graph to understand the real type, it is not aligned with Swift API design.

## Classification

| Class | Meaning | Policy |
| --- | --- | --- |
| Role Alias | A local associated type alias such as `Input` inside a protocol/contract context | Allowed if scoped and unambiguous |
| Domain Alias | Alias gives a meaningful domain role, such as `ReceiptID = String` | Prefer nominal wrapper when identity/security matters |
| Bridge Alias | Alias points at another module's concrete type | Temporary only; usually indicates missing contract extraction |
| Platform Alias | Alias maps AppKit/UIKit/SwiftUI types across platforms | Must live in one platform abstraction layer |
| Type-Erasure Alias | Alias to `AnyCodable`, `AnyHashable`, erased callbacks, or existential wrappers | Must be canonicalized when serialized or shared across modules |
| Primitive Alias | Alias maps domain concepts to weak primitives such as `Int32`, `String`, or C shims | Replace with nominal Swift types when identity, error semantics, or safety matters |
| Drift Alias | Same alias name maps to different targets across modules | Must be renamed, scoped, or replaced with contracts |

## Current Findings From The Audit

### 1. Generic `Input` / `Output`

Observed aliases include:

- `RendererKit.Input = ProfileArtifact`
- `RendererKit.Input = TabularIR`
- `HarmoniaModule.Input = BuildRequest`
- `AnigmaCore.Input = PDFIngestInput`
- `AnigmaCore.Input = HybridSearchInput`
- `AnigmaCore.Input = IndexEmbeddingsInput`
- `AnigmaCore.Input = PDFRenderRequest`

Policy:

- `Input` and `Output` are allowed only inside a protocol, generic contract, or nested type where the declaring context makes the role clear.
- Public module-level `Input` / `Output` aliases are not allowed.
- Cross-module contracts should use domain-specific names such as `PDFIngestInput`, `HybridSearchResult`, or protocol associated types such as `ContractInput`.

### 2. Bridge Aliases

Examples:

- `MigrationResult = AnigmaPrimitives.MigrationResult`
- `AuditLog = AuditLogManager`
- `ToolProgressCallback = AnigmaPrimitives.ToolProgressCallback`

Policy:

- Bridge aliases should be treated as migration markers.
- If more than one module needs the type, move the type to the correct contract/foundation target.
- If only one module needs the type, import the owning contract directly or rename the local concept.

### 3. Platform Aliases

Examples:

- `UIImage = NSImage`
- `UIImage = UIKit.UIImage`
- `PlatformView = NSView`
- `PlatformView = UIView`

Policy:

- Platform aliases should not be scattered through backend/domain modules.
- Platform abstraction belongs in a single UI/platform module, not in backend stabilization surfaces.
- Backend modules should not depend on UIKit/AppKit aliases.

### 4. `AnyCodable`

Examples:

- `DocumentRenderKit.AnyCodable = DocumentIRKit.AnyCodable`
- `AnigmaDaemonCore.AnyCodable = AnigmaCore.AnyCodable`

Policy:

- Anigma needs one canonical heterogeneous JSON value representation.
- The canonical type should live low enough for contracts and daemon surfaces to use without importing feature implementations.
- Candidate location: `AnigmaPrimitives` if it is truly low-level, or `ContractsCore` if it is primarily a wire-contract type.
- Multiple `AnyCodable` aliases are not allowed in durable/serialized boundaries.

### 5. Primitive Alias Drift

Examples:

- `ErrorCode = Int32`
- `ErrorCode = amfp_error_t`

Policy:

- Error, identifier, persistence-key, and security-sensitive values should not cross module boundaries as raw primitive aliases.
- Use Swift enums or nominal wrappers when the domain has real semantics.
- C interop aliases may remain at shim boundaries, but they should be converted before entering domain/backend contracts.

### 6. Concrete Funnel Aliases

Examples:

- `AuditLog = AuditLogManager`
- high-dependency surfaces such as `HarmoniaV2Surface` exposing implementation-dependent DTOs

Policy:

- If callers need behavior, expose a protocol in `ContractsCore` or the narrowest valid contract target.
- If callers need data, expose a DTO owned by a contract/foundation target.
- Do not use typealiases to make concrete managers look like stable interfaces.

## Consolidation Rules

1. Do not use typealiases to hide dependency violations.
2. Do not export generic names like `Input`, `Output`, `State`, `Context`, or `Result` at module scope.
3. Bridge aliases must include a removal path or be replaced with a real contract extraction task.
4. Serialized/wire-facing aliases must resolve to one canonical type.
5. Platform aliases must be isolated in a platform abstraction module.
6. If changing an alias would alter persistence, wire format, or public API, require TD acceptance criteria and review evidence.
7. Prefer nominal wrappers for IDs, security-sensitive values, persistence keys, and cross-module business identities.
8. Prefer protocol associated types for local generic roles when the role is tied to a contract.
9. Convert C/shim aliases to domain-safe Swift types before they enter backend contracts.
10. Require protocol or DTO extraction when an alias points at a concrete manager, runtime, or implementation-heavy module.

## Migration Plan

### Phase 1: Canonicalize Type-Erasure And Wire Values

- Decide canonical `AnyCodable` location.
- Replace module-local `AnyCodable` aliases on durable/wire surfaces.
- Add tests or fixtures for JSON compatibility if serialized data is affected.

### Phase 2: Remove Public Generic Drift

- Inventory public `Input` and `Output` aliases.
- Keep only scoped associated-type aliases inside contracts.
- Rename or expose domain-specific DTOs for cross-module APIs.

### Phase 3: Retire Bridge Aliases

- For each bridge alias, decide:
  - move shared type to contract/foundation module
  - import owning contract directly
  - keep as temporary with TD removal date

### Phase 4: Isolate Platform Aliases

- Move UIKit/AppKit aliases into a single platform abstraction target.
- Prevent backend/domain modules from defining UI platform aliases.

### Phase 5: Replace Weak Primitive Aliases

- Inventory primitive aliases that cross module boundaries.
- Replace domain errors with Swift `Error` enums or nominal error-code wrappers.
- Keep C aliases only inside shim targets and convert at the boundary.

### Phase 6: Enforce

- Add a typealias audit refresh command or report.
- Flag drift aliases with multiple target types.
- Flag public module-level `Input` / `Output` aliases.
- Flag `AnyCodable` aliases that do not point to the canonical type.
- Flag platform aliases outside the approved platform abstraction target.
- Flag primitive aliases that cross domain/backend contract boundaries.

## Relationship To Backend Stabilization

This policy supports `td-f9576a` because aliases that hide broad imports or semantic drift increase compilation-surface risk.

It also supports `td-a0f014` because static plugin architecture requires stable contracts. Feature wiring targets should register against canonical contracts, not module-local aliases that point at different implementations.

## Sources

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift Reference Manual: Declarations](https://docs.swift.org/swift-book/ReferenceManual/Declarations.html)
- [Swift Package Manager PackageDescription](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)
- [Swift Forums: Serializing a dictionary with any codable values](https://forums.swift.org/t/serializing-a-dictionary-with-any-codable-values/16676)
