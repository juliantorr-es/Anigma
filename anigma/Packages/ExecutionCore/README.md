# ExecutionCore

**The execution engine for Anigma, managing receipts, phase gates, and command ledgers.**

ExecutionCore is responsible for the deterministic execution of commands, ensuring that every significant action is recorded as a "Receipt" and gated by specific "Phase Gates". It provides a command ledger for auditing and a transport abstraction for inter-module communication.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ExecutionCore                        │
├─────────────────────────────────────────────────────────┤
│  Receipt Engine         │  Phase Gate Engine            │
│  ──────────────         │  ─────────────────            │
│  • Generation           │  • Policy Evaluation          │
│  • Signing              │  • Transition Control         │
│  • Persistence          │  • Verification               │
├─────────────────────────────────────────────────────────┤
│  Command Ledger         │  Transport Abstraction        │
│  ──────────────         │  ─────────────────────        │
│  • History Tracking     │  • Async Communication        │
│  • Session Mgmt         │  • Payload Encoding           │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Receipt Engine

Receipts are the "ground truth" of what happened in the system. Every command that changes state or crosses a trust boundary generates a receipt.

```swift
public struct ReceiptWire: Codable {
    public let receiptID: String
    public let actionName: String
    public let authority: String
    public let decision: ReceiptDecision
    public let timestampMs: Int64
    public let inputsHash: TelemetryHash
    public let metadata: [String: TelemetryValue]
}
```

### 2. Phase Gate Engine

Phase gates ensure that transitions between different execution phases (e.g., from `PLANNING` to `EXECUTION`) are authorized by policy.

```swift
public actor PhaseGateEngine {
    func evaluateTransition(from: String, to: String, context: [String: Any]) async throws -> PhaseDecision
    func verifyReceipts(for phase: String) async throws -> Bool
}
```

### 3. Command Ledger

The Command Ledger is a persistent log of every command initiated by an agent or user.

```swift
public actor CommandLedger {
    func record(kind: String, command: String, agent: String, sessionID: String) async throws
    func fetchLatest(limit: Int) async throws -> [CommandLedgerWire]
}
```

### 4. Transport Abstraction

A unified interface for asynchronous messaging between components.

```swift
public protocol TransportProtocol: Actor {
    func send(_ payload: Data, to recipient: String) async throws
    func receive() async throws -> (Data, String)
}
```

## Usage Examples

### Generating a Receipt

```swift
import ExecutionCore

let engine = ExecutionCoreFactory.createReceiptEngine(signer: mySigner, store: myStore)
let receipt = try await engine.generateReceipt(
    action: "create_file",
    authority: "principal@anigma.io",
    inputs: ["path": "/tmp/test.txt"]
)
```

### Evaluating a Phase Gate

```swift
let gateEngine = ExecutionCoreFactory.createPhaseGateEngine(
    policyEvaluator: myEvaluator,
    receiptEngine: myReceiptEngine
)

let result = await gateEngine.evaluateTransition(
    from: "PLANNING",
    to: "EXECUTION",
    context: ["proposal": myProposal]
)

if result.isAllowed {
    // Proceed with execution
}
```

### Recording to Command Ledger

```swift
let ledger = ExecutionCoreFactory.createCommandLedger(repoRoot: repoURL)
try await ledger.record(
    kind: "system_command",
    command: "git commit",
    agent: "harmonia-agent",
    sessionID: "session-123"
)
```

## Thread Safety

- **ReceiptEngine**: `actor`
- **PhaseGateEngine**: `actor`
- **CommandLedger**: `actor`
- **TransportProtocol**: `actor`
- **Wire types**: `Sendable` structs

## Dependencies

- **TelemetryCore**: Hashing and structured telemetry values.

## See Also

- [TelemetryCore](../TelemetryCore/README.md)
- [HarmoniaModule](../../Sources/HarmoniaModule/README.md) - Source of policies for PhaseGateEngine.

## License

Part of the Anigma project. See LICENSE for details.
