# HarmoniaModule Service Adapters

This directory contains service adapter implementations that integrate AccessumModule and ObservatoriumModule with HarmoniaModule's workflow orchestration system.

## Overview

Service adapters implement the `ServiceHandler` protocol, allowing external modules to be used as services within HarmoniaModule workflows. Each adapter wraps a module's coordinator and exposes actions that can be invoked through the workflow system.

### Supported Adapters

- **AccessumServiceAdapter**: Provides accessibility assessment and client management
- **ObservatoriumServiceAdapter**: Provides telemetry, metrics, and alerting capabilities

## AccessumServiceAdapter

Wraps `AccessumCoordinator` to expose accessibility assessment workflows.

### Available Actions

#### `assessContent`
Assess content for accessibility issues.

**Input:**
```swift
[
    "content": AnyCodable.string("..."),                  // Required: HTML/text content
    "wcagLevel": AnyCodable.string("AA"),                 // Optional: "A", "AA", or "AAA" (default: "AA")
    "clientId": AnyCodable.string("UUID-string")          // Optional: client UUID
]
```

**Output:**
```swift
[
    "assessmentId": AnyCodable.string("UUID"),
    "overallScore": AnyCodable.double(0.85),
    "wcagCompliance": AnyCodable.dictionary([...]),
    "screenReaderCompatible": AnyCodable.bool(true),
    "keyboardAccessible": AnyCodable.bool(true),
    "colorContrastIssuesCount": AnyCodable.int(0),
    "timestamp": AnyCodable.string("ISO8601-date")
]
```

#### `createClient`
Create a new accessibility client for tracking assessments.

**Input:**
```swift
[
    "requirements": AnyCodable.dictionary([            // Optional: accessibility requirements
        "wcagLevel": AnyCodable.string("AA")
    ]),
    "preferences": AnyCodable.dictionary([             // Optional: user preferences
        "altTextGenerationEnabled": AnyCodable.bool(true),
        "screenReaderOptimized": AnyCodable.bool(true),
        "keyboardNavigationOptimized": AnyCodable.bool(true),
        "highContrastMode": AnyCodable.bool(false)
    ])
]
```

**Output:**
```swift
[
    "clientId": AnyCodable.string("UUID"),
    "createdAt": AnyCodable.string("ISO8601-date"),
    "wcagLevel": AnyCodable.string("AA")
]
```

#### `updateClient`
Update an existing client's requirements or preferences.

**Input:**
```swift
[
    "clientId": AnyCodable.string("UUID-string"),          // Required
    "requirements": AnyCodable.dictionary([...]),          // Optional
    "preferences": AnyCodable.dictionary([...])            // Optional
]
```

**Output:**
```swift
[
    "clientId": AnyCodable.string("UUID"),
    "updated": AnyCodable.bool(true),
    "updatedAt": AnyCodable.string("ISO8601-date"),
    "fieldsUpdated": AnyCodable.int(2)
]
```

## ObservatoriumServiceAdapter

Wraps `ObservatoriumCoordinator` to expose telemetry, metrics, and alerting capabilities.

### Available Actions

#### `recordEvent`
Record a telemetry event.

**Input:**
```swift
[
    "type": AnyCodable.string("error"),                    // Required: event type
    "source": AnyCodable.string("module-name"),            // Required: event source
    "data": AnyCodable.dictionary([                         // Optional: event metadata
        "key": AnyCodable.string("value")
    ]),
    "severity": AnyCodable.string("warning")               // Optional: "info", "warning", "error", "critical"
]
```

Valid event types:
- `system_startup`, `system_shutdown`
- `performance_metric`, `error`, `user_action`
- `resource_usage`, `network_activity`, `database_operation`

**Output:**
```swift
[
    "eventId": AnyCodable.string("UUID"),
    "recorded": AnyCodable.bool(true),
    "timestamp": AnyCodable.string("ISO8601-date")
]
```

#### `recordMetric`
Record a performance metric.

**Input:**
```swift
[
    "name": AnyCodable.string("response_time"),           // Required
    "value": AnyCodable.double(125.5),                    // Required
    "unit": AnyCodable.string("ms"),                      // Optional (default: "count")
    "tags": AnyCodable.dictionary([                        // Optional: key-value pairs
        "endpoint": AnyCodable.string("/api/assess")
    ])
]
```

**Output:**
```swift
[
    "metricId": AnyCodable.string("UUID"),
    "recorded": AnyCodable.bool(true),
    "name": AnyCodable.string("response_time"),
    "value": AnyCodable.double(125.5),
    "unit": AnyCodable.string("ms"),
    "timestamp": AnyCodable.string("ISO8601-date")
]
```

#### `getMetrics`
Retrieve aggregated metrics for a time period.

**Input:**
```swift
[
    "timeRange": AnyCodable.string("lastDay")             // Optional: "lastHour", "lastDay", "lastWeek"
]
```

**Output:**
```swift
[
    "timeRange": AnyCodable.string("lastDay"),
    "eventCount": AnyCodable.int(1250),
    "errorCount": AnyCodable.int(3),
    "avgResponseTime": AnyCodable.double(45.2),
    "peakMemoryUsage": AnyCodable.double(512.0),
    "hasData": AnyCodable.bool(true)
]
```

#### `createAlert`
Create an alert rule for monitoring.

**Input:**
```swift
[
    "name": AnyCodable.string("High Error Rate"),         // Required
    "condition": AnyCodable.string("errorCount > 10"),   // Required
    "severity": AnyCodable.string("critical"),           // Required: "low", "medium", "high", "critical"
    "message": AnyCodable.string("Custom message")       // Optional
]
```

**Output:**
```swift
[
    "ruleId": AnyCodable.string("UUID"),
    "created": AnyCodable.bool(true),
    "name": AnyCodable.string("High Error Rate"),
    "createdAt": AnyCodable.string("ISO8601-date")
]
```

#### `getActiveAlerts`
Get currently active alerts, optionally filtered by severity.

**Input:**
```swift
[
    "severity": AnyCodable.string("critical")             // Optional: filter by severity
]
```

**Output:**
```swift
[
    "alerts": AnyCodable.array([
        AnyCodable.dictionary([
            "ruleId": AnyCodable.string("UUID"),
            "name": AnyCodable.string("Alert Name"),
            "severity": AnyCodable.string("critical"),
            "title": AnyCodable.string("Title"),
            "message": AnyCodable.string("Message")
        ])
    ]),
    "count": AnyCodable.int(2),
    "critical": AnyCodable.int(1),
    "timestamp": AnyCodable.string("ISO8601-date")
]
```

## Integration Examples

### Basic Setup

```swift
import HarmoniaModule
import AccessumModule
import ObservatoriumModule

// Create registry
let registry = ServiceRegistry()

// Create and register adapters
let accessumAdapter = try await AccessumServiceAdapter()
let observatoriumAdapter = try await ObservatoriumServiceAdapter()

try await registry.register(service: accessumAdapter)
try await registry.register(service: observatoriumAdapter)
```

### Using ServiceAdapterFactory

```swift
// Create factory and register all adapters
let factory = try await ServiceAdapterFactory.createWithAllAdapters(registry: registry)

// Or create individual adapters
let accessumAdapter = try await factory.createAccessumAdapter()
let observatoriumAdapter = try await factory.createObservatoriumAdapter()

// Check health
let healthStatuses = try await factory.checkAllAdaptersHealth()
```

### Building Workflows

```swift
// Define a workflow that assesses content and records metrics
let steps = [
    WorkflowStep(
        id: "assess",
        serviceId: "accessum-service",
        action: "assessContent",
        input: [
            "content": .string("Your HTML content here"),
            "wcagLevel": .string("AA")
        ]
    ),
    WorkflowStep(
        id: "record-metrics",
        serviceId: "observatorium-service",
        action: "recordMetric",
        input: [
            "name": .string("assessment_duration"),
            "value": .double(150.0),
            "unit": .string("ms")
        ],
        dependencies: ["assess"]
    )
]

let definition = WorkflowDefinition(
    id: "assessment-workflow",
    name: "Accessibility Assessment",
    description: "Assess content and record metrics",
    steps: steps
)
```

### Error Handling

```swift
do {
    let output = try await adapter.execute(
        action: "assessContent",
        input: [
            "content": .string("HTML content")
        ]
    )
    print("Assessment successful: \(output)")
} catch let error as AccessumAdapterError {
    switch error {
    case .missingRequiredParameter(let param):
        print("Missing parameter: \(param)")
    case .assessmentFailed(let reason):
        print("Assessment failed: \(reason)")
    default:
        print("Error: \(error.localizedDescription)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Health Checking

```swift
// Check health of individual adapter
let status = try await adapter.getHealth()
print("Adapter status: \(status)")

// Monitor all adapters
let healthStatuses = try await factory.checkAllAdaptersHealth()
for (serviceId, status) in healthStatuses {
    print("\(serviceId): \(status)")
}
```

## Performance Considerations

### AccessumServiceAdapter

- **Assessment timeout**: 30 seconds
- **Client management timeout**: 5 seconds
- Large content assessments may take time depending on complexity
- Consider implementing request queuing for high-volume scenarios

### ObservatoriumServiceAdapter

- **Event recording timeout**: 5 seconds (fast, async operation)
- **Metric retrieval timeout**: 10 seconds
- **Alert operations timeout**: 5-10 seconds
- Metrics are aggregated asynchronously; allow time for data accumulation

### Best Practices

1. **Workflow Dependencies**: Chain assessment before metrics recording
2. **Timeout Configuration**: Adjust in `ServiceCapability.timeout` if needed
3. **Error Recovery**: Implement retry logic using `WorkflowDefinition.retryPolicy`
4. **Health Monitoring**: Periodically check adapter health in long-running workflows
5. **Resource Cleanup**: Unregister unused adapters with `factory.unregisterAdapter()`

## Type Conversions

The adapters handle conversion between module-specific types and `AnyCodable` for workflow compatibility:

- **Enums**: Converted to/from string representations
- **UUIDs**: Converted to/from UUID strings
- **Dates**: Converted to/from ISO8601 format strings
- **Complex Objects**: Extracted to dictionaries with relevant fields
- **Arrays**: Mapped through `AnyCodable.array()`

## Extension Points

### Custom Coordinators

Pass custom coordinator instances during adapter creation:

```swift
let customCoordinator = AccessumCoordinator()
// Configure as needed
let adapter = try await factory.createAccessumAdapter(
    coordinator: customCoordinator,
    autoRegister: false
)
```

### Custom Capabilities

Modify service capabilities after creation:

```swift
let adapter = try await factory.createAccessumAdapter()
let customCapability = ServiceCapability(
    action: "customAction",
    inputType: "[String: AnyCodable]",
    outputType: "[String: AnyCodable]",
    timeout: 60.0
)
```

## Troubleshooting

### Adapter Not Found

Ensure the adapter is created and registered:
```swift
let has = await factory.hasAdapter("accessum-service")
if !has {
    _ = try await factory.createAccessumAdapter()
}
```

### Health Check Failures

Verify underlying services are initialized:
```swift
let status = try await adapter.getHealth()
if status == .unhealthy {
    // Reinitialize or check service state
}
```

### Missing Parameters

Check action documentation for required parameters:
```swift
// Required: "content"
let result = try await adapter.execute(
    action: "assessContent",
    input: ["content": .string("...")]
)
```

## Future Enhancements

- Batch action support for multiple operations
- Custom serialization for complex types
- Event streaming for real-time monitoring
- Adapter middleware/interceptors
- Advanced error recovery strategies
