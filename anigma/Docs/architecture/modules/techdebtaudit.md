> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# TechDebtAudit

## Overview

TechDebtAudit is a Swift module in the Anigma ecosystem with **282 lines of code** across **2 files**.

## Statistics

- **Public Types**: 7
- **Public Functions**: 1  
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


### TechDebtAudit.swift

- **Lines**: 197
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct TechDebtAudit` (line 3)



**Public Functions:**
- `runAudit` (line 10)


### TechDebtModels.swift

- **Lines**: 85
- **Public Types**: 6
- **Public Functions**: 0


**Public Types:**
- `struct StubMarker` (line 3)
- `struct TechDebtEntry` (line 15)
- `struct TechDebtIssue` (line 29)
- `struct TechDebtEntryPayload` (line 43)
- `struct TechDebtAuditReport` (line 57)
- `enum TechDebtAuditError` (line 79)





Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
