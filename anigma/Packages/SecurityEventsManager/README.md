# SecurityEventsManager

**Centralized security event logging and observability for the Anigma platform.**

SecurityEventsManager provides specialized logging and monitoring for security-related events across all Anigma modules. It ensures that critical events (e.g., authorization failures, trust changes, doctrine violations) are recorded in a dedicated persistent store for audit and alerting.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              SecurityEventsManager                      │
├─────────────────────────────────────────────────────────┤
│  Security Event API (Actor)                             │
│  ├─ Specialized Loggers (Doctrine, Trust, Capability)    │
│  ├─ Severity-based Filtering                            │
│  └─ Observability Queries & Statistics                  │
├─────────────────────────────────────────────────────────┤
│  SQLite Storage                                         │
│  ├─ security_events table                               │
│  ├─ Structured Details (JSON)                           │
│  └─ High-performance Indexing                          │
└─────────────────────────────────────────────────────────┘
```

## Core Features

- **Dedicated Persistence**: Logs events to a specialized `security_events` table, separate from the general application logs.
- **Specialized Loggers**: Convenient methods for common security scenarios:
  - `logCapabilityBlocked`: When a capability is requested but denied.
  - `logDoctrineViolation`: When an action violates architectural or security doctrines.
  - `logTrustChange`: Tracking promotions or degradations of entity trust tiers.
  - `logModeChange`: Tracking changes in governance operating modes.
  - `logRedTeamAttack`: Recording detected security threats or test attacks.
- **Observability**: API for retrieving historical events and calculating statistics.
- **Thread-Safe**: Implemented as an actor for concurrent security reporting.

## Core Types

### SecurityEventType

Defines the categories of security events tracked by the manager.

```swift
public enum SecurityEventType: String, Codable {
    case capabilityBlocked
    case doctrineViolation
    case trustPromoted
    case trustDegraded
    case modeChanged
    case researchInadequate
    case redTeamAttack
}
```

### SecurityEventSeverity

```swift
public enum SecurityEventSeverity: String, Codable {
    case low
    case medium
    case high
    case critical
}
```

## Usage Examples

### Logging a Blocked Capability

```swift
import SecurityEventsManager

let manager = SecurityEventsManager(dbPath: "anigma_security.sqlite")

await manager.logCapabilityBlocked(
    engineId: "harmonia-executor",
    operation: "write_system_file",
    capability: "filesystem",
    reason: "Restricted zone access attempt"
)
```

### Tracking Trust Changes

```swift
await manager.logTrustChange(
    subjectId: "agent-007",
    subjectKind: "agent",
    oldTier: "trusted",
    newTier: "restricted",
    reason: "Policy violation detected"
)
```

### Monitoring Statistics

```swift
let stats = await manager.getEventStats()
print("Critical events in last 24h: \(stats.eventsBySeverity["critical"] ?? 0)")
```

## Thread Safety

- **SecurityEventsManager** is an `actor` - all database operations are serialized.
- **All event types** are `Sendable`.

## Dependencies

- **AnigmaCore**: Core primitives and logging.
- **SQLite3**: For high-performance event storage.

## See Also

- [AnigmaCore.Governance](../../Sources/AnigmaCore/Governance/README.md) - Runtime enforcement.
- [ExecutionCore](../../Sources/ExecutionCore/README.md) - Source of execution receipts.

## License

Part of the Anigma project. See LICENSE for details.
