# GovernedMigrationCore

## Overview

GovernedMigrationCore is a Swift module in the Anigma ecosystem with **953 lines of code** across **4 files**.

## Statistics

- **Public Types**: 12
- **Public Functions**: 9  
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

- `AnigmaPrimitives`
- `ContractsCore`
- `DatabaseCore`

## File Structure


### CSDoctrineGuard.swift

- **Lines**: 38
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `check` (line 15)


### ConcurrencyDoctrinePack.swift

- **Lines**: 86
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct ConcurrencyDoctrinePack` (line 6)



**Public Functions:**
- `evaluate` (line 9)


### DoctrineViolationLogger.swift

- **Lines**: 71
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `protocol DoctrineViolationLogger` (line 8)



**Public Functions:**
- `record` (line 19)


### GovernedMigrationAPI.swift

- **Lines**: 758
- **Public Types**: 10
- **Public Functions**: 6


**Public Types:**
- `struct GovernedMigrationAPI` (line 11)
- `struct MigrationBatchResult` (line 627)
- `struct TrustChange` (line 635)
- `struct TrustScore` (line 644)
- `struct SecurityEvent` (line 655)
- `struct GovernanceMode` (line 675)
- `struct GovernanceSnapshot` (line 681)
- `struct MigrationTraceStep` (line 689)
- `enum GovernedMigrationError` (line 726)
- `struct MigrationTaskDetails` (line 731)



**Public Functions:**
- `runSwift6DiscoveryAndTaskCreation` (line 22)
- `runSwift6Steps` (line 46)
- `currentGovernanceSnapshot` (line 161)
- `queryMigrationTraceSteps` (line 186)
- `latestMigrationTraceStep` (line 249)
- `queryMigrationTaskDetails` (line 279)


