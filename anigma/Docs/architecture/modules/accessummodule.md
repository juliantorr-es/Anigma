> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# AccessumModule

## Overview

AccessumModule is a Swift module in the Anigma ecosystem with **1480 lines of code** across **5 files**.

## Statistics

- **Public Types**: 43
- **Public Functions**: 14  
- **Components**: 23
- **Systems**: 5
- **Services**: 8

## Architecture

### Components
- `DocumentSource`
- `DocumentStatus`
- `OCRStatus`
- `OCREngine`
- `OCRPriority`
- `ReadingMode`
- `SyncState`
- `FulfillmentStatus`
- `DocumentComponent`
- `OCRStateComponent`
- `ReadingStateComponent`
- `OCREngineComponent`
- `AudioStatus`
- `AudioStateComponent`
- `VoicePreferencesComponent`
- `AccessumRole`
- `UserComponent`
- `AccessibilityPrefsComponent`
- `EyzoStateComponent`
- `CloudSyncComponent`
- `ComplianceLogComponent`
- `AuditComponent`
- `FulfillmentComponent`

### Systems
- `DocumentImportSystem`
- `StubOCRSystem`
- `OCRSystemError`
- `TTSSystem`
- `CloudSyncSystem`

### Services
- `EngineAvailability`
- `OCRProcessingOptions`
- `RecognitionLevel`
- `OCREngineAttempt`
- `OCREngineResult`
- `OCRCoordinatorResult`
- `OCREngineProtocol`
- `OCREngineError`

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### AccessumModule.swift

- **Lines**: 96
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `enum AccessumModuleVersion` (line 51)
- `enum AccessumModule` (line 61)
- `protocol ComponentStore` (line 89)



**Public Functions:**
- `register` (static) (line 62)


### Components/PlaceholderComponents.swift

- **Lines**: 464
- **Public Types**: 23
- **Public Functions**: 0


**Public Types:**
- `enum DocumentSource` (line 14)
- `enum DocumentStatus` (line 18)
- `enum OCRStatus` (line 26)
- `enum OCREngine` (line 48)
- `enum OCRPriority` (line 54)
- `enum ReadingMode` (line 76)
- `enum SyncState` (line 82)
- `enum FulfillmentStatus` (line 86)
- `struct DocumentComponent` (line 93)
- `struct OCRStateComponent` (line 174)
- `struct ReadingStateComponent` (line 260)
- `struct OCREngineComponent` (line 283)
- `enum AudioStatus` (line 297)
- `struct AudioStateComponent` (line 301)
- `struct VoicePreferencesComponent` (line 326)
- `enum AccessumRole` (line 342)
- `struct UserComponent` (line 346)
- `struct AccessibilityPrefsComponent` (line 360)
- `struct EyzoStateComponent` (line 392)
- `struct CloudSyncComponent` (line 406)
- `struct ComplianceLogComponent` (line 420)
- `struct AuditComponent` (line 432)
- `struct FulfillmentComponent` (line 446)




### Pipelines/PlaceholderPipelines.swift

- **Lines**: 44
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `struct DocumentImportJobType` (line 16)
- `struct DocumentImportWorkflow` (line 22)
- `struct OcrProcessingJobType` (line 31)
- `struct OcrProcessingWorkflow` (line 37)




### Services/OCREngineCoordinator.swift

- **Lines**: 409
- **Public Types**: 8
- **Public Functions**: 6


**Public Types:**
- `struct EngineAvailability` (line 25)
- `struct OCRProcessingOptions` (line 67)
- `enum RecognitionLevel` (line 73)
- `struct OCREngineAttempt` (line 94)
- `struct OCREngineResult` (line 109)
- `struct OCRCoordinatorResult` (line 124)
- `protocol OCREngineProtocol` (line 288)
- `enum OCREngineError` (line 385)



**Public Functions:**
- `isAvailable` (line 146)
- `getVersion` (line 154)
- `process` (line 158)
- `checkEngineAvailability` (line 309)
- `process` (line 335)
- `invalidateCache` (line 377)


### Systems/AccessumSystems.swift

- **Lines**: 467
- **Public Types**: 5
- **Public Functions**: 7


**Public Types:**
- `struct DocumentImportSystem` (line 45)
- `struct StubOCRSystem` (line 98)
- `enum OCRSystemError` (line 365)
- `struct TTSSystem` (line 394)
- `struct CloudSyncSystem` (line 430)



**Public Functions:**
- `update` (line 58)
- `update` (line 111)
- `setup` (line 181)
- `update` (line 195)
- `teardown` (line 255)
- `update` (line 407)
- `update` (line 443)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
