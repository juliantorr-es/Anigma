# GovernanceCore

## Responsibility
**Tier 1: Constitutional Infrastructure**. 
This module defines the fundamental governance mechanisms of the Anigma system. It is designed to be purely logic-driven with zero side effects (except audit logging), acting as the ultimate authority for system behavior.

## Key Mechanisms

### 1. KillSwitch
The emergency halt system.
- **Global Halt**: Disables all write operations across the entire platform.
- **Project Halt**: Disables writes for specific tenants or workflows.
- **Invariants**: Must be check-before-write in all integration layers.

### 2. WriteGate
The quality and policy enforcement pipeline.
- **Extensible Checks**: Allows registration of custom `WriteCheck` protocols.
- **Blocking vs. Non-Blocking**: Distinguishes between critical policy violations and warnings.
- **Audit Integration**: Automatically records all decisions to the `AuditLogging` service.

## Usage Example

```swift
let gate = WriteGate()
await gate.registerCheck(MySecurityCheck())

let proposal = WriteProposal(
    principal: "ai-agent-42",
    module: "DataAnalysis",
    operation: "update_record"
)

let decision = await gate.evaluate(proposal)
if decision.allowed {
    // Proceed with write
}
```

## Maturity Level
**Level 5 (Golden)**: Strict concurrency enabled, full unit testing of invariants, architecturally documented.
