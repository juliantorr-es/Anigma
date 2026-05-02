> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# HarmoniaCLI

## Overview

HarmoniaCLI is a Swift module in the Anigma ecosystem with **2279 lines of code** across **15 files**.

## Statistics

- **Public Types**: 10
- **Public Functions**: 7  
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
- `DatabaseCore`
- `ContractsCore`

## File Structure


### CLIUtilities.swift

- **Lines**: 42
- **Public Types**: 0
- **Public Functions**: 0





### CommandCommands/CommandAudit.swift

- **Lines**: 52
- **Public Types**: 0
- **Public Functions**: 0





### CommandCommands/CommandCommand.swift

- **Lines**: 208
- **Public Types**: 0
- **Public Functions**: 0





### CommandCommands/SessionCommand.swift

- **Lines**: 52
- **Public Types**: 0
- **Public Functions**: 0





### GCCommand.swift

- **Lines**: 183
- **Public Types**: 0
- **Public Functions**: 0





### Main.swift

- **Lines**: 85
- **Public Types**: 0
- **Public Functions**: 0





### PipelineStatusCommand.swift

- **Lines**: 109
- **Public Types**: 0
- **Public Functions**: 0





### PraxisCommands.swift

- **Lines**: 134
- **Public Types**: 0
- **Public Functions**: 0





### RealHarnessRunner.swift

- **Lines**: 52
- **Public Types**: 0
- **Public Functions**: 0





### RepoIdentityCommand.swift

- **Lines**: 60
- **Public Types**: 0
- **Public Functions**: 0





### ScoutCommands.swift

- **Lines**: 439
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct Scout` (line 12)
- `struct ScoutSwift6` (line 27)



**Public Functions:**
- `run` (line 41)


### SelfHostCommands.swift

- **Lines**: 150
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct SelfHostInit` (line 10)
- `struct SelfHostStatus` (line 60)



**Public Functions:**
- `run` (line 21)
- `run` (line 71)


### StackCommands/StackCommand.swift

- **Lines**: 85
- **Public Types**: 0
- **Public Functions**: 0





### Swift6StepCommands.swift

- **Lines**: 549
- **Public Types**: 6
- **Public Functions**: 4


**Public Types:**
- `struct Swift6Step` (line 11)
- `struct GameStep` (line 25)
- `struct Swift6StepRun` (line 39)
- `struct Swift6StepState` (line 135)
- `struct GameStepRun` (line 279)
- `struct GameStepState` (line 382)



**Public Functions:**
- `run` (line 56)
- `run` (line 149)
- `run` (line 296)
- `run` (line 396)


### TechDebtCommand.swift

- **Lines**: 79
- **Public Types**: 0
- **Public Functions**: 0






Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
