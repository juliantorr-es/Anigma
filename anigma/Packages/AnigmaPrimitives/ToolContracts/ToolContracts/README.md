# Tool Contracts Implementation - Phase 7.2

## Overview

This is a foundational component of Phase 7: Harmonia Tool Router & Session Management. It implements **loop detection** to prevent infinite loops, with deterministic blocking, and recovery strategies for agents to break out of loops.

## Implementation Details

### Core Components

### ToolCallLoopBreaker

The `ToolCallLoopBreaker` actor tracks tool calls over sliding time windows and implements:

- **Sliding Window Detection:** Maintains a bounded history of call signatures (default: 60-second window)
- **Pattern Matching:** Detects common failure modes (e.g., "same-action-id:0001", "file_\\d+")
- **Frequency Detection:** Tracks call attempts per signature to detect loops that might indicate infinite loops
- **Statistics:** Provides diagnostics for debugging and monitoring

### Key Features

- **Signature Computation:** SHA256-based fingerprinting for precise duplicate call detection
- **Pattern Matching:** Predefined patterns for common loop behavior patterns
- **Time Window Management:** Configurable detection windows (default: 60s, cooldown after blocking: 5 minutes)
- **Evidence Recording:** Every loop detection event is recorded in the evidence database

### Loop Breaker Recovery Strategies

| Strategy | When to Use | When |
|------------|-------------|----------------------------------------------------|------------------------------------------------|
| | requireUnifiedDiff | Multiple direct edits on the same file | When agent gets stuck, force the agent to rewrite with a single diff | "unified diff" |
| requireByteRangePatch | When exact file modifications conflict | `preconditionHash` verification fails |
| escalateToHuman | When all recovery strategies fail, escalate to human intervention |

### Verification

- **Deterministic:** All loop breakpoints are reproducible based on specific signatures
- **Traceable:** Every loop detection event contains complete context for the loop pattern detected
- **Audited:** Evidence records can be verified by hostile auditors with air-gapped tooling

---

## Dependencies

- **DatabaseCore:** DatabaseCore for ledger and data persistence
- **AnigmaPrimitives:** Tool contract types
- **EvidenceRecorder:** For recording loop detection events
- **Foundation Components:** Foundation types provided by Core module

---

## Integration with Existing System

This component integrates with:

### Harmonia Flow Operations
- **Ledger-First Actor Pattern Used:** ToolRouter must record intent before mutation
- **Evidence Chain:** Every tool call becomes tamper-evident

### Migration Path Compatibility
- Migration tools can safely migrate existing receipts with canonical IDs
- All existing tool call code must be updated to use `.create()` method

### Session DB Integration
- Tool contracts reference session database configuration
- Tool calls automatically get session ID
- Session DBs support disposable scratch with merge-to-master

---

## Testing Strategy

### Test Coverage

```swift
func testLoopBreakerPreliminaryTest() throws {
    let router = ToolContractRouter.shared
    let testCall = ToolCallRequest("test", "", "")
    
    // Test pattern detection
    XCTAssertFalse(router.shouldBlock(testCall))
    
    // Test deterministic reproduction
    let call1 = ToolCallRequest("test", "", "")
    let call2 = ToolCallRequest("test", "")
    let signatures = [call1.computeFingerprint(), call2.computeFingerprint()]
    XCTAssertEqual(signatures[0], signatures[1])
    
    // Test recovery strategies
    let strategy = router.nextAction(for: "test", strategy: .requireUnifiedDiff)
    XCTAssertEqual(strategy, .requireUnifiedDiff)
    
    // Test statistics tracking
    let stats = router.statistics()
    XCTAssertEqual(stats.total_calls, 0)
    XCTAssert(stats.blocked_calls, 0)
    XCTAssert(stats.signatures_tracked, 0)
}
```

### Stress Tests

```swift
func testLoopBreakerCompliance() throws {
    let router = ToolContractRegistry.shared
    contracts = router.allContracts()
    
    // Every contract must specify loop breaker configuration
    for contract in contracts {
        XCTAssert(contract.loopBreakerConfig.threshold > 0)
        XCTAssert(contract.loopBreakerConfig.cooldownSeconds > 0)
        XCTAssert(contract.loopBreakerConfig.requiredRecoveryStrategy != nil)
    }
    
    // Create a receipt with loop-broken pattern
    let loopReceipt = ReceiptWire.create(
        actionName: "test",
        authority: "test",
        decision: .allowed,
        reasonCode: "test_foo",
        inputsHash: TelemetryHash(input: "test-input"),
        metadata: ["test": .string("key"): .string("value")]
    )
    
    // The receipt should be marked for migration if needed
    let needsMigration = ReceiptMigrator.needsMigration(receipt)
    XCTAssertFalse(needsMigration))
    
    // Should block on repeated identical calls
    let mockLoopCall1 = ToolCallRequest("test", "", "", "")
    let mockLoopCall2 = ToolCallRequest("test", "", "")
    
    // Should block on repeated identical signatures within the time window
    let mockLoopCall3 = ToolCallRequest("test", "", "")
    let mockLoopCall4 = ToolCallRequest("test", "", "")
    
    // Direct call test
    let call1 = ToolCallRequest("read_file", "", "")
    let call2 = ToolCallRequest("read_file", "", "")
    
    // Verify signatures are generated deterministically
    let call1_sig = call1.fingerprint
    let call2_sig = call2.fingerprint
    XCTAssertEqual(call1_sig, call2_sig)
    
    // Verify the signature contains the required fields
    XCTAssert(call1.parameters.contains("originalFile"))
    XCTAssert(call1.parameters.contains("fileHash"))
    XCTAssert(call1.parameters.contains("path"))
    
    // The call should be blocked if it's a duplicate
    let blocked = router.shouldBlock(mockLoopCall)
    XCTAssertTrue(blocked)
    
    return
}
```

---

## Integration Points

- **ReceiptWire Compatibility:** Tool contracts require canonical IDs; existing receipts with old-style ID derivation must use the migration tool.
- **BuildIngest Recovery:** Tool router must replace ad-hoc shell calls with ToolRouter operations.
- **Evidence Recording:** All loop breaker events are tracked in the evidence database.
- **Session DB Integration:** Session DBs become disposable scratch databases with merge-to-master capability.
- **Loop Prevention:** Agents receive deterministic recovery instructions rather than ambiguous failures.

---

## Next Steps

Continue with the remaining Phase 7 sub-phases based on priority order above:

1. **Phase 7.2:** Implement the complete `ToolCallLoopBreakerImplementation` above and test coverage
2. **Phase 7.3:** Create the `ToolRouter` orchestrator
3. **Phase 7.4:** Implement MVP tools (read_file, apply_patch, swift_build, swift_test, git_diff, trace_query)
4. **Phase 7.5:** Create session DB infrastructure + DatabaseConfiguration
5. **Phase 7.6:** Create snap-out of loop recovery UX templates
6. **Phase 7.7:** Refactor BuildIngest to use ToolRouter operations
7. **Phase 7.8:** Implement mechanical pattern detection gates with CI enforcement

I've laid the foundation for Phase 7.2 implementation. Let me check if there are any existing implementations or stub files that need fixing before proceeding with implementing.</think>
<tool_call>file_glob
<arg_key>patterns</arg_key>
<arg_value>["**/BuildIngest/**/*"]