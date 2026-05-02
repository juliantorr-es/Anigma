# SURFACE.Phase8.Contracts

## 1. Objective
Establish the canonical wire types and enforcement rules for the Anigma UI Harness. This ensures a "side-door-free" boundary where renderers are untrusted presenters and the core is the sole authority.

## 2. Truth Objects (Portable Truth)

### 2.1 Presentation IR (`PresentationIR`)
The stable, serializable representation of the UI state.
- **ViewTree**: Recursive structure of UI nodes.
- **BindingAtoms**: Data points bound to UI elements.
- **ActionRefs**: Opaque, stable identifiers for allowed user interactions.
- **Constraint**: Must be sufficient for the authority to compute **Schema Reachability** without renderer-side state.

### 2.2 ActionIntent (`ActionIntent`)
The envelope for all renderer-to-core requests.
- **Header**:
    - `SurfaceId`: Minted by authority, bound to window instance.
    - `ActorId`: Authenticated identity.
    - `CapabilityToken`: Reference to active permissions.
- **Payload**:
    - `ActionRef`: The target interaction.
    - `Parameters`: Intent-specific data.
    - `Nonce`: For replay protection.

### 2.3 Receipt (`Receipt`)
The immutable source of truth for "what happened."
- **Status**: `Success`, `Failure`, `Blocked`.
- **Outcome**: Serializable result or error payload.
- **Provenance**: Cryptographic link to the authority decision.
- **LedgerLink**: Pointer to the permanent governance record.

---

## 3. Enforcement Objects (Access Control)

### 3.1 CapabilityToken
- **Permissions**: Set of allowed `ActionIntent` families.
- **Identity**: Bound to `SurfaceId` and `ActorId`.
- **TTL**: Time-bounded validity.

### 3.2 Scopes
- **Semantics**: Constraints on specific capabilities (e.g., `FS.Read: /Users/user/Docs`).
- **Conflict Resolution**: **Deny overrides Allow**. If any scope denies an action, it is blocked.
- **Enforcement**: Validated by `AnigmaClientKit` before routing to core.

---

## 4. Canonical Rules

### 4.1 Serialization
- **Format**: JSON with strict schema validation.
- **Encoding**: Canonical fields only (no extra keys allowed).
- **Versioning**: Semantic versioning in the envelope header; rejects mismatched versions.

### 4.2 Denial Codes
Deterministic failure codes for UI consistency:
- `SCHEMA_UNREACHABLE`: ActionRef not in current IR state.
- `CAPABILITY_DENIED`: Surface/Actor lacks basic permission.
- `SCOPE_VIOLATION`: Specific constraint (e.g., path) rejected it.
- `TRANSPORT_FAILED`: IPC or network layer error.

### 4.3 CI Enforcement
- **Boundary Check**: Renderer targets **MUST NOT** import any core module except `AnigmaClientKit` and pure UI primitives.
- **Verification**: CI script parses `Package.swift` and dependency graphs to assert strict subset property.
