> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# HarmoniaSurface

## Overview

HarmoniaSurface is a Swift module in the Anigma ecosystem with **319 lines of code** across **1 files**.

## Statistics

- **Public Types**: 8
- **Public Functions**: 4  
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

- `AnigmaCore`

## File Structure


### HarmoniaSurface.swift

- **Lines**: 319
- **Public Types**: 8
- **Public Functions**: 4


**Public Types:**
- `enum ModelKind` (line 7)
- `struct ConcurrencyLimits` (line 13)
- `struct ConcurrencyStats` (line 35)
- `struct RequestPhase` (line 67)
- `struct SessionComponent` (line 84)
- `struct RequestComponent` (line 95)
- `struct ConcurrencyStateComponent` (line 116)
- `struct SlotManagementSystem` (line 150)



**Public Functions:**
- `limit` (line 26)
- `recordRequest` (line 58)
- `stats` (line 62)
- `update` (line 158)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
