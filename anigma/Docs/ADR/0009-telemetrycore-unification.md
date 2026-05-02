> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR-0009: TelemetryCore Unification

## Context

The Anigma repository has scattered telemetry mechanisms across multiple modules:
- `ObservatoriumModule` has its own `TelemetryService` with event buffering and metric collection
- `AnigmaCore` has `TelemetryTypes` with different event structures and privacy controls
- `HarmoniaMemory` has observation capture with JSON string storage
- Various modules emit metrics and events independently

This fragmentation creates several problems:
1. **Privacy Inconsistency**: Different modules have different privacy controls and redaction rules
2. **Duplicate Infrastructure**: Multiple buffering, sampling, and redaction implementations
3. **Inability to Enforce Policy**: No single chokepoint for telemetry governance
4. **Testing Complexity**: Hard to verify privacy guarantees across scattered implementations

## Decision

Create a unified `TelemetryCore` module that consolidates all telemetry mechanisms while enforcing privacy by construction. The new module follows these design principles:

### Privacy-First by Type System Design
- **No Arbitrary Strings**: `TelemetryValue` enum only supports numeric, boolean, controlled tags, and hashed tokens
- **Mandatory Redaction**: All events pass through `Redaction.apply()` before reaching sinks
- **Restricted Access**: Sinks only receive `RedactedTelemetryEvent`, never raw events
- **Hashed Tokens**: User data is cryptographically hashed, never stored as plaintext

### Consolidated Mechanisms
- **Single TelemetryClient**: Centralized telemetry emission with enforced pipeline
- **Unified Sinks**: File, memory, console, and composite sinks with consistent interfaces
- **Privacy-Aware Sampling**: Respects privacy classifications (public=100%, internal=10%, restricted=1%)
- **Deterministic Redaction**: Whitelist-based tag filtering with strict length limits

### Governance Boundaries Preserved
- **Memory Storage Remains Separate**: `HarmoniaMemory` continues as the memory substrate
- **Policy Enforcement**: `TelemetryCore` provides the mechanisms, `HarmoniaModule` provides the policy decisions
- **No New Storage Surfaces**: `TelemetryCore` is instrumentation only, not data persistence

## Consequences

### Positive
1. **Privacy Guarantees Enforced by Type System**: Impossible to emit raw user strings through telemetry
2. **Single Chokepoint**: All telemetry flows through unified redaction and sampling
3. **Reduced Duplication**: Eliminates multiple telemetry buffering and redaction implementations
4. **Consistent API**: Single `TelemetryClient.emit()` interface across all modules
5. **Testable Privacy Invariants**: Comprehensive test suite proves no user data leakage

### Negative
1. **Migration Effort**: Existing telemetry calls must be updated to use new API
2. **Learning Curve**: Developers must understand new value type constraints
3. **Potential Performance Overhead**: Redaction and sampling add minimal processing

### Neutral
1. **Backward Compatibility**: Migration adapters can bridge old APIs temporarily
2. **Configuration Complexity**: Privacy and sampling policies must be carefully configured
3. **Testing Requirements**: Additional tests needed for privacy invariants

## Migration Plan

### Phase 1: Foundation (Current Sprint)
- [x] Create `TelemetryCore` module with privacy-enforced types
- [x] Implement mandatory redaction pipeline
- [x] Create unified sink infrastructure
- [x] Add comprehensive privacy tests

### Phase 2: Migration (Next Sprint)
- [ ] Update `ObservatoriumModule` to use `TelemetryClient`
- [ ] Migrate telemetry hooks from `HarmoniaMemory` (memory storage unchanged)
- [ ] Update `AnigmaCore` telemetry usage
- [ ] Add compatibility adapters for gradual migration

### Phase 3: Cleanup (Following Sprint)
- [ ] Remove deprecated telemetry implementations
- [ ] Update documentation and contracts
- [ ] Optimize performance based on production usage

## Privacy Guarantees

### Enforced by Type System
```swift
// This does not compile - no raw string support
TelemetryValue.string("user_sensitive_data") // ❌

// Only safe types allowed
TelemetryValue.hashedToken("user_data")      // ✅
TelemetryValue.limitedTag(.success)          // ✅
TelemetryValue.integer(42)                   // ✅
```

### Enforced by Pipeline
```swift
// All emissions go through mandatory pipeline
TelemetryClient.emit() → Sampling.check() → Redaction.apply() → Sink.handle()
```

### Enforced by Sink Protocol
```swift
protocol TelemetrySink {
    func handle(_ event: RedactedTelemetryEvent) // Raw events never exposed
}
```

## Implementation Notes

### Key Files Created
- `Sources/TelemetryCore/TelemetryEvent.swift` - Core event structure
- `Sources/TelemetryCore/TelemetryValue.swift` - Restricted value types
- `Sources/TelemetryCore/Redaction.swift` - Mandatory redaction pipeline
- `Sources/TelemetryCore/TelemetryClient.swift` - Unified telemetry API
- `Sources/TelemetryCore/TelemetrySink.swift` - Output sink abstractions
- `Tests/TelemetryCoreTests/TelemetryPrivacyTests.swift` - Privacy invariant tests

### Backward Compatibility Strategy
- Existing telemetry services can use compatibility adapters temporarily
- Old APIs route through new `TelemetryClient` under the hood
- Gradual migration path with feature flags if needed

### Integration Points
- `HarmoniaModule` provides policy decisions (unchanged)
- `HarmoniaMemory` provides memory storage (unchanged)
- `ObservatoriumModule` migrates to unified client
- `AnigmaCore` updates to use new value types

## Success Criteria

1. **Build Passes**: All existing functionality works with new module
2. **Tests Pass**: All privacy invariant tests pass
3. **No Data Leakage**: Comprehensive testing proves no user data in telemetry
4. **Migration Path**: Clear upgrade path for existing telemetry users
5. **Performance**: No significant performance regression

## Future Considerations

1. **Dynamic Configuration**: Runtime policy updates for privacy controls
2. **Advanced Sinks**: Remote telemetry services with encrypted transmission
3. **Machine Learning**: Anomaly detection on telemetry patterns
4. **Compliance Features**: GDPR and data retention automation
5. **Performance Optimization**: Batching and compression for high-volume scenarios

This ADR establishes the foundation for privacy-respecting telemetry that can evolve with the project's needs while maintaining strict security boundaries.