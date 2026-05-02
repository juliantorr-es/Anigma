# SURFACE.ExecutorProfileProviding

## Surface Definition
**Surface Name**: ExecutorProfileProviding  
**Authority Boundary**: Core Governance Layer (PolicyRegistry + Accessum evidence)  
**Implementation Location**: Capability Module (HarmoniaModule/Capability/ExecutorProfiles)  
**Lease Required**: Yes - changes to this surface require a surface lease.

## Contract Requirements

### Core Interface
All implementations MUST conform to `ExecutorProfileProviding`:

```swift
public protocol ExecutorProfileProviding: Sendable {
    func listProfiles(trustTier: TrustTier) async throws -> [ExecutorProfileSummary]
    func getProfile(id: String, trustTier: TrustTier) async throws -> ExecutorProfile
    func resolveProfile(
        id: String,
        variantId: String?,
        taskOverrides: ExecutorProfileOverrides?,
        attemptOverrides: ExecutorProfileOverrides?,
        trustTier: TrustTier
    ) async throws -> ResolvedExecutorProfile
    func canUseProfile(id: String, trustTier: TrustTier) async throws -> Bool
}
```

### Executor Profile Schema (Deterministic JSON)
Executor profiles are governed artifacts stored as deterministic JSON. Merge order is:
profile defaults -> variant overrides -> task overrides -> attempt overrides.

```json
{
  "id": "codex.default",
  "version": "1.0.0",
  "displayName": "Codex Default",
  "executorKind": "codex",
  "defaultVariant": "plan",
  "defaults": {
    "modelId": "gpt-5-codex",
    "mlTaskOptions": {
      "seed": 42,
      "maxTokens": 4096,
      "temperature": 0.2,
      "topP": 0.9
    },
    "permissions": ["read_files", "read_repository"],
    "granularCapabilities": ["fs.read.project", "fs.list.directory"],
    "budgets": {
      "maxWallTime": 900,
      "maxTokens": 4096,
      "maxToolCalls": 200,
      "maxRetries": 1
    },
    "governance": {
      "requiredTrustTier": "silver",
      "securityZone": "self_host",
      "allowUnattendedExecution": false,
      "allowGovernedBuild": false
    }
  },
  "variants": [
    {
      "id": "plan",
      "description": "Planning-first, no writes",
      "overrides": {
        "mlTaskOptions": {
          "temperature": 0.1,
          "maxTokens": 2048
        },
        "permissions": ["read_files", "read_repository"],
        "governance": {
          "allowUnattendedExecution": false
        }
      }
    },
    {
      "id": "build",
      "description": "Implementation allowed",
      "overrides": {
        "permissions": ["read_files", "write_files", "modify_code", "read_repository", "write_repository"],
        "granularCapabilities": ["fs.read.project", "fs.write.source", "fs.list.directory"]
      }
    }
  ]
}
```

Schema alignment:
- `permissions` MUST use `HarmoniaModule.Permission` raw values.
- `granularCapabilities` MUST use `AnigmaCore.GranularCapability` raw values.
- `budgets` MUST match `ContractsCore.ContractBudgets` fields and units (seconds for `maxWallTime`).
- `governance.requiredTrustTier` MUST use `AnigmaPrimitives.TrustTier` raw values.
- `governance.securityZone` MUST use `ContractsCore.SecurityZone` raw values.
- `mlTaskOptions` MUST match `ContractsCore.MLTaskOptions` fields.

### Governance Integration
- Profile reads and resolves MUST evaluate `PolicyRegistry` before access.
- All profile resolutions MUST emit Accessum receipts with profile hash, variant id, and override hashes.
- Profiles are immutable; updates require new version ids and new receipts.

### Concurrency Model
- Registry reads MUST be concurrency safe (actor isolation or immutable snapshots).
- Resolve operations MUST be deterministic and free of side effects.
- All public types are Sendable.

### Error Handling
Implementations MUST return deterministic errors:
- `ExecutorProfileError.notFound(id:)`
- `ExecutorProfileError.variantNotFound(id:variantId:)`
- `ExecutorProfileError.accessDenied(reason:)`
- `ExecutorProfileError.invalidSchema(code:message:)`
- `ExecutorProfileError.governanceViolation(code:message:)`

## Stop Conditions
- Policy denial or trust tier mismatch
- Missing profile or variant
- Invalid schema or non-deterministic JSON
- Attempts to override disallowed fields (e.g., elevate trust tier)

## Acceptance Tests
- Deterministic merge order for defaults/variants/overrides.
- Schema validation rejects unknown fields and invalid raw values.
- Trust tier gating blocks profiles above caller tier.
- Resolved profiles produce receipts with stable hashes.

## Migration Plan (Ordered)
1. Contract artifact (this file).
2. Implement registry storage and deterministic JSON normalization.
3. Add resolver that merges defaults/variants/overrides and validates permissions.
4. Wire WorkBoard `startAttempt` to resolve executor profiles.
5. Add unit tests for schema validation and merge determinism.

---
**Contract Status**: DRAFT  
**Last Updated**: 2026-01-01  
**Authority**: Core Governance Layer  
**Implementation**: HarmoniaModule (Executor profile registry)
