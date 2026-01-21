# DiaplasionModule

## Overview

DiaplasionModule is a Swift module in the Anigma ecosystem with **3696 lines of code** across **5 files**.

## Statistics

- **Public Types**: 46
- **Public Functions**: 12  
- **Components**: 24
- **Systems**: 13
- **Services**: 0

## Architecture

### Components
- `DocumentSourceComponent`
- `DocumentFormat`
- `IngestedDocumentComponent`
- `DocumentAssetComponent`
- `DocumentAsset`
- `DocumentAssetType`
- `DocumentAssetRole`
- `TransformRequestComponent`
- `OutputFormat`
- `TransformStatus`
- `OCRResultComponent`
- `PageOCRResult`
- `TextBoundingBox`
- `ChunkedTextComponent`
- `TextChunk`
- `ChunkType`
- `ChunkingStrategy`
- `AccessibleOutputComponent`
- `OutputReference`
- `QAStatus`
- `ValidationResult`
- `DiaplasionProcessingStage`
- `DiaplasionProcessingError`
- `DiaplasionProcessingErrorComponent`

### Systems
- `DiaplasionError`
- `DocumentIngestSystem`
- `OCRExtractionSystem`
- `RecognitionLevel`
- `TextChunkingSystem`
- `EPUBExportSystem`
- `BrailleExportSystem`
- `BrailleGrade`
- `BrailleOutputFormat`
- `Configuration`
- `AudioPrepSystem`
- `Configuration`
- `DiaplasionQASystem`

### Services
No services found

## Dependencies

- `AnigmaCore`

## File Structure


### Components/DiaplasionComponents.swift

- **Lines**: 544
- **Public Types**: 24
- **Public Functions**: 0


**Public Types:**
- `struct DocumentSourceComponent` (line 18)
- `enum DocumentFormat` (line 50)
- `struct IngestedDocumentComponent` (line 91)
- `struct DocumentAssetComponent` (line 126)
- `struct DocumentAsset` (line 136)
- `enum DocumentAssetType` (line 178)
- `enum DocumentAssetRole` (line 185)
- `struct TransformRequestComponent` (line 194)
- `enum OutputFormat` (line 239)
- `enum TransformStatus` (line 251)
- `struct OCRResultComponent` (line 265)
- `struct PageOCRResult` (line 302)
- `struct TextBoundingBox` (line 322)
- `struct ChunkedTextComponent` (line 344)
- `struct TextChunk` (line 366)
- `enum ChunkType` (line 389)
- `enum ChunkingStrategy` (line 402)
- `struct AccessibleOutputComponent` (line 413)
- `struct OutputReference` (line 435)
- `enum QAStatus` (line 462)
- `struct ValidationResult` (line 470)
- `enum DiaplasionProcessingStage` (line 485)
- `struct DiaplasionProcessingError` (line 496)
- `struct DiaplasionProcessingErrorComponent` (line 536)




### DiaplasionModule.swift

- **Lines**: 133
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `enum DiaplasionModuleVersion` (line 46)
- `enum DiaplasionModule` (line 56)
- `enum DiaplasionJobType` (line 125)



**Public Functions:**
- `register` (static) (line 66)
- `createOCRPipeline` (static) (line 109)


### Pipelines/DiaplasionWorkflows.swift

- **Lines**: 140
- **Public Types**: 5
- **Public Functions**: 1


**Public Types:**
- `struct DocumentToEPUBWorkflow` (line 15)
- `struct DocumentToBrailleWorkflow` (line 36)
- `struct DocumentToAudioWorkflow` (line 57)
- `struct OCROnlyWorkflow` (line 78)
- `struct MultiFormatWorkflow` (line 96)



**Public Functions:**
- `shouldRunSystem` (line 115)


### Resources/DiaplasionFixtures.swift

- **Lines**: 31
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `enum DiaplasionModuleResources` (line 3)



**Public Functions:**
- `urlForHappyPathSpec` (static) (line 4)
- `baseURLForHappyPathFixtures` (static) (line 8)


### Systems/DiaplasionSystems.swift

- **Lines**: 2848
- **Public Types**: 13
- **Public Functions**: 7


**Public Types:**
- `enum DiaplasionError` (line 39)
- `struct DocumentIngestSystem` (line 131)
- `struct OCRExtractionSystem` (line 733)
- `enum RecognitionLevel` (line 748)
- `struct TextChunkingSystem` (line 1068)
- `struct EPUBExportSystem` (line 1348)
- `struct BrailleExportSystem` (line 1740)
- `enum BrailleGrade` (line 1744)
- `enum BrailleOutputFormat` (line 1750)
- `struct Configuration` (line 1756)
- `struct AudioPrepSystem` (line 2210)
- `struct Configuration` (line 2214)
- `struct DiaplasionQASystem` (line 2682)



**Public Functions:**
- `update` (line 146)
- `update` (line 765)
- `update` (line 1095)
- `update` (line 1369)
- `update` (line 1786)
- `update` (line 2253)
- `update` (line 2699)


