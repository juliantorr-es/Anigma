# OutlineumModule

## Overview

OutlineumModule is a Swift module in the Anigma ecosystem with **1672 lines of code** across **11 files**.

## Statistics

- **Public Types**: 22
- **Public Functions**: 13  
- **Components**: 8
- **Systems**: 8
- **Services**: 0

## Architecture

### Components
- `ImageComponent`
- `OutlineComponent`
- `OutlineQAComponent`
- `ZineComponent`
- `ZineStatus`
- `ZinePageComponent`
- `PageLayoutType`
- `ZineRecipeComponent`

### Systems
- `IngestSystem`
- `OutlineQASystem`
- `Thresholds`
- `OutlineConfig`
- `OutlineSystem`
- `ZineLayoutConfig`
- `ZineLayoutSystem`
- `ZineExportSystem`

### Services
No services found

## Dependencies

- `AnigmaCore`

## File Structure


### Components/ImageComponent.swift

- **Lines**: 59
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct ImageComponent` (line 19)




### Components/OutlineComponent.swift

- **Lines**: 83
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct OutlineComponent` (line 22)




### Components/OutlineQAComponent.swift

- **Lines**: 87
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct OutlineQAComponent` (line 17)




### Components/ZineComponent.swift

- **Lines**: 152
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `struct ZineComponent` (line 19)
- `enum ZineStatus` (line 91)
- `struct ZinePageComponent` (line 109)
- `enum PageLayoutType` (line 136)




### Components/ZineRecipeComponent.swift

- **Lines**: 38
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct ZineRecipeComponent` (line 11)




### OutlineumModule.swift

- **Lines**: 112
- **Public Types**: 2
- **Public Functions**: 4


**Public Types:**
- `enum OutlineumModuleVersion` (line 24)
- `enum OutlineumModule` (line 41)



**Public Functions:**
- `register` (static) (line 43)
- `createOutlineJob` (static) (line 68)
- `defaultWorkDirectory` (static) (line 87)
- `runOutlinePipeline` (line 97)


### Pipelines/OutlineWorkflows.swift

- **Lines**: 128
- **Public Types**: 4
- **Public Functions**: 4


**Public Types:**
- `struct OutlineJobType` (line 15)
- `struct ZineJobType` (line 21)
- `struct OutlineWorkflow` (line 31)
- `struct ZineWorkflow` (line 80)



**Public Functions:**
- `prepare` (line 38)
- `finalize` (line 57)
- `prepare` (line 87)
- `finalize` (line 110)


### Systems/IngestSystem.swift

- **Lines**: 111
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct IngestSystem` (line 33)



**Public Functions:**
- `update` (line 44)


### Systems/OutlineQASystem.swift

- **Lines**: 198
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct OutlineQASystem` (line 32)
- `struct Thresholds` (line 36)



**Public Functions:**
- `update` (line 53)


### Systems/OutlineSystem.swift

- **Lines**: 315
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct OutlineConfig` (line 28)
- `struct OutlineSystem` (line 53)



**Public Functions:**
- `update` (line 71)


### Systems/ZineSystems.swift

- **Lines**: 389
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct ZineLayoutConfig` (line 23)
- `struct ZineLayoutSystem` (line 54)
- `struct ZineExportSystem` (line 130)



**Public Functions:**
- `update` (line 63)
- `update` (line 148)


