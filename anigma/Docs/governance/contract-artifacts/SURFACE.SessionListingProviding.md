# SURFACE.SessionListingProviding

## Surface Definition

**Surface Name**: SessionListingProviding  
**Authority Boundary**: Core Governance Layer  
**Implementation Location**: Capability Module (HarmoniaModule/Capability/)  
**Lease Required**: Yes - All implementations must acquire surface lease

## Contract Requirements

### Core Interface
All implementations MUST conform to `SessionListingProviding` protocol:

```swift
public protocol SessionListingProviding: Sendable {
    func listRecentSessions(projectId: UUID, limit: Int, trustTier: SessionTrustTier) async throws -> [SessionReport]
    func recentSessionsStream(projectId: UUID, limit: Int, trustTier: SessionTrustTier) -> AsyncThrowingStream<SessionReport, Error>
    func canListSessions(projectId: UUID, trustTier: SessionTrustTier) async throws -> Bool
}
```

### Governance Integration
All implementations MUST evaluate access through Harmonia governance layers BEFORE data access:

1. **SecurityEnforcer** - Check quarantine status first
2. **PolicyRegistry** - Validate session plan (Seraphim layer)
3. **Gatekeeper** - Per-session checks (Cherubim layer)
4. **EventSink** - Log all governance decisions

### Trust Verification
All yielded sessions MUST pass trust verification:
- **SessionTrustVerifier** integration required
- **TrustResult** must include verification time, score, and reasons
- **Failed verification** must throw `SessionListingError.trustVerificationFailed`

### Error Handling
All implementations MUST use first-class error handling:
- **Access Denied**: `SessionListingError.accessDenied(reason:)`
- **Trust Failure**: `SessionListingError.trustVerificationFailed(sessionId:reason:)`
- **Governance Violation**: `SessionListingError.governanceViolation(code:message:)`
- **Quarantine**: `SessionListingError.accessDenied(reason: "Project is quarantined")`

### Swift6 Concurrency
All implementations MUST be Swift6 concurrency safe:
- **Actor Isolation**: For mutable state (cache, in-flight operations)
- **Sendable Compliance**: All public interfaces must be Sendable
- **Async/Await**: Proper async/await patterns throughout
- **No Data Races**: Actor-managed state prevents concurrent access

## Implementation Patterns

### Pattern 1: Legacy Adapter (Immediate Compatibility)
- **Purpose**: Bridge new protocol with existing ProjectHarnessStore APIs
- **Use Case**: Immediate deployment without breaking changes
- **Governance**: Full Harmonia evaluation before store access
- **Trust**: Basic verification using governance trace information

### Pattern 2: Full Service (Production-Grade)
- **Purpose**: Complete implementation with ECS + caching + governance
- **Use Case**: High-performance, scalable session management
- **ECS Integration**: SessionListingSystem uses World queries for candidate assembly
- **Caching**: Actor-managed cache with TTL and in-flight coalescing
- **Trust**: Full SessionTrustVerifier integration with hardware-backed verification

## Surface Lease Enforcement

### Lease Acquisition
- **Required**: Yes - All implementations must acquire lease before development
- **Registry**: `.harmonia/sprint-registry.local.json` tracks active leases
- **Conflict Prevention**: Multiple sprints cannot lease same surface simultaneously
- **Duration**: Lease lasts until sprint finalization or explicit release

### Boundary Violations
The following changes REQUIRE contract artifact update:

1. **Surface Interface Changes**: Modifying SessionListingProviding protocol
2. **Core Layer Changes**: Modifying AnigmaCore session-related components
3. **Governance Changes**: Modifying PolicyRegistry, Gatekeeper, SecurityEnforcer
4. **New Implementation Patterns**: Adding new SessionListingProviding conformers

### Allowed Changes (Without Contract Update)
- **Capability Module Implementation**: New SessionListingProviding conformers
- **Performance Optimizations**: Caching, ECS query improvements
- **Bug Fixes**: Within existing implementation boundaries
- **Testing**: New tests for SessionListingProviding implementations

## Migration Path

### Phase 1: Contract Artifact Creation
- Create SURFACE.SessionListingProviding.md
- Define surface boundaries and requirements
- Establish lease enforcement mechanism

### Phase 2: Legacy Adapter Implementation
- Implement SessionListingLegacyAdapter
- Bridge existing ProjectHarnessStore APIs
- Maintain full governance evaluation
- Ensure zero breaking changes

### Phase 3: Full Service Implementation
- Implement SessionListingService with ECS integration
- Add actor-managed caching with TTL
- Integrate SessionTrustVerifier for court-safe access
- Provide AsyncThrowingStream for reactive consumers

### Phase 4: Controller Integration
- Update PrincipalityProjectController dependency
- Replace direct store coupling with SessionListingProviding
- Maintain backward compatibility through automatic fallback
- Add new streaming interfaces

## Audit Requirements

### Governance Audit Trail
All session listing operations MUST generate audit events:
- **Access Requests**: SessionListingAccessRequest evaluation
- **Access Decisions**: Allow/deny with reasons
- **Trust Verification**: Per-session verification results
- **Performance Metrics**: Cache hit rates, query times

### Security Audit
All implementations MUST support security auditing:
- **Session Provenance**: Hardware-backed signatures when available
- **Access Control**: Role-based access through trust tiers
- **Quarantine Compliance**: Immediate blocking of quarantined projects
- **Data Minimization**: Only return necessary session metadata

## Testing Requirements

### Unit Tests
- **Protocol Conformance**: All SessionListingProviding implementations
- **Governance Integration**: Mock PolicyRegistry, Gatekeeper, SecurityEnforcer
- **Error Scenarios**: Access denied, trust failures, quarantine
- **Concurrency**: Actor isolation, Sendable compliance

### Integration Tests
- **End-to-End**: Full session listing flow with real governance
- **Performance**: Cache behavior, concurrent access patterns
- **Compatibility**: Legacy adapter vs full service behavior
- **Security**: Trust verification with real certificates

## Versioning and Compatibility

### Surface Versioning
- **Major**: Breaking changes to SessionListingProviding protocol
- **Minor**: New methods or governance requirements
- **Patch**: Bug fixes, performance improvements

### Backward Compatibility
- **Protocol Stability**: Existing methods remain stable across minor versions
- **Implementation Compatibility**: Multiple implementations can coexist
- **Migration Support**: Clear upgrade paths between implementations

---

**Contract Status**: ACTIVE  
**Last Updated**: 2025-12-15  
**Authority**: Core Governance Layer  
**Implementation**: HarmoniaModule/Capability/