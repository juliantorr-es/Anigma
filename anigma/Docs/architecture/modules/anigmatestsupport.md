# AnigmaTestSupport

## Overview

AnigmaTestSupport is a Swift module in the Anigma ecosystem with **610 lines of code** across **7 files**.

## Statistics

- **Public Types**: 17
- **Public Functions**: 11  
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

- `ContractsCore`
- `AnigmaCore`
- `DatabaseCore`

## File Structure


### AuditLifecycleCompat.swift

- **Lines**: 143
- **Public Types**: 3
- **Public Functions**: 0


**Public Types:**
- `enum LifecycleSensitivity` (line 41)
- `enum LifecycleState` (line 47)
- `struct LifecycleMetadataComponent` (line 52)




### Compat/Audit/AuditCompat.swift

- **Lines**: 168
- **Public Types**: 4
- **Public Functions**: 1


**Public Types:**
- `enum LegacyAuditEventType` (line 7)
- `struct AuditEntryView` (line 40)
- `struct LegacyAuditingResult` (line 57)
- `struct LegacyComplianceReport` (line 64)



**Public Functions:**
- `toRuntime` (line 16)


### Compat/Contracts/ContractTestCompat.swift

- **Lines**: 75
- **Public Types**: 5
- **Public Functions**: 6


**Public Types:**
- `struct ContractTestCompat` (line 5)
- `class RegistryBuilder` (line 15)
- `struct ReceiptStatusView` (line 31)
- `class PipelineGraphBuilder` (line 51)
- `struct ContractPlanBuilder` (line 66)



**Public Functions:**
- `makeID` (static) (line 6)
- `register` (line 22)
- `build` (line 26)
- `addEdge` (line 56)
- `build` (line 61)
- `makePlan` (static) (line 67)


### Compat/Graphene/GrapheneTestHarness.swift

- **Lines**: 21
- **Public Types**: 0
- **Public Functions**: 2




**Public Functions:**
- `runUntilIdle` (line 12)
- `snapshot` (line 17)


### Compat/Pipeline/PipelineTestKit.swift

- **Lines**: 59
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct PipelineTestConfig` (line 6)
- `enum PipelineTestKit` (line 37)



**Public Functions:**
- `makeHarness` (static) (line 38)


### Compat/Updates/UpdateCompat.swift

- **Lines**: 24
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `enum UpdateCompat` (line 3)
- `struct AddComponentMigrationBridge` (line 13)



**Public Functions:**
- `addComponentMigration` (static) (line 4)


### PolytroposLegacy.swift

- **Lines**: 120
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `enum LegacyVideoCodec` (line 21)




