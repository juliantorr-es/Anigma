> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Phase 5 Complete: Loop Breakers & Safety

**Date**: 2026-01-10  
**Status**: ✅ Complete  
**Overall Progress**: 50% (5 of 10 phases)

## Summary

Phase 5 implements comprehensive safety limits and loop detection to prevent runaway executions. The loop breaker monitors multiple dimensions (steps, time, resources, patterns) and gracefully terminates runs when limits are exceeded.

## Components Implemented

### 1. CLILoopBreaker (320 lines)
**Location**: `Packages/AnigmaCLI/Database/CLILoopBreaker.swift`

**Features**:
- ✅ Configurable limit enforcement
- ✅ Multiple safety dimensions
- ✅ Pattern detection (repeated calls, no-novelty)
- ✅ Counter tracking with state inspection
- ✅ Receipt integration for audit trail

**Limits Enforced**:

| Limit | Default | Description |
|-------|---------|-------------|
| Max Steps | 50 | Total execution steps |
| Max Tool Calls | 100 | Number of tool invocations |
| Max Wall Time | 1800s (30m) | Real-time execution duration |
| Max Tokens | unlimited* | Token consumption (configurable) |
| Max Spend | unlimited* | Dollar spend (configurable) |
| Repeated Calls | 3 | Same call N times in a row |
| No-Novelty Window | 3 | Steps without new evidence |

*Can be configured per-run

**Usage**:
```swift
let config = LoopBreakerConfig(
    maxSteps: 50,
    maxToolCalls: 100,
    maxWallTimeSeconds: 1800,
    maxTokens: 10000,
    maxSpend: 5.0,
    repeatedCallThreshold: 3,
    noNoveltyWindow: 3
)

let loopBreaker = CLILoopBreaker(runID: runID, config: config)

// Record activity
await loopBreaker.recordStep()
await loopBreaker.recordToolCall(toolName: "read_file", args: "path.txt")
await loopBreaker.recordTokens(count: 150)
await loopBreaker.recordNovelty(hash: "abc123...")

// Check limits
if let result = await loopBreaker.shouldStop() {
    print("Stop reason: \(result.reason)")
    print("Message: \(result.message)")
    print("Counters: \(result.counters)")
}
```

**Pattern Detection**:

1. **Repeated Calls**: Detects when the same tool with same args is called N times consecutively
   ```
   read_file path.txt  ← 1
   read_file path.txt  ← 2
   read_file path.txt  ← 3 (STOP!)
   ```

2. **No Novelty**: Detects when no new evidence (file changes, diffs) is produced for N steps
   ```
   Step 1: (no novelty)
   Step 2: (no novelty)
   Step 3: (no novelty) ← STOP!
   ```

**Stop Receipt Generation**:
```swift
let receipt = try await receiptManager.recordLoopBreaker(
    runID: runID,
    result: stopResult
)
```

Receipt includes:
- Stop reason (max_steps, max_time, etc.)
- All counter values at stop time
- Last action performed
- Full metadata for audit

### 2. CLIOrchestratorIntegration Updates
**Location**: `Packages/AnigmaCLI/Orchestrator/CLIOrchestratorIntegration.swift`

**New Features**:
- ✅ Automatic loop breaker creation per run
- ✅ Pre-execution limit checking
- ✅ Stop receipt generation on trigger
- ✅ Graceful run cancellation
- ✅ Counter logging in event stream

**Flow**:
```
1. Create run
2. Create loop breaker with config
3. Update run status → running
4. Record step
5. Check loop breaker.shouldStop()
   ├─ If triggered:
   │  ├─ Generate stop receipt
   │  ├─ Update step status → failed
   │  ├─ Update run status → cancelled
   │  └─ Return with error
   └─ If OK: Continue execution
6. Execute orchestrator
7. Log final counters
8. Complete run
```

### 3. LoopBreakerCommand (220 lines)
**Location**: `Packages/AnigmaCLI/Executable/LoopBreakerCommand.swift`

**Subcommands**:

#### `loop-breaker test`
Test different loop breaker scenarios:

```bash
# Test max steps
$ anigma-cli loop-breaker test --scenario max-steps

🧪 Loop Breaker Test: max-steps

Testing max steps limit (5)...

✅ Step 1 passed
✅ Step 2 passed
✅ Step 3 passed
✅ Step 4 passed
✅ Step 5 passed
🛑 Loop breaker triggered at step 6!
   Reason: max_steps
   Message: Maximum steps (5) exceeded

📊 Final Counters:
   Steps:      6
   Tool Calls: 0
   Tokens:     0
   Spend:      $0.00
   Wall Time:  0.1s
```

**Test Scenarios**:
- `max-steps`: Exceeds step limit
- `max-time`: Exceeds wall time limit
- `repeated-calls`: Triggers repeated call detection
- `no-novelty`: Triggers no-novelty detection

#### `loop-breaker config`
Display current configuration:

```bash
$ anigma-cli loop-breaker config

🔧 Loop Breaker Configuration (Default):

Max Steps:              50
Max Tool Calls:         100
Max Wall Time:          1800s (30m)
Max Tokens:             unlimited
Max Spend:              unlimited
Repeated Call Threshold: 3
No-Novelty Window:      3 steps
```

## Integration Points

### With Phase 3 (Receipts)
- ✅ Stop receipts with full metadata
- ✅ Counter values captured
- ✅ Trigger reason hashed
- ✅ Chain integrity maintained

### With Phase 4 (Runs/Steps)
- ✅ Loop breaker created per run
- ✅ Step counting integrated
- ✅ Run cancellation on trigger
- ✅ Error messages in step records

### With Orchestrator
- ✅ Pre-execution checking
- ✅ Graceful termination
- ✅ Event stream integration
- ✅ Counter logging

## Files Created/Modified

**Created**:
1. `Packages/AnigmaCLI/Database/CLILoopBreaker.swift` (320 lines)
2. `Packages/AnigmaCLI/Executable/LoopBreakerCommand.swift` (220 lines)

**Modified**:
1. `Packages/AnigmaCLI/Orchestrator/CLIOrchestratorIntegration.swift` (+80 lines)
2. `Packages/AnigmaCLI/Executable/Main.swift` (added AnigmaLoopBreakerCommand)

**Total**: 620 new lines

## Command Line Interface

### New Commands
```bash
anigma-cli loop-breaker test --scenario <scenario> [--verbose]
anigma-cli loop-breaker config
```

### Total Commands Now Available
- `index` (3 subcommands)
- `worktree` (6 subcommands)
- `runs` (3 subcommands)
- `loop-breaker` (2 subcommands)
- **Total: 14 commands across 4 command groups**

## Safety Guarantees

### Hard Limits
1. **No infinite loops**: Max steps enforced
2. **No time bombs**: Wall time limit prevents hangs
3. **Resource bounds**: Token/spend limits configurable
4. **Pattern detection**: Catches common failure modes

### Graceful Degradation
1. **Receipt generation**: Even on failure
2. **Clean state**: Run marked as cancelled
3. **Error context**: Full counters in message
4. **Audit trail**: Stop reason captured

### Configurability
```swift
// Strict limits for testing
let testConfig = LoopBreakerConfig(
    maxSteps: 10,
    maxWallTimeSeconds: 60,
    repeatedCallThreshold: 2
)

// Relaxed limits for production
let prodConfig = LoopBreakerConfig(
    maxSteps: 100,
    maxWallTimeSeconds: 3600,
    maxTokens: 50000,
    maxSpend: 10.0
)
```

## Testing

### Automated Tests
- ⏳ Unit tests: Not yet implemented
- ⏳ Integration tests: Not yet implemented

### Manual Tests
✅ All test scenarios verified:
- Max steps trigger
- Max time trigger
- Repeated calls detection
- No-novelty detection
- Counter tracking
- Receipt generation

## Compliance with SURFACE Contract

### ✅ New Achievements
- [x] Loop breaker limits (maxSteps, maxToolCalls, maxWallTime)
- [x] Token/spend tracking
- [x] Repeated call detection
- [x] No-novelty window detection
- [x] Stop receipts with counters
- [x] Graceful run termination

### From SURFACE Contract
> Loop breakers: Implement orchestrator-level counters (steps, tool calls, wall/time, tokens/spend, repeated calls, "no novelty") with stop receipts.

✅ All requirements met

## Progress Metrics

| Metric | Value | Change |
|--------|-------|--------|
| Phases Complete | 5/10 | +1 |
| Components | 8 actors | +1 |
| Commands | 14 | +2 |
| Files Created | 13 | +2 |
| Lines of Code | ~4,820 | +620 |
| Overall Completion | 50% | +10% |

## Technical Highlights

### Actor-Based Safety
- Thread-safe counter updates
- Atomic limit checking
- Isolated per-run state

### Multi-Dimensional Limits
- Not just "max iterations"
- Resource consumption (tokens, $)
- Time bounds (wall clock)
- Pattern detection (behavioral)

### Deterministic Behavior
- Same config → same limits
- Reproducible across runs
- Testable with scenarios

### Receipt Integration
- Every stop is documented
- Counter snapshot preserved
- Audit trail complete

## Example: Full Run with Loop Breaker

```swift
// 1. Create run
let run = try await runManager.createRun(
    taskSummary: "Refactor auth module",
    mode: .run,
    dryRun: false
)

// 2. Create loop breaker
let loopBreaker = CLILoopBreaker(runID: run.runID)

// 3. Execute steps
for stepNum in 1...100 {
    await loopBreaker.recordStep()
    
    // Check before each step
    if let stop = await loopBreaker.shouldStop() {
        // Generate stop receipt
        _ = try await receiptManager.recordLoopBreaker(
            runID: run.runID,
            result: stop
        )
        
        // Cancel run
        try await runManager.updateRunStatus(
            runID: run.runID,
            status: .cancelled,
            message: stop.message
        )
        
        throw ExecutionError.loopBreakerTriggered(stop)
    }
    
    // Do actual work
    await executeStep(stepNum)
}
```

## Next Steps (Phase 6)

Focus shifts to **Policy & Approval Gates**:
1. CLIPolicyEngine for default-deny enforcement
2. Allowlist management (tools, MCP servers)
3. Approval workflow (interactive/automatic)
4. RepoIdentity gate integration
5. MCP trust model (hash/signature verification)

## Summary

Phase 5 adds critical safety infrastructure to prevent runaway executions. The system now has:

- **Multi-dimensional limits**: Steps, time, resources, patterns
- **Graceful termination**: Proper cleanup and receipts
- **Configurability**: Per-run limit customization
- **Testability**: Demo commands for validation
- **Integration**: Seamlessly wired into orchestrator

**Status**: ✅ Phase 5 Complete - Ready for Phase 6 (Policy & Approval Gates)

---

**Halfway there!** 🎉 5 of 10 phases complete, 50% progress achieved.
