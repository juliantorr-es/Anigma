> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# AnigmaPrimitives

## Overview

AnigmaPrimitives is a Swift module in the Anigma ecosystem with **340 lines of code** across **3 files**.

## Statistics

- **Public Types**: 9
- **Public Functions**: 5  
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


### Contracts.swift

- **Lines**: 125
- **Public Types**: 4
- **Public Functions**: 2


**Public Types:**
- `enum GovernanceMode` (line 4)
- `enum TrustTier` (line 11)
- `enum RiskLevel` (line 41)
- `struct AstAnchor` (line 50)



**Public Functions:**
- `minimum` (static) (line 23)
- `maximum` (static) (line 31)


### MigrationTraceSink.swift

- **Lines**: 63
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `struct MigrationStepOutcome` (line 4)
- `protocol MigrationTraceSink` (line 42)
- `struct NoopMigrationTraceSink` (line 53)



**Public Functions:**
- `record` (line 59)


### MigrationTypes.swift

- **Lines**: 152
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct MigrationTaskRow` (line 4)
- `enum MigrationResult` (line 72)



**Public Functions:**
- `skipped` (static) (line 99)
- `failed` (static) (line 107)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
