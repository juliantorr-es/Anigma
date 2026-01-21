# HarmoniaSpine

## Overview

HarmoniaSpine is a Swift module in the Anigma ecosystem with **1292 lines of code** across **7 files**.

## Statistics

- **Public Types**: 6
- **Public Functions**: 10  
- **Components**: 0
- **Systems**: 3
- **Services**: 0

## Architecture

### Components
No components found

### Systems
- `MigrationEngine`
- `MigrationEngineFactory`
- `Swift6MigrationEngine`

### Services
No services found

## Dependencies

- `AnigmaASTServicesCore`
- `AnigmaPrimitives`
- `AnigmaCore`
- `DatabaseCore`

## File Structure


### MigrationRules/SendableConformanceRule.swift

- **Lines**: 245
- **Public Types**: 0
- **Public Functions**: 0





### MigrationTaskRow+Convenience.swift

- **Lines**: 25
- **Public Types**: 0
- **Public Functions**: 0





### ScoutFinding.swift

- **Lines**: 53
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `enum ScoutFindingSeverity` (line 4)
- `struct ScoutFinding` (line 11)




### Systems/MigrationEngine.swift

- **Lines**: 584
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `protocol MigrationEngine` (line 17)
- `struct MigrationEngineFactory` (line 96)
- `struct Swift6MigrationEngine` (line 112)



**Public Functions:**
- `engine` (static) (line 101)
- `process` (line 145)


### Utilities/CircuitBreaker.swift

- **Lines**: 123
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `enum CircuitBreakerState` (line 97)



**Public Functions:**
- `recordFailure` (line 30)
- `recordSuccess` (line 58)
- `reset` (line 70)
- `getState` (line 77)


### Utilities/MigrationTraceStore.swift

- **Lines**: 138
- **Public Types**: 0
- **Public Functions**: 3




**Public Functions:**
- `waitUntilReady` (line 69)
- `record` (line 73)
- `latestOutcome` (line 105)


### Utilities/SQLiteHelpers.swift

- **Lines**: 124
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `loadMigrationTasks` (line 6)


