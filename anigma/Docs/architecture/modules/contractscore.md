# ContractsCore

## Overview

ContractsCore is a Swift module in the Anigma ecosystem with **5515 lines of code** across **17 files**.

## Statistics

- **Public Types**: 218
- **Public Functions**: 61  
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

- `AnigmaPrimitives`

## File Structure


### BoundaryTicketService.swift

- **Lines**: 26
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct BoundaryTicketService` (line 8)



**Public Functions:**
- `emitTicket` (line 11)


### Contracts/AttestationArtifacts.swift

- **Lines**: 37
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct HardeningAttestation` (line 4)




### Contracts/ContractRuntimeTypes.swift

- **Lines**: 518
- **Public Types**: 14
- **Public Functions**: 5


**Public Types:**
- `struct ArtifactEnvelope` (line 6)
- `struct AnyArtifactPayload` (line 40)
- `struct AnyArtifactEnvelope` (line 61)
- `enum EvidenceRefKind` (line 143)
- `struct BoundingBoxRef` (line 149)
- `struct ByteRangeRef` (line 164)
- `struct EvidenceRef` (line 175)
- `struct ExecutionMetrics` (line 204)
- `enum ContractStatus` (line 239)
- `struct ContractReceipt` (line 247)
- `struct ContractContext` (line 402)
- `struct ContractBudgets` (line 443)
- `enum ContractValidationError` (line 463)
- `enum ContractExecutionError` (line 490)



**Public Functions:**
- `withReceipt` (line 28)
- `decodePayload` (line 102)
- `withReceipt` (line 111)
- `withComputedProvenanceHash` (line 301)
- `placeholder` (static) (line 373)


### Contracts/ContractSpec.swift

- **Lines**: 189
- **Public Types**: 3
- **Public Functions**: 12


**Public Types:**
- `protocol ContractSpec` (line 4)
- `struct AnyContractSpec` (line 28)
- `struct OutputComponents` (line 167)



**Public Functions:**
- `validate` (static) (line 18)
- `artifactKeyMetadata` (static) (line 22)
- `executeErased` (line 58)
- `validateErased` (line 62)
- `decodeInput` (line 66)
- `encodeOutput` (line 70)
- `decodeOutput` (line 74)
- `extractOutputComponents` (line 78)
- `decodeOutputPayload` (line 82)
- `artifactKeyMetadata` (line 86)
- `register` (line 181)
- `resolve` (line 185)


### Contracts/EmbeddingComputing.swift

- **Lines**: 29
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `protocol EmbeddingComputing` (line 4)
- `struct EmbeddingResult` (line 14)




### Contracts/EvidenceContracts.swift

- **Lines**: 238
- **Public Types**: 9
- **Public Functions**: 0


**Public Types:**
- `enum EvidenceRequirement` (line 13)
- `enum EvidenceStatus` (line 50)
- `enum OperationExecutionStatus` (line 75)
- `enum EvidenceViolationType` (line 100)
- `enum EvidenceViolationSeverity` (line 114)
- `enum EvidenceValidationMode` (line 143)
- `struct EvidenceRequirementContract` (line 163)
- `struct EvidenceValidationResult` (line 187)
- `struct EvidenceViolation` (line 212)




### Contracts/EvidenceSupport.swift

- **Lines**: 98
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `struct ChainViolation` (line 4)
- `struct ChainIntegrityReport` (line 15)
- `struct EvidenceChainValidation` (line 38)
- `struct EvidenceRecord` (line 53)




### Contracts/KeyDerivation.swift

- **Lines**: 78
- **Public Types**: 3
- **Public Functions**: 4


**Public Types:**
- `struct InputKey` (line 5)
- `struct ArtifactKey` (line 11)
- `enum ContractKeyDerivation` (line 17)



**Public Functions:**
- `queueKey` (static) (line 19)
- `inputKey` (static) (line 24)
- `artifactKey` (static) (line 34)
- `sha256Hex` (static) (line 59)


### Contracts/PatchArtifactContracts.swift

- **Lines**: 298
- **Public Types**: 11
- **Public Functions**: 1


**Public Types:**
- `struct PatchArtifact` (line 5)
- `struct PatchMetadata` (line 41)
- `struct PatchReceipt` (line 81)
- `enum PatchStage` (line 113)
- `enum PatchReceiptStatus` (line 125)
- `struct ValidationResults` (line 133)
- `struct ValidationPackResult` (line 149)
- `struct ValidationCheck` (line 177)
- `enum ValidationVerdict` (line 192)
- `struct RollbackInfo` (line 200)
- `struct PatchArtifactContract` (line 226)



**Public Functions:**
- `validateInvariants` (static) (line 240)


### Contracts/TestExecutionPort.swift

- **Lines**: 46
- **Public Types**: 3
- **Public Functions**: 0


**Public Types:**
- `protocol TestCommandRunning` (line 4)
- `struct TestCommandRequest` (line 9)
- `struct TestCommandResult` (line 29)




### ContractsCore.swift

- **Lines**: 191
- **Public Types**: 10
- **Public Functions**: 5


**Public Types:**
- `struct ContractID` (line 5)
- `protocol WorkflowContract` (line 20)
- `struct ContractEnvelope` (line 26)
- `enum SecurityZone` (line 47)
- `enum ValidationError` (line 60)
- `enum AuditEventType` (line 72)
- `protocol AuditLogging` (line 114)
- `struct EvidenceHead` (line 158)
- `protocol EvidenceRecording` (line 173)
- `protocol TraceContentPolicy` (line 187)



**Public Functions:**
- `validateInvariants` (static) (line 38)
- `record` (line 126)
- `getChainHead` (line 144)
- `entryCount` (line 148)
- `verifyChain` (line 152)


### DiaplasionStateContracts.swift

- **Lines**: 1303
- **Public Types**: 56
- **Public Functions**: 1


**Public Types:**
- `struct DiaplasionState` (line 14)
- `struct DocumentEntity` (line 37)
- `struct ProcessingEntity` (line 66)
- `struct ExportEntity` (line 101)
- `enum DocumentType` (line 135)
- `struct DocumentSource` (line 170)
- `enum SourceType` (line 196)
- `struct DocumentContent` (line 215)
- `enum ContentFormat` (line 241)
- `struct ExtractedContent` (line 268)
- `struct ExtractedImage` (line 288)
- `struct ImageSize` (line 314)
- `struct ExtractedTable` (line 327)
- `struct DocumentStructure` (line 350)
- `struct DocumentSection` (line 370)
- `struct ContentPosition` (line 402)
- `struct DocumentHierarchy` (line 425)
- `struct HierarchyNode` (line 438)
- `struct NavigationStructure` (line 461)
- `struct NavigationItem` (line 481)
- `struct NavigationLink` (line 504)
- `enum LinkType` (line 527)
- `struct StructureMetadata` (line 544)
- `enum ProcessingStage` (line 566)
- `struct ProcessingOperation` (line 589)
- `enum OperationType` (line 606)
- `struct OperationRequirements` (line 633)
- `enum ProcessingStatus` (line 656)
- `struct ProcessingProgress` (line 677)
- `struct ProcessingArtifact` (line 700)
- `enum ArtifactType` (line 729)
- `struct ProcessingError` (line 752)
- `enum ErrorSeverity` (line 781)
- `struct ProcessingMetadata` (line 798)
- `enum ExportFormat` (line 823)
- `struct ExportDestination` (line 858)
- `enum DestinationType` (line 878)
- `struct ExportCredentials` (line 897)
- `enum CredentialType` (line 917)
- `struct ExportSettings` (line 934)
- `struct ExportQuality` (line 957)
- `enum QualityLevel` (line 977)
- `struct Resolution` (line 994)
- `struct CompressionSettings` (line 1007)
- `enum CompressionAlgorithm` (line 1024)
- `struct AccessibilitySettings` (line 1041)
- `enum WCAGLevel` (line 1064)
- `struct FormattingSettings` (line 1079)
- `enum ExportStatus` (line 1099)
- `struct ExportResult` (line 1118)
- `struct ExportMetadata` (line 1144)
- `struct AccessibilityInfo` (line 1166)
- `struct DocumentMetadata` (line 1192)
- `struct DiaplasionMetadata` (line 1227)
- `struct DiaplasionConfiguration` (line 1244)
- `struct DiaplasionStateContract` (line 1266)



**Public Functions:**
- `validateInvariants` (static) (line 1275)


### IRContracts.swift

- **Lines**: 594
- **Public Types**: 20
- **Public Functions**: 19


**Public Types:**
- `struct IRNodeId` (line 15)
- `struct IREdgeId` (line 28)
- `struct IRGraphId` (line 41)
- `struct IRNode` (line 56)
- `enum IRNodeKind` (line 73)
- `struct IRAttributes` (line 108)
- `enum IRAttributeValue` (line 138)
- `struct IRMetadata` (line 193)
- `struct IREdge` (line 221)
- `enum IREdgeKind` (line 242)
- `struct IRGraph` (line 287)
- `struct IRVersion` (line 367)
- `struct IRIndexes` (line 386)
- `struct IRQuery` (line 408)
- `struct IRFilter` (line 453)
- `enum IROperator` (line 470)
- `struct IRQueryResult` (line 490)
- `struct IRMatch` (line 503)
- `struct IRGraphContract` (line 520)
- `struct IRQueryContract` (line 563)



**Public Functions:**
- `generate` (static) (line 22)
- `generate` (static) (line 35)
- `generate` (static) (line 48)
- `contains` (line 120)
- `keys` (line 124)
- `values` (line 128)
- `count` (line 132)
- `contains` (line 205)
- `keys` (line 209)
- `count` (line 213)
- `node` (line 315)
- `edge` (line 320)
- `nodes` (line 325)
- `edges` (line 330)
- `outgoingEdges` (line 335)
- `incomingEdges` (line 340)
- `reachable` (line 345)
- `validateInvariants` (static) (line 529)
- `validateInvariants` (static) (line 572)


### MLWorkerContracts.swift

- **Lines**: 270
- **Public Types**: 11
- **Public Functions**: 2


**Public Types:**
- `enum MLWorkerEngine` (line 7)
- `enum MLWorkerTask` (line 15)
- `struct MLArtifactRef` (line 28)
- `struct MLTaskOptions` (line 45)
- `struct MLWorkerMetrics` (line 68)
- `struct MLWorkerEngineMetadata` (line 94)
- `enum MLWorkerStatus` (line 119)
- `struct MLWorkerRequest` (line 128)
- `struct MLWorkerResponse` (line 153)
- `struct EmbeddingHeader` (line 188)
- `struct EngineMetadata` (line 211)



**Public Functions:**
- `validateInvariants` (static) (line 235)
- `validateInvariants` (static) (line 260)


### MakerContracts.swift

- **Lines**: 661
- **Public Types**: 39
- **Public Functions**: 7


**Public Types:**
- `struct StepId` (line 15)
- `enum StepKind` (line 28)
- `struct StepInput` (line 55)
- `struct StepOutput` (line 70)
- `struct StepCandidate` (line 87)
- `struct StepDecision` (line 108)
- `struct CandidateId` (line 129)
- `struct CandidateAction` (line 142)
- `enum ActionType` (line 155)
- `struct StateSlice` (line 176)
- `struct StateDelta` (line 189)
- `struct StateEntity` (line 206)
- `struct StateRelation` (line 219)
- `struct StepContext` (line 236)
- `struct StepConstraint` (line 255)
- `enum ConstraintType` (line 266)
- `struct StepMetrics` (line 276)
- `enum StepStatus` (line 293)
- `struct ImpactEstimate` (line 303)
- `struct ResourceEstimate` (line 318)
- `struct PolicyFlag` (line 333)
- `enum PolicySeverity` (line 346)
- `struct PolicyViolation` (line 354)
- `struct QuarantineAction` (line 371)
- `struct ArtifactRef` (line 384)
- `struct StepTrace` (line 401)
- `enum TraceValueKind` (line 435)
- `struct RedactionPolicy` (line 443)
- `struct TraceEvent` (line 456)
- `struct TraceId` (line 481)
- `struct EventId` (line 494)
- `enum EventType` (line 507)
- `enum EventSeverity` (line 523)
- `struct StepInputContract` (line 534)
- `struct StepOutputContract` (line 557)
- `struct StepTraceContract` (line 584)
- `struct RetryPolicy` (line 618)
- `struct QuarantineRecord` (line 631)
- `struct PolicyEvaluationResult` (line 650)



**Public Functions:**
- `generate` (static) (line 22)
- `generate` (static) (line 136)
- `generate` (static) (line 488)
- `generate` (static) (line 501)
- `validateInvariants` (static) (line 543)
- `validateInvariants` (static) (line 566)
- `validateInvariants` (static) (line 593)


### Models/RollbackComplexity.swift

- **Lines**: 11
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `enum RollbackComplexity` (line 4)




### SecurityContracts.swift

- **Lines**: 928
- **Public Types**: 30
- **Public Functions**: 4


**Public Types:**
- `struct EvidenceHeadInfo` (line 6)
- `struct EvidenceBundle` (line 27)
- `struct RedactionPlan` (line 57)
- `struct RedactionTarget` (line 94)
- `struct ContentRedaction` (line 115)
- `struct RedactionPattern` (line 145)
- `enum VerificationStatus` (line 212)
- `struct RedactedBundleManifest` (line 223)
- `struct PrivilegeLog` (line 270)
- `struct RedactionVerificationResult` (line 301)
- `struct RedactedBundle` (line 325)
- `struct RedactedComponent` (line 357)
- `struct RedactionResult` (line 383)
- `struct AppliedRedaction` (line 415)
- `struct RedactionMetrics` (line 447)
- `struct RedactionAuditTrail` (line 467)
- `struct BundleSignature` (line 502)
- `struct VerificationResult` (line 537)
- `struct SigningKeyStatus` (line 566)
- `enum KeyStatusEnum` (line 583)
- `struct RedactionVerification` (line 589)
- `struct RedactionDiscrepancy` (line 606)
- `struct RedactionTransparencyReport` (line 625)
- `struct RedactionStatistics` (line 656)
- `struct RedactionExample` (line 673)
- `struct PrivilegeClaim` (line 694)
- `struct EmbeddingRecipe` (line 716)
- `struct RetrievalEvidenceRecord` (line 735)
- `struct RetrievalHit` (line 775)
- `struct EvidenceSignature` (line 817)



**Public Functions:**
- `validateInvariants` (static) (line 803)
- `validateInvariants` (static) (line 868)
- `validateInvariants` (static) (line 892)
- `validateInvariants` (static) (line 913)


