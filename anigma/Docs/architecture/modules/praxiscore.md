> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# PraxisCore

## Overview

PraxisCore is a Swift module in the Anigma ecosystem with **2286 lines of code** across **23 files**.

## Statistics

- **Public Types**: 72
- **Public Functions**: 62  
- **Components**: 0
- **Systems**: 0
- **Services**: 0

## Architecture

### Components
No components found

### Systems
No systems found

### Services
No services found

## Dependencies

No internal dependencies

## File Structure


### BoundaryTicketService.swift

- **Lines**: 124
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct BlockageEvent` (line 5)
- `struct BoundaryTicket` (line 43)
- `struct BoundaryTicketService` (line 84)



**Public Functions:**
- `createTicket` (line 92)
- `persist` (line 114)


### CommandSystem/AgentProfile.swift

- **Lines**: 84
- **Public Types**: 5
- **Public Functions**: 2


**Public Types:**
- `enum PermissionDecision` (line 3)
- `struct PermissionPolicy` (line 9)
- `struct AgentProfile` (line 30)
- `enum AgentProfileRegistryError` (line 42)
- `struct AgentProfileRegistry` (line 46)



**Public Functions:**
- `evaluate` (line 18)
- `profile` (line 53)


### CommandSystem/CommandEventBus.swift

- **Lines**: 51
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `enum CommandEventKind` (line 3)
- `struct CommandEvent` (line 9)



**Public Functions:**
- `shared` (static) (line 24)
- `emit` (line 37)


### CommandSystem/CommandEventReader.swift

- **Lines**: 31
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct CommandEventReader` (line 3)



**Public Functions:**
- `listEvents` (line 10)


### CommandSystem/CommandLedger.swift

- **Lines**: 57
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `struct CommandLedgerMeta` (line 3)
- `struct CommandLedgerRecord` (line 10)
- `struct CommandLedger` (line 24)



**Public Functions:**
- `append` (line 37)


### CommandSystem/CommandLedgerReader.swift

- **Lines**: 34
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct CommandLedgerReader` (line 3)



**Public Functions:**
- `load` (line 16)
- `sessions` (line 30)


### CommandSystem/CommandReceipts.swift

- **Lines**: 64
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct CommandExecutionReceipt` (line 3)
- `struct CommandReceiptWriter` (line 28)



**Public Functions:**
- `write` (line 35)


### CommandSystem/CommandRenderer.swift

- **Lines**: 14
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct CommandRenderer` (line 3)



**Public Functions:**
- `render` (line 6)


### CommandSystem/CommandSpec.swift

- **Lines**: 36
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `enum CommandSpecSource` (line 3)
- `struct CommandSpec` (line 9)




### CommandSystem/CommandSpecCatalog.swift

- **Lines**: 173
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct CommandSpecCatalog` (line 3)



**Public Functions:**
- `loadSpecs` (line 10)
- `spec` (line 31)


### CommandSystem/SessionStore.swift

- **Lines**: 93
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `struct CommandSession` (line 3)
- `struct SessionStore` (line 17)



**Public Functions:**
- `createSession` (line 38)
- `load` (line 46)
- `recordCommand` (line 52)
- `lastSessionID` (line 58)
- `setLastSessionID` (line 63)
- `resolveSession` (line 68)


### PraxisModule.swift

- **Lines**: 114
- **Public Types**: 4
- **Public Functions**: 2


**Public Types:**
- `struct PatchSummary` (line 4)
- `struct SessionSummary` (line 36)
- `struct PraxisDiagnosis` (line 53)
- `struct PraxisModuleEnvironment` (line 62)



**Public Functions:**
- `diagnose` (line 75)
- `createBoundaryTicket` (line 108)


### PraxisSessionIndex.swift

- **Lines**: 275
- **Public Types**: 9
- **Public Functions**: 3


**Public Types:**
- `struct GateOutcome` (line 4)
- `struct LedgerRecordDetail` (line 19)
- `struct LedgerRecord` (line 36)
- `struct LedgerMeta` (line 68)
- `struct QuarantineRecord` (line 77)
- `struct GateFailure` (line 85)
- `struct SessionRecord` (line 101)
- `struct PatchReceiptChain` (line 117)
- `struct PraxisSessionIndex` (line 136)



**Public Functions:**
- `session` (line 150)
- `describeSessions` (line 154)
- `missingPhases` (static) (line 269)


### RepoIdentityGate/RepoIdentityGate.swift

- **Lines**: 145
- **Public Types**: 6
- **Public Functions**: 2


**Public Types:**
- `struct RepoIdentityConfig` (line 3)
- `struct RepoIdentityGateResult` (line 25)
- `enum Verdict` (line 26)
- `enum RepoIdentityGateError` (line 44)
- `struct RepoIdentityGate` (line 58)
- `enum Mode` (line 59)



**Public Functions:**
- `loadOrCreateDefaultConfig` (line 66)
- `evaluate` (line 83)


### Rulepack.swift

- **Lines**: 70
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct RuleEvaluation` (line 4)
- `struct Rulepack` (line 19)
- `struct RuleAction` (line 61)



**Public Functions:**
- `load` (static) (line 28)
- `evaluate` (line 38)


### StackManager/GitRunner.swift

- **Lines**: 196
- **Public Types**: 5
- **Public Functions**: 15


**Public Types:**
- `struct GitOpArtifactRefs` (line 4)
- `struct GitOpResult` (line 9)
- `enum GitRunnerError` (line 17)
- `struct GitRunner` (line 29)
- `struct ArtifactWriter` (line 159)



**Public Functions:**
- `repoRoot` (line 36)
- `headSHA` (line 41)
- `currentBranchName` (line 45)
- `isDirty` (line 52)
- `branchExists` (line 57)
- `fetch` (line 66)
- `checkout` (line 70)
- `createBranch` (line 74)
- `checkoutNewBranch` (line 78)
- `rebase` (line 82)
- `mergeNoFF` (line 86)
- `mergeSquash` (line 90)
- `deleteBranch` (line 94)
- `revParse` (line 98)
- `run` (line 109)


### StackManager/PraxisReceipts.swift

- **Lines**: 93
- **Public Types**: 5
- **Public Functions**: 2


**Public Types:**
- `struct PraxisReceipt` (line 3)
- `struct RepoInfo` (line 4)
- `struct GateInfo` (line 11)
- `enum Outcome` (line 16)
- `struct ReceiptWriter` (line 51)



**Public Functions:**
- `writeReceipt` (line 58)
- `writeTicket` (line 76)


### StackManager/StackOps.swift

- **Lines**: 297
- **Public Types**: 3
- **Public Functions**: 5


**Public Types:**
- `enum StackOpsError` (line 3)
- `struct StackOps` (line 23)
- `enum LandStrategy` (line 207)



**Public Functions:**
- `stackInit` (line 46)
- `stackCreate` (line 66)
- `stackStatus` (line 123)
- `stackSync` (line 169)
- `stackLand` (line 209)


### StackManager/StackPlanner.swift

- **Lines**: 65
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `enum StackPlannerError` (line 3)
- `struct StackPlanner` (line 15)



**Public Functions:**
- `orderedBranches` (line 18)
- `tipBranchName` (line 55)


### StackManager/StackRecord.swift

- **Lines**: 41
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct StackRecord` (line 3)
- `struct Branch` (line 4)




### StackManager/StackStore.swift

- **Lines**: 89
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `enum StackStoreError` (line 3)
- `struct StackStore` (line 17)



**Public Functions:**
- `stacksDir` (line 24)
- `stackURL` (line 29)
- `listStackIDs` (line 34)
- `load` (line 44)
- `save` (line 55)
- `create` (line 68)


### StackManager/ValidationMatrixGate.swift

- **Lines**: 92
- **Public Types**: 5
- **Public Functions**: 2


**Public Types:**
- `struct ValidationMatrixConfig` (line 3)
- `struct ValidationRun` (line 13)
- `struct ValidationMatrixResult` (line 20)
- `enum Verdict` (line 21)
- `struct ValidationMatrixGate` (line 26)



**Public Functions:**
- `loadOrCreateDefaultConfig` (line 29)
- `run` (line 43)


### WorkflowSpec.swift

- **Lines**: 48
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `enum WorkflowStopState` (line 4)
- `struct WorkflowStep` (line 12)
- `struct WorkflowSpec` (line 27)



**Public Functions:**
- `load` (static) (line 36)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
