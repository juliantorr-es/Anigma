# OSLog Implementation Guide for Anigma Backend

**Version**: 1.0  
**Last Updated**: 2026-04-09  
**Status**: ✅ **ACTIVE**

---

## Quick Start Guide

### 1. Basic OSLog Setup

```swift
// At the top of your file (with other imports)
import os.log

// Define your logger (typically at class/file level)
private let log = Logger(
    subsystem: "com.anigma.backend",
    category: "workflow"  // Change based on your module
)
```

### 2. Logging Levels Cheat Sheet

```swift
// Development debugging (remove in production)
if log.isEnabled(for: .debug) {
    log.debug("Function entered with parameters: \(parameters, privacy: .public)")
}

// Normal operation messages
log.info("Workflow execution started", 
    metadata: ["workflowId": "\(workflow.id)"])

// Potential issues (non-fatal)
log.warning("Retrying operation after transient failure", 
    metadata: ["attempt": "3/5", "error": "\(error.localizedDescription)"])

// Errors and exceptions
log.error("Document processing failed", 
    metadata: [
        "documentId": "\(document.id)",
        "error": "\(error.localizedDescription, privacy: .public)"
    ])

// Critical failures
log.critical("Database connection lost - entering degraded mode")
```

### 3. Privacy Handling

```swift
// ✅ SAFE: Public data only
log.info("User authenticated", 
    metadata: ["userId": "\(user.id)", "method": "\(authMethod)"])

// ✅ SAFE: Explicit privacy control
log.debug("Processing sensitive data", 
    metadata: ["recordId": "\(record.id, privacy: .public)"])

// ❌ UNSAFE: Never do this
log.info("User token: \(user.authToken)")  // Security violation!

// ✅ SAFE: Hash sensitive identifiers
log.info("User activity", 
    metadata: ["hashedUserId": "\(user.id.hash)"])
```

---

## Module-Specific Guidelines

### HarmoniaModule (Workflow Orchestration)

```swift
private let log = Logger(subsystem: "com.anigma.harmonia", category: "workflow")

exension OSLog {
    static let harmoniaWorkflow = OSLog(
        subsystem: "com.anigma.harmonia", 
        category: "workflow"
    )
    
    static let harmoniaGovernance = OSLog(
        subsystem: "com.anigma.harmonia", 
        category: "governance"
    )
}

// Usage in workflow execution
log.info("Starting workflow execution", 
    metadata: [
        "workflowId": "\(workflow.id)",
        "operation": "\(workflow.operationType)",
        "principal": "\(principal.id.hash)"
    ])

// Performance tracking
let startTime = ContinuousClock.now
// ... workflow execution ...
let duration = startTime.duration(to: .now)
log.info("Workflow completed", 
    metadata: ["durationMs": "\(duration.milliseconds)"])
```

### PragmaModule (Work Board System)

```swift
private let log = Logger(subsystem: "com.anigma.pragma", category: "workboard")

// Work board operations
log.info("Creating work board attempt", 
    metadata: [
        "attemptId": "\(attempt.id)",
        "boardId": "\(board.id)",
        "userId": "\(user.id.hash)"
    ])

// Error handling
do {
    try await submitAttempt()
    log.info("Attempt submitted successfully")
} catch {
    log.error("Attempt submission failed", 
        metadata: [
            "error": "\(error.localizedDescription, privacy: .public)",
            "attemptId": "\(attempt.id)"
        ])
}
```

### ConexusModule (Connection Management)

```swift
private let log = Logger(subsystem: "com.anigma.conexus", category: "network")

// Network operations
log.info("Establishing connection", 
    metadata: [
        "endpoint": "\(endpoint.redacted)",  // Don't log full URLs
        "protocol": "\(protocol)"
    ])

// Connection events
log.info("Connection established", 
    metadata: [
        "connectionId": "\(connection.id)",
        "latencyMs": "\(latency)"
    ])

// Disconnection
log.warning("Connection closed", 
    metadata: [
        "connectionId": "\(connection.id)",
        "reason": "\(reason, privacy: .public)"
    ])
```

---

## Common Patterns & Recipes

### 1. Performance-Optimized Logging

```swift
// ✅ GOOD: Check if logging is enabled before expensive operations
if log.isEnabled(for: .debug) {
    let debugInfo = generateExpensiveDebugString()
    log.debug("Debug info: \(debugInfo, privacy: .public)")
}

// ❌ BAD: Expensive operation even when logging disabled
log.debug("Debug info: \(generateExpensiveDebugString(), privacy: .public)")
```

### 2. Error Logging with Context

```swift
// ✅ GOOD: Complete error context
do {
    try performOperation()
} catch {
    log.error("Operation failed", 
        metadata: [
            "errorType": "\(type(of: error))",
            "errorMessage": "\(error.localizedDescription, privacy: .public)",
            "operation": "documentProcessing",
            "documentId": "\(document.id)",
            "retryCount": "\(retryCount)"
        ])
}

// ❌ BAD: Minimal context
catch {
    print("Error: \(error)")  // No structure, no metadata
}
```

### 3. Batch Operation Logging

```swift
// ✅ GOOD: Summary logging for batches
let startTime = ContinuousClock.now
var successCount = 0
var failureCount = 0

for item in batch {
    do {
        try process(item)
        successCount += 1
    } catch {
        failureCount += 1
        log.warning("Item processing failed", 
            metadata: ["itemId": "\(item.id)", "error": "\(error.localizedDescription)"])
    }
}

let duration = startTime.duration(to: .now)
log.info("Batch processing completed", 
    metadata: [
        "totalItems": "\(batch.count)",
        "successCount": "\(successCount)",
        "failureCount": "\(failureCount)",
        "durationMs": "\(duration.milliseconds)",
        "successRate": "\(Double(successCount) / Double(batch.count))"
    ])
```

### 4. State Transition Logging

```swift
// ✅ GOOD: Track state changes
log.info("State transition", 
    metadata: [
        "entityId": "\(entity.id)",
        "fromState": "\(oldState)",
        "toState": "\(newState)",
        "trigger": "\(trigger)",
        "timestamp": "\(Date().iso8601)"
    ])
```

---

## Migration Guide: print() → OSLog

### Before & After Examples

#### 1. Simple Message

**Before**:
```swift
print("Starting document processing")
```

**After**:
```swift
log.info("Starting document processing")
```

#### 2. Variable Interpolation

**Before**:
```swift
print("Processing document \(document.id) - \(document.title)")
```

**After**:
```swift
log.info("Processing document \(document.id, privacy: .public) - \(document.title, privacy: .public)")
```

#### 3. Error Logging

**Before**:
```swift
print("ERROR: Failed to process document: \(error)")
```

**After**:
```swift
log.error("Document processing failed", 
    metadata: ["error": "\(error.localizedDescription, privacy: .public)"])
```

#### 4. Debug Logging

**Before**:
```swift
print("Debug: Current state = \(complexStateDescription())")
```

**After**:
```swift
if log.isEnabled(for: .debug) {
    log.debug("Current state: \(complexStateDescription(), privacy: .public)")
}
```

#### 5. Loop Logging

**Before**:
```swift
for (index, item) in items.enumerated() {
    print("Processing item \(index): \(item)")
    // ... processing ...
}
```

**After**:
```swift
if log.isEnabled(for: .debug) {
    for (index, item) in items.enumerated() {
        log.debug("Processing item \(index, privacy: .public)")
        // ... processing ...
    }
}
```

---

## CI/CD Integration

### Git Hook (pre-commit)

```bash
#!/bin/bash

# Check for new print statements
git diff --cached --name-only | grep \.swift$ | while read -r file; do
    if git diff --cached "$file" | grep -q "^+.*print("; then
        echo "❌ Found print() statement in $file"
        echo "Please use OSLog instead: log.info()"
        exit 1
    fi
done

exit 0
```

### GitHub Actions Check

```yaml
- name: Check for print statements
  run: |
    PRINT_COUNT=$(find Sources Packages -name "*.swift" -exec grep -c "print(" {} + | paste -sd+ | bc)
    if [ "$PRINT_COUNT" -gt "0" ]; then
      echo "❌ Found $PRINT_COUNT print() statements"
      echo "Please convert to OSLog for production readiness"
      exit 1
    fi
```

---

## Monitoring & Alerts

### Log Aggregation Setup

```swift
// Configure in your AppDelegate or main.swift
try? OSLog.configure(with: .init(
    logFilePath: URL(fileURLWithPath: "/var/log/anigma/backend.log"),
    maxFileSize: 10 * 1024 * 1024,  // 10MB per file
    maximumNumberOfLogFiles: 5      // Keep 5 rotated files
))
```

### Production Alerting

```swift
// Set up error monitoring
let errorMonitor = LogMonitor(subsystem: "com.anigma.backend") { entry in
    if entry.level == .error || entry.level == .critical {
        // Send alert to monitoring system
        MonitoringSystem.shared.alert(
            title: "Backend Error",
            message: entry.composedMessage,
            severity: .high,
            metadata: entry.metadata
        )
    }
}
errorMonitor.start()
```

---

## Best Practices Checklist

### ✅ Do's

- [ ] Use appropriate log levels (.debug, .info, .warning, .error, .critical)
- [ ] Check `isEnabled(for:)` before expensive debug operations
- [ ] Use `privacy: .public` for non-sensitive data
- [ ] Never log tokens, passwords, or PII
- [ ] Include relevant context in metadata
- [ ] Use consistent subsystem and category per module
- [ ] Add timestamps for important events
- [ ] Log both success and failure paths
- [ ] Include operation IDs for correlation
- [ ] Document logging conventions per module

### ❌ Don'ts

- [ ] Don't use `print()` in production code
- [ ] Don't log sensitive data (tokens, passwords, PII)
- [ ] Don't use logging in performance-critical loops without checks
- [ ] Don't mix logging approaches in the same module
- [ ] Don't log excessive amounts of data
- [ ] Don't use logging for control flow
- [ ] Don't forget to handle privacy for all logged data
- [ ] Don't create loggers repeatedly (reuse them)
- [ ] Don't log in tight loops without level checks
- [ ] Don't assume logs are always written (check levels)

---

## Module-Specific Categories

| Module | Subsystem | Recommended Categories |
|--------|-----------|----------------------|
| AnigmaCore | `com.anigma.core` | `runtime`, `jobs`, `governance`, `security` |
| HarmoniaModule | `com.anigma.harmonia` | `workflow`, `governance`, `inference`, `memory` |
| PragmaModule | `com.anigma.pragma` | `workboard`, `attempt`, `review`, `scoring` |
| ConexusModule | `com.anigma.conexus` | `network`, `connection`, `protocol`, `security` |
| ContextumModule | `com.anigma.contextum` | `indexing`, `search`, `embedding`, `storage` |
| ObservatoriumModule | `com.anigma.observatorium` | `telemetry`, `metrics`, `alerts`, `feedback` |
| OutlineumModule | `com.anigma.outlineum` | `outline`, `zine`, `generation`, `export` |
| AnimationKit | `com.anigma.animation` | `animation`, `rendering`, `timing`, `performance` |
| TranscriptumModule | `com.anigma.transcriptum` | `enrollment`, `grades`, `records`, `compliance` |

---

## Performance Impact Analysis

### Before Conversion

```
Estimated Impact: 15-20% performance degradation
Cause: I/O-bound print() operations in hot paths
Affected Areas:
- Workflow execution loops
- Network operation handling  
- Document processing pipelines
- Real-time event processing
```

### After Conversion

```
Estimated Improvement: 15-20% performance gain
Benefits:
- OSLog is buffered and async
- No I/O in hot paths
- Level-based filtering reduces overhead
- Structured data is more efficient
```

### Measurement Approach

```swift
// Before: Measure baseline
let startTime = ContinuousClock.now
performOperation()
let baselineDuration = startTime.duration(to: .now)

// After: Measure with OSLog
let optimizedStart = ContinuousClock.now
performOperation()
let optimizedDuration = optimizedStart.duration(to: .now)

// Calculate improvement
let improvement = 1 - (optimizedDuration / baselineDuration)
log.info("Performance improvement", 
    metadata: ["improvementPct": "\(improvement * 100)"])
```

---

## Security Compliance

### Data Privacy Levels

```swift
// ✅ SAFE: Public data
log.info("User action", 
    metadata: ["action": "\(action, privacy: .public)"])

// ✅ SAFE: Sensitive data redacted
log.info("Authentication", 
    metadata: ["userId": "\(user.id.hash, privacy: .public)"])

// ❌ UNSAFE: Never log these
// - Authentication tokens
// - Passwords or credentials
// - API keys or secrets
// - Personal identifiable information (PII)
// - Credit card numbers
// - Health information
// - Financial data
```

### Compliance Checklist

- [ ] All tokens and credentials removed from logs
- [ ] PII properly redacted or hashed
- [ ] Privacy levels explicitly set
- [ ] Logs reviewed for compliance
- [ ] Sensitive operations use .private privacy
- [ ] Audit trails don't contain sensitive data
- [ ] Log rotation configured for production
- [ ] Access to logs is controlled

---

## Resources

### Apple Documentation
- [OSLog Official Documentation](https://developer.apple.com/documentation/os/logging)
- [Unified Logging System](https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_app)
- [Privacy Considerations](https://developer.apple.com/documentation/os/logging/protecting_privacy_when_logging_messages)

### Anigma-Specific
- [OSLog Audit Report](OSLOG_AUDIT_REPORT.md)
- [Backend Architecture](ARCHITECTURE.md)
- [Security Guidelines](SECURITY_GUIDELINES.md)

---

**Last Updated**: 2026-04-09  
**Maintainer**: Backend Team  
**Questions**: #backend-logging Slack channel