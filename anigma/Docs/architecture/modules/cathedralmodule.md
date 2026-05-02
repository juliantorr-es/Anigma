> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# CathedralModule

## Overview

CathedralModule is a Swift module in the Anigma ecosystem with **107 lines of code** across **1 files**.

## Statistics

- **Public Types**: 5
- **Public Functions**: 3  
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

- `DatabaseCore`
- `AnigmaCore`
- `ContractsCore`

## File Structure


### CathedralModule.swift

- **Lines**: 107
- **Public Types**: 5
- **Public Functions**: 3


**Public Types:**
- `struct CathedralConfig` (line 17)
- `enum ValidationMode` (line 24)
- `enum CathedralError` (line 51)
- `struct CathedralModule` (line 83)
- `class CathedralCoordinator` (line 92)



**Public Functions:**
- `create` (static) (line 87)
- `validateEvidenceChain` (line 99)
- `recordEvidence` (line 103)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
