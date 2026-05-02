# CLI Analytics Integration Guide

## Overview

The CLI Analytics system provides privacy-preserving analytics for Phase 3 of the CLI thin client migration. It enables data-driven optimization while respecting user privacy with comprehensive opt-in/opt-out mechanisms.

## Quick Start

### 1. Initialize Analytics

```swift
import AnigmaCLICore
import TelemetryCore

// Initialize global analytics
GlobalCLIAnalytics.initialize(configuration: .default)

// Or create a custom manager
let config = CLIAnalyticsConfiguration(
    isEnabled: true,
    collectionLevel: .basic,
    anonymizationLevel: .anonymous,
    optInRequired: true
)
let analyticsManager = CLIAnalyticsManager(configuration: config)
```

### 2. Basic Command Analytics

```swift
// Record command start
GlobalCLIAnalytics.recordCommandStart("plan")

// Execute command...
// ...

// Record command completion
await GlobalCLIAnalytics.recordCommandCompletion("plan", success: true)
```

### 3. Using Convenience Methods

```swift
let result = try await analyticsManager.withCommandAnalytics("search") {
    // Your command logic here
    return performSearch(query: "test")
}

let measuredResult = try await analyticsManager.measurePerformance("database_query") {
    return queryDatabase()
}
```

## Integration Patterns

### 1. Command Integration

```swift
public func executeCommand(_ command: String, arguments: [String]) async throws {
    // Record start
    GlobalCLIAnalytics.recordCommandStart(command)
    
    do {
        // Execute command logic
        let result = try await executeLogic(command, arguments: arguments)
        
        // Record success
        await GlobalCLIAnalytics.recordCommandCompletion(command, success: true)
        
        return result
    } catch {
        // Record failure
        await GlobalCLIAnalytics.recordCommandCompletion(
            command,
            success: false,
            errorMessage: error.localizedDescription
        )
        throw error
    }
}
```

### 2. Daemon Usage Tracking

```swift
public func executeWithDaemon(_ command: String) async throws {
    let startTime = Date()
    
    do {
        let result = try await executeViaDaemon(command)
        let latency = Date().timeIntervalSince(startTime) * 1000
        
        await analyticsManager.recordDaemonUsage(
            command: command,
            usedDaemon: true,
            latencyMs: latency
        )
        
        return result
    } catch {
        let latency = Date().timeIntervalSince(startTime) * 1000
        
        await analyticsManager.recordDaemonUsage(
            command: command,
            usedDaemon: true,
            fallbackReason: error.localizedDescription,
            latencyMs: latency
        )
        throw error
    }
}
```

### 3. Cache Performance Tracking

```swift
public func getCachedOrCompute(_ key: String) async throws -> String {
    let cacheType = "response_cache"
    let keyHash = String(key.hashValue)
    
    if let cached = cache.get(key) {
        await analyticsManager.recordCacheEvent(
            cacheType: cacheType,
            hit: true,
            keyHash: keyHash
        )
        return cached
    }
    
    await analyticsManager.recordCacheEvent(
        cacheType: cacheType,
        hit: false,
        keyHash: keyHash
    )
    
    let result = try await computeValue(key)
    cache.set(key, result)
    
    return result
}
```

## Configuration

### Environment Variables

```bash
# Enable/disable analytics
export ANIGMA_ANALYTICS_CONSENT=true

# Collection level
export ANIGMA_ANALYTICS_LEVEL=basic  # minimal, basic, detailed, full

# Anonymization level
export ANIGMA_ANALYTICS_ANONYMIZATION=anonymous  # anonymous, pseudonymous, aggregated
```

### Programmatic Configuration

```swift
let config = CLIAnalyticsConfiguration(
    isEnabled: true,
    collectionLevel: .detailed,
    anonymizationLevel: .pseudonymous,
    retentionDays: 90,
    optInRequired: true
)
```

## Privacy Controls

### 1. Opt-In Mechanism

By default, analytics require explicit user consent. Users can provide consent via:

- Environment variable: `ANIGMA_ANALYTICS_CONSENT=true`
- User defaults: `UserDefaults.standard.set(true, forKey: "anigma.analytics.consent")`
- Interactive prompt (implement in your CLI)

### 2. Data Anonymization

Three levels of anonymization:

1. **Anonymous**: No user identifiers, session-based only
2. **Pseudonymous**: Anonymous user ID for trend analysis
3. **Aggregated**: Only aggregate statistics, no individual data

### 3. Data Retention

- Default: 30 days
- Configurable via `retentionDays`
- Automatic data cleanup

## Analytics Insights

### Generating Insights

```swift
let insights = await analyticsManager.generateOptimizationInsights()

for insight in insights {
    print("""
    Category: \(insight.category)
    Description: \(insight.description)
    Impact Score: \(String(format: "%.1f", insight.impactScore))
    Confidence: \(String(format: "%.0f", insight.confidence * 100))%
    Action: \(insight.suggestedAction)
    """)
}
```

### Common Insights

The system automatically identifies:
- Slow commands (>1 second average execution)
- Error-prone commands (<90% success rate)
- Inefficient cache usage
- Daemon fallback patterns

## Data Export

### Export Analytics Data

```swift
if let data = await analyticsManager.exportAnalyticsData() {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("anigma-analytics-\(Date().ISO8601Format()).json")
    try data.write(to: url)
    print("Exported analytics to: \(url.path)")
}
```

### Export Format

```json
{
  "sessionId": "anonymous",
  "metrics": [
    {
      "commandName": "plan",
      "executionCount": 42,
      "averageDurationMs": 1250.5,
      "successRate": 0.95,
      "errorCount": 2,
      "cacheHitRate": 0.75,
      "daemonUsageRate": 0.85
    }
  ],
  "configuration": {
    "isEnabled": true,
    "collectionLevel": "basic",
    "anonymizationLevel": "anonymous",
    "retentionDays": 30,
    "optInRequired": true
  },
  "timestamp": "2025-01-27T18:59:00Z"
}
```

## Migration Analytics

### Tracking Migration Progress

```swift
public func executeMigrationPhase(_ phase: String, steps: [String]) async throws {
    for step in steps {
        let stepStart = Date()
        
        do {
            try await executeMigrationStep(step)
            let duration = Date().timeIntervalSince(stepStart) * 1000
            
            await analyticsManager.recordMigrationEvent(
                phase: phase,
                step: step,
                success: true,
                durationMs: duration
            )
        } catch {
            let duration = Date().timeIntervalSince(stepStart) * 1000
            
            await analyticsManager.recordMigrationEvent(
                phase: phase,
                step: step,
                success: false,
                durationMs: duration,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
}
```

## Testing

### Unit Tests

```swift
import Testing
@testable import AnigmaCLICore

@Test func testAnalyticsRecording() async {
    let config = CLIAnalyticsConfiguration(optInRequired: false)
    let manager = CLIAnalyticsManager(configuration: config)
    
    await manager.recordCommandStart("test")
    await manager.recordCommandCompletion("test", success: true)
    
    let metrics = await manager.getCommandMetrics()
    #expect(metrics.count > 0)
}
```

### Integration Tests

See `CLIAnalyticsIntegrationExample.swift` for comprehensive examples.

## Best Practices

### 1. Always Check Consent

```swift
guard analyticsManager.configuration.isEnabled else { return }
```

### 2. Use Appropriate Privacy Levels

```swift
// For sensitive operations
await analyticsManager.recordPerformanceMetric(
    "sensitive_operation",
    value: duration,
    privacyClassification: .restricted
)

// For public operations
await analyticsManager.recordPerformanceMetric(
    "public_operation",
    value: duration,
    privacyClassification: .public
)
```

### 3. Batch Operations

```swift
// Batch multiple metrics
await withTaskGroup(of: Void.self) { group in
    group.addTask {
        await analyticsManager.recordPerformanceMetric("metric1", value: 1.0)
    }
    group.addTask {
        await analyticsManager.recordPerformanceMetric("metric2", value: 2.0)
    }
}
```

### 4. Clean Up Old Data

```swift
// Clear metrics periodically
await analyticsManager.clearMetrics()
```

## Troubleshooting

### Common Issues

1. **Analytics not recording**: Check if `isEnabled` is true and user has provided consent
2. **High memory usage**: Analytics buffer grows with usage, call `clearMetrics()` periodically
3. **Performance impact**: Use `collectionLevel: .minimal` for performance-critical operations
4. **Export failures**: Ensure analytics is enabled and has data to export

### Debugging

```swift
// Check configuration
print("Analytics enabled: \(analyticsManager.configuration.isEnabled)")
print("Collection level: \(analyticsManager.configuration.collectionLevel)")
print("Has consent: \(await analyticsManager.hasUserConsent())")

// Check metrics count
let metrics = await analyticsManager.getCommandMetrics()
print("Metrics recorded: \(metrics.count)")
```

## Migration from Phase 2

If you're migrating from Phase 2 analytics:

1. **Backward Compatibility**: The new system is compatible with existing TelemetryCore
2. **Enhanced Features**: Adds CLI-specific analytics not available in Phase 2
3. **Privacy Improvements**: Stronger privacy controls and consent management
4. **Performance Insights**: Automatic optimization recommendations

## References

- `CLIAnalytics.swift`: Core analytics implementation
- `CLIAnalyticsTests.swift`: Unit tests
- `CLIAnalyticsIntegrationExample.swift`: Comprehensive examples
- TelemetryCore documentation for underlying telemetry system

---

**Last Updated**: 2025-01-27  
**Phase**: 3 (Thin Client Migration)  
**Status**: Production Ready  
**Privacy Level**: Enterprise-grade