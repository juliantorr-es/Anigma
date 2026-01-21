# HarmoniaMemory

## Overview

HarmoniaMemory is a Swift module in the Anigma ecosystem with **1828 lines of code** across **5 files**.

## Statistics

- **Public Types**: 18
- **Public Functions**: 30  
- **Components**: 0
- **Systems**: 6
- **Services**: 0

## Architecture

### Components
No components found

### Systems
- `ObservationCaptureConfig`
- `ToolCallComponent`
- `RequestComponent`
- `SessionComponent`
- `RequestPhase`
- `ModelKind`

### Services
No services found

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### HarmoniaMemory.swift

- **Lines**: 148
- **Public Types**: 3
- **Public Functions**: 8


**Public Types:**
- `enum HarmoniaMemoryVersion` (line 18)
- `enum HarmoniaMemory` (line 36)
- `struct MemoryConfig` (line 122)



**Public Functions:**
- `register` (static) (line 37)
- `createMemoryService` (static) (line 61)
- `storeObservation` (line 79)
- `searchObservations` (line 84)
- `getSessionSummary` (line 99)
- `updateSessionSummary` (line 104)
- `getActiveSessions` (line 109)
- `endSession` (line 114)


### Models/MemoryObservation.swift

- **Lines**: 340
- **Public Types**: 6
- **Public Functions**: 4


**Public Types:**
- `struct MemoryObservation` (line 13)
- `enum ObservationType` (line 85)
- `enum ObservationSource` (line 121)
- `struct ObservationResult` (line 145)
- `struct ObservationError` (line 172)
- `struct ToolCall` (line 204)



**Public Functions:**
- `toolCall` (static) (line 224)
- `toolResult` (static) (line 245)
- `toolError` (static) (line 268)
- `decision` (static) (line 291)


### Models/MemorySessionSummary.swift

- **Lines**: 185
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct MemorySessionSummary` (line 12)



**Public Functions:**
- `initial` (static) (line 146)


### SQLite/SQLiteMemoryStore.swift

- **Lines**: 655
- **Public Types**: 2
- **Public Functions**: 14


**Public Types:**
- `struct DatabaseStats` (line 600)
- `enum MemoryError` (line 608)



**Public Functions:**
- `initialize` (line 30)
- `storeObservation` (line 186)
- `storeCodeAbstraction` (line 213)
- `searchObservations` (line 242)
- `getSessionSummary` (line 307)
- `updateSessionSummary` (line 318)
- `getObservationsForSession` (line 333)
- `getObservationsByType` (line 351)
- `getActiveSessions` (line 375)
- `endSession` (line 394)
- `deleteOldObservations` (line 408)
- `getStats` (line 435)
- `encode` (line 517)
- `encode` (line 576)


### Systems/ObservationCaptureSystem.swift

- **Lines**: 500
- **Public Types**: 6
- **Public Functions**: 3


**Public Types:**
- `struct ObservationCaptureConfig` (line 355)
- `struct ToolCallComponent` (line 389)
- `struct RequestComponent` (line 417)
- `struct SessionComponent` (line 449)
- `enum RequestPhase` (line 473)
- `enum ModelKind` (line 490)



**Public Functions:**
- `setup` (line 54)
- `update` (line 68)
- `teardown` (line 85)


