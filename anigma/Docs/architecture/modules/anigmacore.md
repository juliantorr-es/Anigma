> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# AnigmaCore

## Overview

AnigmaCore is a Swift module in the Anigma ecosystem with **51043 lines of code** across **103 files**.

## Statistics

- **Public Types**: 818
- **Public Functions**: 958  
- **Components**: 9
- **Systems**: 0
- **Services**: 0

## Architecture

### Components
- `FileComponent`
- `QAComponent`
- `MetadataComponent`
- `JobComponent`
- `JobRole`
- `NameComponent`
- `TimestampComponent`
- `TagComponent`
- `StatusComponent`

### Systems
No systems found

### Services
No services found

## Dependencies

- `ContractsCore`
- `AnigmaPrimitives`
- `AnigmaCore``
- `DatabaseCore`

## File Structure


### Adapters/AnigmaCoreAdapters.swift

- **Lines**: 128
- **Public Types**: 3
- **Public Functions**: 6


**Public Types:**
- `protocol EvidenceRecorder` (line 7)
- `struct AnigmaAuditLogger` (line 30)
- `struct AnigmaEvidenceRecorder` (line 57)



**Public Functions:**
- `recordEvent` (line 37)
- `recordEvidence` (line 64)
- `recordStateDelta` (line 79)
- `recordEvidence` (line 100)
- `recordIRGraph` (line 110)
- `recordStateDelta` (line 120)


### Analytics/CampaignPlanners.swift

- **Lines**: 784
- **Public Types**: 4
- **Public Functions**: 4


**Public Types:**
- `struct FailureAnalysisPlanner` (line 13)
- `struct PolicyImprovementPlanner` (line 191)
- `struct PerformanceOptimizationPlanner` (line 381)
- `struct ResourceScalingPlanner` (line 574)



**Public Functions:**
- `plan` (line 14)
- `plan` (line 192)
- `plan` (line 382)
- `plan` (line 575)


### Analytics/PatternDetectors.swift

- **Lines**: 543
- **Public Types**: 5
- **Public Functions**: 5


**Public Types:**
- `struct RepeatedFailureDetector` (line 12)
- `struct PolicyViolationDetector` (line 100)
- `struct PerformanceDegradationDetector` (line 220)
- `struct ResourceExhaustionDetector` (line 331)
- `struct QuarantinePatternDetector` (line 429)



**Public Functions:**
- `detect` (line 15)
- `detect` (line 103)
- `detect` (line 223)
- `detect` (line 334)
- `detect` (line 432)


### Analytics/ReflexiveAnalytics.swift

- **Lines**: 936
- **Public Types**: 22
- **Public Functions**: 10


**Public Types:**
- `struct ReflexiveAnalyticsConfig` (line 465)
- `struct NormalizedTrace` (line 490)
- `struct TraceMetrics` (line 519)
- `struct NormalizedEvent` (line 548)
- `struct NormalizationMetadata` (line 583)
- `enum EventCategory` (line 596)
- `enum NormalizedSeverity` (line 617)
- `protocol PatternDetector` (line 634)
- `enum PatternType` (line 640)
- `struct DetectedPattern` (line 659)
- `struct PatternId` (line 688)
- `struct PatternMetadata` (line 701)
- `protocol CampaignPlanner` (line 726)
- `struct CampaignRecommendation` (line 731)
- `struct CampaignId` (line 772)
- `enum CampaignType` (line 785)
- `enum CampaignPriority` (line 804)
- `struct SuggestedAction` (line 821)
- `struct EffortEstimate` (line 847)
- `enum ComplexityLevel` (line 867)
- `struct CampaignImpact` (line 886)
- `struct CampaignMetadata` (line 909)



**Public Functions:**
- `normalizeTrace` (line 44)
- `detectPatterns` (line 109)
- `generateCampaigns` (line 164)
- `getNormalizedTrace` (line 224)
- `getDetectedPattern` (line 229)
- `getCampaignRecommendation` (line 234)
- `getAllDetectedPatterns` (line 239)
- `getAllCampaignRecommendations` (line 244)
- `generate` (static) (line 695)
- `generate` (static) (line 779)


### AnigmaCore.swift

- **Lines**: 1254
- **Public Types**: 17
- **Public Functions**: 11


**Public Types:**
- `enum AnigmaCoreVersion` (line 142)
- `enum TrustSubjectKind` (line 152)
- `struct TrustStateRecord` (line 206)
- `struct TrustStats` (line 235)
- `enum SecurityEventType` (line 290)
- `enum SecurityEventSeverity` (line 307)
- `struct SecurityEventDetails` (line 315)
- `struct SecurityEvent` (line 356)
- `struct SecurityEventStats` (line 385)
- `struct SandboxConfig` (line 415)
- `struct ProcessResult` (line 535)
- `enum GranularCapability` (line 702)
- `enum CapabilityCategory` (line 890)
- `enum EngineType` (line 907)
- `struct CapabilityPolicy` (line 949)
- `struct CapabilityGrant` (line 1176)
- `struct AuditEntry` (line 1225)



**Public Functions:**
- `mutationEngineSandbox` (static) (line 466)
- `networkEngineSandbox` (static) (line 495)
- `readOnlySandbox` (static) (line 516)
- `logOperation` (line 585)
- `logResult` (line 614)
- `logError` (line 640)
- `getAuditTrail` (line 658)
- `getAllEntries` (line 670)
- `implies` (line 1125)
- `includes` (line 1212)
- `includesAll` (line 1217)


### Automation/Automation.swift

- **Lines**: 747
- **Public Types**: 20
- **Public Functions**: 5


**Public Types:**
- `struct AutomationRuleComponent` (line 23)
- `struct AutomationTrigger` (line 114)
- `enum TriggerType` (line 171)
- `struct AutomationCondition` (line 192)
- `enum ConditionOperator` (line 210)
- `struct AutomationAction` (line 225)
- `struct AgentDefinitionComponent` (line 251)
- `enum OperatingModeRaw` (line 316)
- `enum AgentType` (line 331)
- `struct AgentCapability` (line 352)
- `struct CapabilityField` (line 394)
- `struct AutomationExecutionComponent` (line 413)
- `enum ExecutionStatus` (line 476)
- `struct TriggerContext` (line 488)
- `struct ConditionResult` (line 514)
- `struct ActionResult` (line 531)
- `struct AgentInvocationComponent` (line 559)
- `enum InvocationStatus` (line 632)
- `struct ResourceUsage` (line 643)
- `enum StandardAgents` (line 658)



**Public Functions:**
- `onEntityCreated` (static) (line 145)
- `onEntityUpdated` (static) (line 150)
- `onStateChange` (static) (line 155)
- `scheduled` (static) (line 160)
- `onEvent` (static) (line 165)


### Compliance/Compliance.swift

- **Lines**: 387
- **Public Types**: 8
- **Public Functions**: 8


**Public Types:**
- `enum ComplianceModule` (line 97)
- `struct ComplianceInfrastructure` (line 146)
- `struct FrameworkSummary` (line 158)
- `struct ComplianceAssessment` (line 279)
- `struct ComplianceReportPackage` (line 302)
- `struct ComplianceDashboardData` (line 314)
- `struct ControlFamilyStatus` (line 348)
- `enum ComplianceError` (line 362)



**Public Functions:**
- `initialize` (static) (line 105)
- `getNIST80053Summary` (static) (line 125)
- `getWCAG21Summary` (static) (line 135)
- `setAuditLog` (line 181)
- `runAssessment` (line 186)
- `getQuickStatus` (line 232)
- `generateReportPackage` (line 237)
- `generateAccessibilityReport` (line 266)


### Compliance/ContinuousMonitoring.swift

- **Lines**: 912
- **Public Types**: 11
- **Public Functions**: 22


**Public Types:**
- `struct ControlProbe` (line 17)
- `enum ProbeFrequency` (line 71)
- `struct ProbeThresholds` (line 112)
- `struct ProbeResult` (line 144)
- `enum ProbeStatus` (line 247)
- `struct ProbeMetric` (line 265)
- `struct ProbeIssue` (line 297)
- `struct ComplianceStatus` (line 543)
- `struct ControlComplianceStatus` (line 555)
- `enum StandardProbes` (line 566)
- `enum AccessibilityProbes` (line 814)



**Public Functions:**
- `healthy` (static) (line 189)
- `degraded` (static) (line 206)
- `failing` (static) (line 226)
- `setAuditLog` (line 348)
- `registerProbe` (line 353)
- `unregisterProbe` (line 358)
- `getProbes` (line 363)
- `getProbesForControl` (line 368)
- `runProbe` (line 373)
- `runAllProbes` (line 410)
- `getLatestResult` (line 423)
- `getAllLatestResults` (line 428)
- `getResultHistory` (line 433)
- `getOverallStatus` (line 438)
- `getControlStatus` (line 483)
- `accountManagementProbe` (static) (line 569)
- `auditIntegrityProbe` (static) (line 612)
- `backupComplianceProbe` (static) (line 652)
- `keyManagementProbe` (static) (line 702)
- `systemMonitoringProbe` (static) (line 760)
- `colorContrastProbe` (static) (line 817)
- `keyboardAccessibilityProbe` (static) (line 861)


### Compliance/ControlCatalog.swift

- **Lines**: 1161
- **Public Types**: 13
- **Public Functions**: 4


**Public Types:**
- `struct ComplianceFramework` (line 20)
- `enum StandardFrameworks` (line 57)
- `struct ControlFamily` (line 115)
- `enum NIST80053Families` (line 147)
- `struct ControlDefinition` (line 297)
- `enum ControlBaseline` (line 375)
- `enum ControlPriority` (line 382)
- `struct ControlParameter` (line 389)
- `enum NIST80053Controls` (line 419)
- `enum WCAGLevel` (line 891)
- `enum WCAGPrinciple` (line 898)
- `struct AccessibilityControlDefinition` (line 906)
- `enum WCAGControls` (line 950)



**Public Functions:**
- `hash` (line 140)
- `hash` (line 359)
- `controlsForBaseline` (static) (line 883)
- `controlsForLevel` (static) (line 1150)


### Compliance/ControlImplementation.swift

- **Lines**: 773
- **Public Types**: 12
- **Public Functions**: 1


**Public Types:**
- `struct ControlImplementation` (line 20)
- `enum ImplementationType` (line 110)
- `enum ImplementationStatus` (line 128)
- `struct EvidenceSource` (line 164)
- `enum EvidenceType` (line 196)
- `enum EvidenceCollectionMethod` (line 229)
- `enum EvidenceFrequency` (line 241)
- `struct EvidenceArtifact` (line 267)
- `struct EvidenceFinding` (line 340)
- `enum FindingSeverity` (line 367)
- `enum ComplianceValue` (line 376)
- `enum AnigmaControlImplementations` (line 426)



**Public Functions:**
- `encode` (line 409)


### Compliance/DocumentGeneration.swift

- **Lines**: 1187
- **Public Types**: 11
- **Public Functions**: 13


**Public Types:**
- `enum ComplianceDocumentType` (line 18)
- `enum DocumentFormat` (line 42)
- `struct DocumentGenerationContext` (line 59)
- `struct OrganizationInfo` (line 109)
- `struct SystemInfo` (line 135)
- `struct GeneratedDocument` (line 169)
- `struct DocumentSection` (line 233)
- `struct POAMItem` (line 1019)
- `enum POAMRisk` (line 1032)
- `enum POAMStatus` (line 1039)
- `struct ControlCoverageStats` (line 1167)



**Public Functions:**
- `setAuditLog` (line 274)
- `generateSSP` (line 281)
- `generatePOAM` (line 353)
- `generateVPAT` (line 457)
- `generateConMonReport` (line 560)
- `getControl` (line 1080)
- `getControlsForFramework` (line 1085)
- `getControlsForBaseline` (line 1090)
- `registerImplementation` (line 1095)
- `getImplementation` (line 1101)
- `getImplementationsForFramework` (line 1107)
- `updateImplementationStatus` (line 1112)
- `getCoverageStatistics` (line 1127)


### Components/SharedComponents.swift

- **Lines**: 407
- **Public Types**: 9
- **Public Functions**: 10


**Public Types:**
- `struct FileComponent` (line 24)
- `struct QAComponent` (line 108)
- `struct MetadataComponent` (line 167)
- `struct JobComponent` (line 238)
- `enum JobRole` (line 270)
- `struct NameComponent` (line 288)
- `struct TimestampComponent` (line 309)
- `struct TagComponent` (line 341)
- `struct StatusComponent` (line 374)



**Public Functions:**
- `passes` (line 144)
- `get` (line 198)
- `getInt` (line 203)
- `getDouble` (line 208)
- `getBool` (line 213)
- `hasTag` (line 223)
- `touch` (line 332)
- `hasTag` (line 357)
- `hasAnyTag` (line 361)
- `hasAllTags` (line 365)


### ECS/Component.swift

- **Lines**: 124
- **Public Types**: 7
- **Public Functions**: 1


**Public Types:**
- `protocol Component` (line 45)
- `protocol TypedComponent` (line 51)
- `protocol VersionedComponent` (line 69)
- `protocol CodableComponent` (line 79)
- `protocol PersistableComponent` (line 83)
- `struct AnyComponent` (line 92)
- `enum ComponentTypeNaming` (line 114)



**Public Functions:**
- `typeName` (static) (line 118)


### ECS/EntityId.swift

- **Lines**: 107
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct EntityId` (line 31)




### ECS/System.swift

- **Lines**: 194
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `protocol System` (line 44)
- `protocol AsyncSystem` (line 76)
- `enum SystemPhase` (line 115)
- `struct SystemContext` (line 130)




### ECS/World.swift

- **Lines**: 644
- **Public Types**: 4
- **Public Functions**: 30


**Public Types:**
- `protocol WorldObserver` (line 74)
- `enum WorldEvent` (line 99)
- `struct WorldSnapshot` (line 550)
- `enum ECSError` (line 596)



**Public Functions:**
- `createEntity` (line 168)
- `createEntity` (line 181)
- `destroyEntity` (line 192)
- `entityExists` (line 206)
- `allEntities` (line 211)
- `entityCount` (line 216)
- `addComponent` (line 223)
- `removeComponent` (line 243)
- `getComponent` (line 258)
- `hasComponent` (line 265)
- `entitiesWith` (line 272)
- `query` (line 281)
- `query` (line 288)
- `query` (line 310)
- `query` (line 337)
- `registerSystem` (line 370)
- `registerSystem` (line 379)
- `removeSystem` (line 390)
- `update` (line 401)
- `runSystem` (line 423)
- `registeredSystemNames` (line 428)
- `context` (line 433)
- `addObserver` (line 445)
- `removeObserver` (line 451)
- `snapshot` (line 528)
- `spawn` (line 576)
- `query` (line 621)
- `query` (line 625)
- `query` (line 633)
- `addComponent` (line 640)


### Governance/Governance.swift

- **Lines**: 561
- **Public Types**: 11
- **Public Functions**: 24


**Public Types:**
- `struct NoOpAuditLogger` (line 19)
- `enum OperatingMode` (line 37)
- `struct KillSwitchStatus` (line 193)
- `struct WriteProposal` (line 278)
- `protocol WriteCheck` (line 315)
- `struct WriteCheckResult` (line 333)
- `struct WriteGateDecision` (line 361)
- `struct OperatingModeCheck` (line 374)
- `struct KillSwitchCheck` (line 401)
- `struct GovernanceStatus` (line 532)
- `enum GovernanceError` (line 542)



**Public Functions:**
- `recordEvent` (line 22)
- `setAuditLog` (line 90)
- `activate` (line 95)
- `deactivate` (line 114)
- `activateForProject` (line 134)
- `deactivateForProject` (line 150)
- `isWriteAllowed` (line 166)
- `status` (line 181)
- `setAuditLog` (line 218)
- `registerCheck` (line 223)
- `removeCheck` (line 228)
- `evaluate` (line 233)
- `pass` (static) (line 351)
- `fail` (static) (line 355)
- `appliesTo` (line 385)
- `evaluate` (line 389)
- `appliesTo` (line 412)
- `evaluate` (line 416)
- `initialize` (line 457)
- `getMode` (line 472)
- `setMode` (line 477)
- `canWrite` (line 492)
- `recordHumanOverride` (line 497)
- `status` (line 516)


### Governance/StateAccess.swift

- **Lines**: 678
- **Public Types**: 6
- **Public Functions**: 9


**Public Types:**
- `struct StateAccessConfig` (line 542)
- `struct StateAccessRequest` (line 564)
- `enum StateAccessOperation` (line 590)
- `struct StateAccessDecision` (line 611)
- `struct StateAccessRecord` (line 622)
- `enum StateAccessError` (line 657)



**Public Functions:**
- `readState` (line 46)
- `writeState` (line 120)
- `createSession` (line 232)
- `deleteSession` (line 288)
- `quarantineEntities` (line 335)
- `liftQuarantine` (line 396)
- `getAccessHistory` (line 430)
- `getCurrentState` (line 448)
- `getQuarantinedEntities` (line 453)


### Identity/Identity.swift

- **Lines**: 903
- **Public Types**: 22
- **Public Functions**: 6


**Public Types:**
- `struct PrincipalIdentity` (line 23)
- `enum PrincipalType` (line 83)
- `enum PrincipalStatus` (line 98)
- `struct ExternalIdentifierComponent` (line 118)
- `struct RoleDefinition` (line 166)
- `struct RoleAssignmentComponent` (line 228)
- `enum RoleAssignmentStatus` (line 297)
- `struct GroupComponent` (line 317)
- `enum GroupType` (line 372)
- `struct GroupMembershipComponent` (line 393)
- `struct DerivedCapabilities` (line 453)
- `struct CapabilitySource` (line 509)
- `enum CapabilitySourceType` (line 524)
- `struct SessionComponent` (line 534)
- `struct SessionClientInfo` (line 592)
- `enum AuthenticationMethod` (line 615)
- `struct DeprovisioningRecord` (line 626)
- `enum DeprovisionType` (line 678)
- `enum DeprovisionStatus` (line 696)
- `struct DeprovisionAction` (line 705)
- `enum StandardRoles` (line 724)
- `enum StandardCapabilities` (line 868)



**Public Functions:**
- `hash` (line 216)
- `isEffective` (line 288)
- `isEffective` (line 442)
- `hasCapability` (line 498)
- `canAccessSensitivity` (line 503)
- `isActive` (line 586)


### Integration/AnigmaPlatform.swift

- **Lines**: 511
- **Public Types**: 6
- **Public Functions**: 7


**Public Types:**
- `struct AuditIntegrityReport` (line 25)
- `struct ComplianceReport` (line 37)
- `struct PlatformConfiguration` (line 52)
- `struct ModuleConfiguration` (line 120)
- `struct PlatformHealth` (line 142)
- `struct SecurityHealthStatus` (line 165)



**Public Functions:**
- `bootstrap` (static) (line 230)
- `healthCheck` (line 282)
- `createSystemPrincipal` (line 324)
- `registerSystem` (line 333)
- `uptime` (line 344)
- `generateComplianceReport` (line 349)
- `shutdown` (line 360)


### Integration/SecuredWorld.swift

- **Lines**: 613
- **Public Types**: 1
- **Public Functions**: 24


**Public Types:**
- `enum SecuredWorldError` (line 531)



**Public Functions:**
- `create` (static) (line 69)
- `registerSystemPrincipal` (line 105)
- `registerComponentSensitivity` (line 110)
- `registerSensitiveComponent` (line 120)
- `createEntity` (line 128)
- `destroyEntity` (line 149)
- `getComponent` (line 168)
- `addComponent` (line 193)
- `removeComponent` (line 247)
- `query` (line 296)
- `recordAIDecision` (line 321)
- `handleThreat` (line 370)
- `runSystem` (line 405)
- `entityExists` (line 436)
- `allEntities` (line 441)
- `entityCount` (line 446)
- `getMode` (line 453)
- `setMode` (line 458)
- `activateKillSwitch` (line 470)
- `deactivateKillSwitch` (line 482)
- `entityCreated` (line 560)
- `entityDestroyed` (line 571)
- `componentAdded` (line 582)
- `componentRemoved` (line 597)


### Jobs/Job.swift

- **Lines**: 403
- **Public Types**: 11
- **Public Functions**: 1


**Public Types:**
- `struct JobId` (line 26)
- `enum JobStatus` (line 51)
- `enum JobPriority` (line 95)
- `protocol JobType` (line 118)
- `struct GenericJobType` (line 129)
- `struct RetryPolicy` (line 137)
- `struct Job` (line 185)
- `struct JobRecord` (line 267)
- `struct JobResult` (line 341)
- `enum JobOutcome` (line 373)
- `enum JobError` (line 384)



**Public Functions:**
- `backoff` (line 167)


### Jobs/Scheduler.swift

- **Lines**: 409
- **Public Types**: 2
- **Public Functions**: 15


**Public Types:**
- `struct SchedulerSnapshot` (line 382)
- `struct SchedulerStats` (line 399)



**Public Functions:**
- `enqueue` (line 45)
- `enqueueBatch` (line 68)
- `dequeue` (line 81)
- `peek` (line 115)
- `complete` (line 127)
- `fail` (line 137)
- `cancel` (line 156)
- `get` (line 183)
- `list` (line 188)
- `stats` (line 209)
- `cleanup` (line 246)
- `save` (line 302)
- `load` (line 328)
- `allRecords` (line 363)
- `importRecords` (line 369)


### Jobs/Workflow.swift

- **Lines**: 217
- **Public Types**: 3
- **Public Functions**: 7


**Public Types:**
- `protocol Workflow` (line 33)
- `enum WorkflowError` (line 186)
- `struct SimpleWorkflow` (line 206)



**Public Functions:**
- `register` (line 77)
- `unregister` (line 82)
- `workflow` (line 87)
- `allWorkflowNames` (line 92)
- `allJobTypeIds` (line 97)
- `registerSystem` (line 115)
- `execute` (line 121)


### MigrationTypes.swift

- **Lines**: 5
- **Public Types**: 0
- **Public Functions**: 0





### Pipeline/AINodes.swift

- **Lines**: 622
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct AINodeRegistrar` (line 24)



**Public Functions:**
- `registerAll` (static) (line 26)


### Pipeline/ArtifactStore.swift

- **Lines**: 243
- **Public Types**: 1
- **Public Functions**: 16


**Public Types:**
- `protocol PipelineArtifactStore` (line 6)



**Public Functions:**
- `store` (line 55)
- `store` (line 62)
- `storeRaw` (line 67)
- `load` (line 73)
- `contains` (line 89)
- `loadRaw` (line 93)
- `loadEnvelopeData` (line 103)
- `storeEnvelopeData` (line 113)
- `store` (line 146)
- `store` (line 152)
- `storeRaw` (line 170)
- `load` (line 190)
- `contains` (line 197)
- `loadRaw` (line 201)
- `loadEnvelopeData` (line 208)
- `storeEnvelopeData` (line 215)


### Pipeline/Contracts/EmbedTextContract.swift

- **Lines**: 122
- **Public Types**: 4
- **Public Functions**: 3


**Public Types:**
- `struct EmbedTextInput` (line 4)
- `struct EmbeddingVector` (line 16)
- `struct EmbedTextOutput` (line 26)
- `enum EmbedTextContract` (line 40)



**Public Functions:**
- `validate` (static) (line 45)
- `artifactKeyMetadata` (static) (line 62)
- `execute` (static) (line 66)


### Pipeline/Contracts/HardeningAttestationContract.swift

- **Lines**: 109
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct HardeningAttestationInput` (line 5)
- `enum HardeningAttestationContract` (line 37)



**Public Functions:**
- `validate` (static) (line 42)
- `execute` (static) (line 69)


### Pipeline/Contracts/HybridSearchContract.swift

- **Lines**: 195
- **Public Types**: 6
- **Public Functions**: 2


**Public Types:**
- `struct EmbeddingSearchResult` (line 5)
- `struct LexicalSearchResult` (line 19)
- `struct HybridSearchInput` (line 32)
- `struct HybridSearchHit` (line 40)
- `struct HybridSearchResult` (line 51)
- `enum HybridSearchContract` (line 57)



**Public Functions:**
- `validate` (static) (line 64)
- `execute` (static) (line 68)


### Pipeline/Contracts/IndexEmbeddingsContract.swift

- **Lines**: 119
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct IndexEmbeddingsInput` (line 6)
- `struct IndexEmbeddingsOutput` (line 14)
- `enum IndexEmbeddingsContract` (line 25)



**Public Functions:**
- `validate` (static) (line 32)
- `execute` (static) (line 38)


### Pipeline/Contracts/PDFExtractContract.swift

- **Lines**: 122
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct PDFExtractedItem` (line 4)
- `struct PDFExtractionOutput` (line 17)
- `enum PDFExtractContract` (line 28)



**Public Functions:**
- `validate` (static) (line 33)
- `execute` (static) (line 52)


### Pipeline/Contracts/PDFIngestContract.swift

- **Lines**: 71
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct PDFIngestInput` (line 5)
- `enum PDFIngestContract` (line 13)



**Public Functions:**
- `validate` (static) (line 20)
- `execute` (static) (line 29)


### Pipeline/Contracts/PDFQACheckContract.swift

- **Lines**: 88
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct PDFQAFlag` (line 5)
- `struct PDFQAResult` (line 16)
- `enum PDFQACheckContract` (line 25)



**Public Functions:**
- `validate` (static) (line 30)
- `execute` (static) (line 34)


### Pipeline/Contracts/PDFSegmentContract.swift

- **Lines**: 137
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct PDFPageRegion` (line 5)
- `struct PDFRegionMap` (line 20)
- `enum PDFSegmentContract` (line 31)



**Public Functions:**
- `validate` (static) (line 36)
- `execute` (static) (line 61)


### Pipeline/Contracts/RunSwiftTestsContract.swift

- **Lines**: 140
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct TestRunInput` (line 5)
- `struct TestRunResult` (line 31)
- `enum RunSwiftTestsContract` (line 50)



**Public Functions:**
- `validate` (static) (line 55)
- `execute` (static) (line 76)


### Pipeline/Contracts/SharedPDFTypes.swift

- **Lines**: 16
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct PDFBlobArtifact` (line 5)




### Pipeline/GrapheneCore.swift

- **Lines**: 595
- **Public Types**: 24
- **Public Functions**: 7


**Public Types:**
- `protocol PortType` (line 27)
- `struct TextPort` (line 50)
- `struct NumberPort` (line 56)
- `struct BoolPort` (line 62)
- `struct ImagePort` (line 68)
- `struct AudioPort` (line 83)
- `struct TensorPort` (line 98)
- `struct JsonPort` (line 111)
- `struct AnyPortValue` (line 130)
- `struct PortId` (line 147)
- `struct InputPortDef` (line 160)
- `struct OutputPortDef` (line 183)
- `struct NodeParameter` (line 202)
- `enum ParameterType` (line 208)
- `enum ParameterValue` (line 233)
- `struct NodeTypeId` (line 279)
- `struct NodeDescriptor` (line 292)
- `enum ExecutionHint` (line 303)
- `struct NodeInstanceId` (line 337)
- `struct NodeInstance` (line 344)
- `struct NodeConnection` (line 375)
- `struct NodeGraphId` (line 408)
- `struct NodeGraph` (line 415)
- `enum GrapheneError` (line 564)



**Public Functions:**
- `isCompatible` (static) (line 42)
- `dictionary` (line 122)
- `incomingConnections` (line 509)
- `outgoingConnections` (line 514)
- `rootNodes` (line 519)
- `leafNodes` (line 525)
- `topologicalSort` (line 531)


### Pipeline/GrapheneEngine.swift

- **Lines**: 579
- **Public Types**: 9
- **Public Functions**: 8


**Public Types:**
- `struct GraphExecutionResult` (line 21)
- `struct NodeExecutionResult` (line 47)
- `struct ExecutionOptions` (line 72)
- `struct EngineStatistics` (line 406)
- `struct GraphBuilder` (line 422)
- `struct GraphValidator` (line 479)
- `struct ValidationResult` (line 482)
- `enum ValidationError` (line 488)
- `enum ValidationWarning` (line 511)



**Public Functions:**
- `execute` (line 131)
- `cancel` (line 371)
- `isExecuting` (line 378)
- `invalidateCache` (line 383)
- `clearCache` (line 388)
- `statistics` (line 395)
- `build` (line 471)
- `validate` (line 524)


### Pipeline/GrapheneInferenceBridge.swift

- **Lines**: 593
- **Public Types**: 16
- **Public Functions**: 14


**Public Types:**
- `protocol InferenceBridge` (line 20)
- `struct TextGenerationConfig` (line 63)
- `struct EmbeddingConfig` (line 95)
- `struct TranscriptionConfig` (line 115)
- `struct SynthesisConfig` (line 135)
- `struct TextGenerationResult` (line 157)
- `enum FinishReason` (line 165)
- `struct EmbeddingResult` (line 190)
- `struct TranscriptionResult` (line 209)
- `struct TranscriptionSegment` (line 215)
- `struct SynthesisResult` (line 236)
- `struct ModelInfo` (line 256)
- `enum ModelType` (line 265)
- `enum ModelCapability` (line 274)
- `struct BridgedTextGenerationExecutor` (line 463)
- `struct BridgedEmbeddingExecutor` (line 556)



**Public Functions:**
- `generateText` (line 313)
- `generateTextStreaming` (line 330)
- `embed` (line 351)
- `transcribe` (line 368)
- `synthesize` (line 389)
- `isModelAvailable` (line 407)
- `availableModels` (line 412)
- `register` (line 438)
- `getDefault` (line 443)
- `get` (line 448)
- `setDefault` (line 453)
- `execute` (line 470)
- `executeStreaming` (line 501)
- `execute` (line 563)


### Pipeline/GraphenePrimitives.swift

- **Lines**: 628
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct PrimitiveNodeRegistrar` (line 17)



**Public Functions:**
- `registerAll` (static) (line 19)


### Pipeline/GrapheneProfiling.swift

- **Lines**: 609
- **Public Types**: 12
- **Public Functions**: 16


**Public Types:**
- `struct ExecutionTrace` (line 20)
- `enum ProfilingExecutionStatus` (line 62)
- `struct NodeTrace` (line 71)
- `enum ExecutionBackend` (line 116)
- `struct ErrorInfo` (line 125)
- `struct AggregateStatistics` (line 450)
- `struct NodePerformanceSummary` (line 477)
- `struct TraceVisualizer` (line 490)
- `struct PerformanceAdvisor` (line 531)
- `struct Suggestion` (line 589)
- `enum SuggestionType` (line 595)
- `enum Severity` (line 603)



**Public Functions:**
- `startExecution` (line 170)
- `nodeStarted` (line 183)
- `nodeCompleted` (line 195)
- `nodeFailed` (line 215)
- `finishExecution` (line 226)
- `getTrace` (line 260)
- `recentTraces` (line 265)
- `allRecentTraces` (line 274)
- `getAggregateStats` (line 282)
- `nodePerformanceSummary` (line 287)
- `setEnabled` (line 321)
- `setMaxHistory` (line 326)
- `clearTraces` (line 331)
- `generateTimeline` (static) (line 493)
- `generateJSON` (static) (line 520)
- `analyze` (static) (line 533)


### Pipeline/GrapheneRegistry.swift

- **Lines**: 612
- **Public Types**: 4
- **Public Functions**: 19


**Public Types:**
- `protocol NodeExecutor` (line 20)
- `struct ExecutionContext` (line 31)
- `protocol NodeCacheProtocol` (line 107)
- `struct NodeCacheKey` (line 115)



**Public Functions:**
- `cancel` (line 59)
- `allocate` (line 75)
- `get` (line 79)
- `release` (line 83)
- `createTempFile` (line 87)
- `cleanup` (line 95)
- `get` (line 137)
- `set` (line 147)
- `invalidate` (line 159)
- `invalidateAll` (line 167)
- `register` (line 190)
- `unregister` (line 200)
- `descriptor` (line 208)
- `executor` (line 213)
- `allDescriptors` (line 218)
- `descriptors` (line 223)
- `allCategories` (line 228)
- `search` (line 233)
- `createInstance` (line 244)


### Pipeline/GrapheneStreaming.swift

- **Lines**: 365
- **Public Types**: 9
- **Public Functions**: 14


**Public Types:**
- `struct StreamingTextPort` (line 19)
- `struct TextChunk` (line 31)
- `protocol StreamingNodeExecutor` (line 48)
- `enum StreamingOutput` (line 59)
- `protocol StreamSubscriber` (line 142)
- `struct StreamingTextGenerationExecutor` (line 151)
- `enum StreamingGraphOutput` (line 293)
- `struct ProgressiveRefinementConfig` (line 334)
- `struct RefinementResult` (line 359)



**Public Functions:**
- `createStream` (line 76)
- `emit` (line 81)
- `close` (line 96)
- `accumulatedText` (line 111)
- `subscribe` (line 116)
- `isActive` (line 121)
- `cleanup` (line 127)
- `execute` (line 158)
- `executeStreaming` (line 194)
- `executeStreaming` (line 267)
- `addChunk` (line 311)
- `complete` (line 316)
- `accumulatedText` (line 321)
- `checkComplete` (line 326)


### Pipeline/GrapheneSubgraph.swift

- **Lines**: 598
- **Public Types**: 10
- **Public Functions**: 9


**Public Types:**
- `struct SubgraphDefinition` (line 19)
- `struct SubgraphId` (line 57)
- `struct GraphSemanticVersion` (line 64)
- `struct SubgraphInterface` (line 85)
- `struct InterfacePort` (line 99)
- `struct ExposedParameter` (line 122)
- `struct SubgraphMetadata` (line 148)
- `enum ExecutionCost` (line 174)
- `struct SubgraphExecutor` (line 403)
- `struct SubgraphBuilder` (line 474)



**Public Functions:**
- `register` (line 202)
- `unregister` (line 209)
- `get` (line 220)
- `get` (line 225)
- `subgraphs` (line 231)
- `allCategories` (line 237)
- `search` (line 242)
- `execute` (line 412)
- `build` (line 592)


### Pipeline/GrapheneVerticalSlice.swift

- **Lines**: 592
- **Public Types**: 6
- **Public Functions**: 11


**Public Types:**
- `struct PipelineFactory` (line 19)
- `enum PipelineStreamEvent` (line 473)
- `enum PipelineError` (line 482)
- `struct ThrowingTransformSequence` (line 502)
- `struct AsyncIterator` (line 505)
- `struct PipelineExamples` (line 528)



**Public Functions:**
- `createSimpleTextGeneration` (line 32)
- `createSummarization` (line 120)
- `createRAGPipeline` (line 205)
- `createTranscribeAndSummarize` (line 313)
- `runTextToText` (line 401)
- `runStreaming` (line 421)
- `runWithProfiling` (line 443)
- `makeAsyncIterator` (line 518)
- `questionAnswering` (static) (line 531)
- `summarization` (static) (line 550)
- `customPipeline` (static) (line 567)


### Pipeline/MLWorkerEmbeddingComputer.swift

- **Lines**: 111
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct MLWorkerEmbeddingComputer` (line 5)
- `enum MLWorkerEmbeddingComputerError` (line 86)



**Public Functions:**
- `computeEmbeddings` (line 12)


### Pipeline/MLWorkerInterface.swift

- **Lines**: 71
- **Public Types**: 4
- **Public Functions**: 1


**Public Types:**
- `enum MLWorkerTaskKind` (line 4)
- `struct AgentShellCommandRequest` (line 11)
- `protocol MLWorkerInterface` (line 21)
- `struct MLWorkerProcessInterface` (line 31)



**Public Functions:**
- `performMLTask` (line 38)


### Pipeline/Metopticon/MetopticonDashboard.swift

- **Lines**: 666
- **Public Types**: 19
- **Public Functions**: 7


**Public Types:**
- `struct MetopticonDashboardOverview` (line 20)
- `struct ResourcePressure` (line 84)
- `enum HealthLevel` (line 100)
- `struct CategorySummary` (line 123)
- `enum HealthStatus` (line 144)
- `struct Hotspot` (line 168)
- `enum HotspotType` (line 189)
- `enum Severity` (line 198)
- `struct TimeWindow` (line 224)
- `struct MetopticonWorkloadQuery` (line 252)
- `enum SortField` (line 283)
- `struct MetopticonWorkloadListResult` (line 317)
- `struct MetopticonWorkloadDetail` (line 346)
- `struct ExecutionPhase` (line 383)
- `struct NodeMetric` (line 406)
- `struct MetopticonExecutionContext` (line 447)
- `struct WorkloadError` (line 473)
- `struct CacheStats` (line 499)
- `struct MetopticonTemplateAnalytics` (line 521)



**Public Functions:**
- `lastHour` (static) (line 233)
- `lastDay` (static) (line 238)
- `lastWeek` (static) (line 243)
- `getOverview` (line 588)
- `queryWorkloads` (line 617)
- `getWorkloadDetail` (line 636)
- `getTemplateAnalytics` (line 655)


### Pipeline/Metopticon/MetopticonIntegration.swift

- **Lines**: 763
- **Public Types**: 11
- **Public Functions**: 15


**Public Types:**
- `struct PipelineWorkloadComponent` (line 29)
- `enum WorkloadCategory` (line 108)
- `enum WorkloadStatus` (line 133)
- `struct PipelineMetricsComponent` (line 160)
- `struct PipelineHealthComponent` (line 222)
- `enum HealthStatus` (line 232)
- `struct HealthIssue` (line 239)
- `enum Severity` (line 245)
- `struct WorkloadEntity` (line 274)
- `struct AggregateStats` (line 418)
- `struct MetopticonWorkloadConfig` (line 619)



**Public Functions:**
- `createWorkload` (line 303)
- `updateStatus` (line 313)
- `updateMetrics` (line 329)
- `updateHealth` (line 337)
- `getWorkload` (line 345)
- `queryWorkloads` (line 350)
- `cleanupOldWorkloads` (line 378)
- `getAggregateStats` (line 389)
- `getOverview` (line 468)
- `queryWorkloads` (line 514)
- `workloadStarted` (line 673)
- `updateStatus` (line 704)
- `updateFromTrace` (line 710)
- `workloadCompleted` (line 735)
- `workloadFailed` (line 746)


### Pipeline/Metopticon/MetopticonManifest.swift

- **Lines**: 683
- **Public Types**: 14
- **Public Functions**: 3


**Public Types:**
- `struct MetopticonManifest` (line 23)
- `struct Principle` (line 91)
- `struct TechnicalGuarantee` (line 108)
- `struct DataCategory` (line 133)
- `enum SensitivityLevel` (line 141)
- `struct ExcludedData` (line 165)
- `struct AllowedUse` (line 182)
- `struct ProhibitedUse` (line 205)
- `enum ViolationSeverity` (line 212)
- `struct MetopticonRetentionPolicy` (line 236)
- `struct GovernanceStructure` (line 264)
- `struct MetopticonManifestValidator` (line 613)
- `struct ManifestViolation` (line 663)
- `enum ViolationType` (line 669)



**Public Functions:**
- `defaultManifest` (static) (line 305)
- `validateTelemetryContext` (line 621)
- `validateRBACConfiguration` (line 641)


### Pipeline/Metopticon/MetopticonModule.swift

- **Lines**: 328
- **Public Types**: 4
- **Public Functions**: 12


**Public Types:**
- `struct MetopticonModule` (line 33)
- `enum Metopticon` (line 143)
- `class MetopticonDashboardViewModel` (line 221)
- `class MetopticonWorkloadListViewModel` (line 248)



**Public Functions:**
- `initialize` (static) (line 70)
- `startWorkload` (static) (line 146)
- `updateStatus` (static) (line 172)
- `completeWorkload` (static) (line 177)
- `failWorkload` (static) (line 182)
- `getOverview` (static) (line 187)
- `queryWorkloads` (static) (line 195)
- `validateTelemetry` (static) (line 208)
- `refresh` (line 232)
- `refresh` (line 261)
- `loadNextPage` (line 274)
- `createTestData` (static) (line 289)


### Pipeline/Metopticon/MetopticonRBAC.swift

- **Lines**: 533
- **Public Types**: 8
- **Public Functions**: 2


**Public Types:**
- `enum MetopticonAccessScope` (line 24)
- `enum MetopticonGranularity` (line 44)
- `struct MetopticonFieldCategories` (line 65)
- `enum MetopticonRole` (line 117)
- `struct MetopticonAccessConfiguration` (line 225)
- `struct MetopticonPrincipal` (line 269)
- `struct MetopticonWorkloadView` (line 473)
- `struct ResourceUsageView` (line 491)



**Public Functions:**
- `filterWorkloads` (line 362)
- `canAccessTraces` (line 460)


### Pipeline/Metopticon/MetopticonRunner.swift

- **Lines**: 262
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `enum MetopticonAccessError` (line 247)



**Public Functions:**
- `runPipeline` (line 52)
- `runPipelineStreaming` (line 97)


### Pipeline/PDFProcessing.swift

- **Lines**: 80
- **Public Types**: 0
- **Public Functions**: 0





### Pipeline/PipelineContractRegistry.swift

- **Lines**: 24
- **Public Types**: 0
- **Public Functions**: 2




**Public Functions:**
- `registerPDFPipelineContracts` (line 6)
- `makePDFPipelineRegistry` (line 19)


### Pipeline/PipelineECS.swift

- **Lines**: 524
- **Public Types**: 12
- **Public Functions**: 20


**Public Types:**
- `struct NodeGraphComponent` (line 18)
- `enum GraphStatus` (line 27)
- `struct NodeGraphDataComponent` (line 54)
- `struct PipelineExecutionComponent` (line 67)
- `enum ExecutionStatus` (line 77)
- `struct PipelineResultComponent` (line 98)
- `struct PipelineTemplateComponent` (line 123)
- `struct PipelineScheduleComponent` (line 151)
- `enum TriggerType` (line 160)
- `struct PipelineExecutionSystem` (line 183)
- `struct PipelineValidationSystem` (line 240)
- `struct PipelineCleanupSystem` (line 270)



**Public Functions:**
- `decode` (line 61)
- `update` (line 192)
- `update` (line 249)
- `update` (line 281)
- `createGraph` (line 322)
- `getGraph` (line 342)
- `updateGraph` (line 350)
- `deleteGraph` (line 364)
- `execute` (line 371)
- `executeAndWait` (line 397)
- `saveAsTemplate` (line 416)
- `createFromTemplate` (line 443)
- `availableNodeTypes` (line 479)
- `nodeTypes` (line 484)
- `searchNodeTypes` (line 489)
- `addHandler` (line 502)
- `entityCreated` (line 506)
- `entityDestroyed` (line 510)
- `componentAdded` (line 514)
- `componentRemoved` (line 520)


### Pipeline/PipelineGraph.swift

- **Lines**: 108
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct PipelineGraph` (line 5)
- `struct PipelinePlan` (line 63)



**Public Functions:**
- `upstream` (line 21)
- `downstream` (line 26)
- `topologicalOrder` (line 31)
- `nextEligible` (line 75)
- `inputRefs` (line 95)


### Pipeline/PipelineModule.swift

- **Lines**: 386
- **Public Types**: 4
- **Public Functions**: 10


**Public Types:**
- `struct PipelineModule` (line 28)
- `enum Capability` (line 75)
- `struct ModuleInfo` (line 86)
- `struct ModulePipelineFactory` (line 99)



**Public Functions:**
- `initialize` (static) (line 35)
- `createEngine` (static) (line 102)
- `createService` (static) (line 114)
- `createValidator` (static) (line 119)
- `createBuilder` (static) (line 124)
- `createRunner` (static) (line 134)
- `createTextPipeline` (static) (line 199)
- `createRAGPipeline` (static) (line 220)
- `createMultimodalPipeline` (static) (line 259)
- `duplicate` (line 311)


### Pipeline/PipelineRunner.swift

- **Lines**: 519
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `runWithProfiling` (line 62)
- `runStreaming` (line 74)
- `runUntilIdle` (line 97)
- `allReceipts` (line 107)
- `statusSnapshot` (line 112)


### Pipeline/PipelineStatus.swift

- **Lines**: 39
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct PipelineStatus` (line 6)
- `struct BlockedContractStatus` (line 35)




### Pipeline/PipelineStatusSerializer.swift

- **Lines**: 20
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `enum PipelineStatusSerializer` (line 6)



**Public Functions:**
- `encode` (static) (line 7)
- `decode` (static) (line 14)


### Pipeline/PluginSystem.swift

- **Lines**: 487
- **Public Types**: 13
- **Public Functions**: 12


**Public Types:**
- `protocol GraphenePlugin` (line 19)
- `struct PluginIdentifier` (line 61)
- `struct PluginVersion` (line 76)
- `struct PluginManifest` (line 107)
- `struct PluginDependency` (line 120)
- `enum PluginCapability` (line 125)
- `struct PluginState` (line 137)
- `enum PluginStatus` (line 145)
- `enum PluginError` (line 309)
- `struct ScriptNodeConfig` (line 368)
- `enum ScriptLanguage` (line 376)
- `struct ScriptNodeExecutor` (line 400)
- `struct PluginSandbox` (line 445)



**Public Functions:**
- `onLoad` (line 54)
- `onUnload` (line 55)
- `loadPlugin` (line 173)
- `unloadPlugin` (line 219)
- `reloadPlugin` (line 246)
- `discoverPlugins` (line 258)
- `loadedPlugins` (line 282)
- `state` (line 287)
- `allStates` (line 292)
- `isLoaded` (line 297)
- `nodes` (line 302)
- `execute` (line 407)


### Privacy/AccessControl.swift

- **Lines**: 530
- **Public Types**: 12
- **Public Functions**: 15


**Public Types:**
- `enum DataSensitivity` (line 26)
- `protocol SensitiveComponent` (line 61)
- `struct AccessPrincipal` (line 78)
- `struct AccessRequest` (line 112)
- `enum AccessType` (line 159)
- `struct AccessDecision` (line 169)
- `protocol AccessPolicy` (line 214)
- `struct RoleBasedPolicy` (line 229)
- `struct ModuleOwnershipPolicy` (line 292)
- `struct RestrictedDataPolicy` (line 335)
- `struct DefaultDenyPolicy` (line 363)
- `enum AccessControlError` (line 467)



**Public Functions:**
- `system` (static) (line 104)
- `allow` (static) (line 200)
- `deny` (static) (line 205)
- `evaluate` (line 261)
- `evaluate` (line 314)
- `evaluate` (line 344)
- `evaluate` (line 369)
- `setAuditLog` (line 388)
- `addPolicy` (line 393)
- `removePolicy` (line 400)
- `evaluate` (line 405)
- `checkAccess` (line 447)
- `listPolicies` (line 460)
- `getComponentControlled` (line 489)
- `queryControlled` (line 511)


### Privacy/AuditLog.swift

- **Lines**: 176
- **Public Types**: 2
- **Public Functions**: 11


**Public Types:**
- `struct AuditFilter` (line 11)
- `protocol AuditLogStorage` (line 60)



**Public Functions:**
- `matches` (line 45)
- `append` (line 82)
- `query` (line 86)
- `queryLatestEntry` (line 94)
- `count` (line 98)
- `recordEvent` (line 114)
- `query` (line 143)
- `recent` (line 148)
- `getChainHead` (line 155)
- `entryCount` (line 160)
- `verifyChain` (line 169)


### Privacy/DataLifecycle.swift

- **Lines**: 146
- **Public Types**: 5
- **Public Functions**: 3


**Public Types:**
- `struct RetentionPolicy` (line 7)
- `struct PolicyMetadata` (line 68)
- `struct GCPolicy` (line 80)
- `struct SessionDbPolicy` (line 102)
- `struct ArtifactPolicy` (line 112)



**Public Functions:**
- `load` (static) (line 47)
- `computeHash` (line 54)
- `ttlForArtifact` (line 136)


### Privacy/LifecycleManagerDebug.swift

- **Lines**: 51
- **Public Types**: 3
- **Public Functions**: 5


**Public Types:**
- `struct LifecycleSweepReport` (line 27)
- `enum LifecycleError` (line 40)
- `struct LifecycleSystem` (line 45)



**Public Functions:**
- `startMonitoring` (line 12)
- `stopMonitoring` (line 13)
- `applyPolicy` (line 14)
- `setAuditLog` (line 17)
- `listPolicies` (line 21)


### Reasoning/AdversarialScenarios.swift

- **Lines**: 516
- **Public Types**: 5
- **Public Functions**: 15


**Public Types:**
- `struct AdversarialScenario` (line 21)
- `enum ScenarioStatus` (line 123)
- `struct ScenarioResolution` (line 147)
- `enum ResolutionType` (line 179)
- `struct ScenarioLibraryStatistics` (line 508)



**Public Functions:**
- `configure` (line 210)
- `add` (line 217)
- `createFromResult` (line 242)
- `updateStatus` (line 276)
- `linkToPragma` (line 313)
- `linkToCodex` (line 321)
- `get` (line 331)
- `getByDomain` (line 336)
- `getByControl` (line 341)
- `getByStatus` (line 346)
- `getOpenScenariosBySeverity` (line 351)
- `getRegressionTestCandidates` (line 357)
- `getStatistics` (line 364)
- `export` (line 388)
- `exportAsJSON` (line 409)


### Reasoning/ContinuousReasoning.swift

- **Lines**: 830
- **Public Types**: 8
- **Public Functions**: 14


**Public Types:**
- `struct ContinuousReasoningConfig` (line 418)
- `enum ReasoningEvent` (line 470)
- `struct ReasoningHealthCheckResult` (line 493)
- `struct ContinuousReasoningStatistics` (line 503)
- `struct CICDReasoningGate` (line 517)
- `struct CICDGateResult` (line 558)
- `struct ProbeSuggestion` (line 785)
- `enum ReasoningProbeFrequency` (line 823)



**Public Functions:**
- `configure` (line 57)
- `updateConfig` (line 66)
- `queueEvent` (line 73)
- `processPendingEvents` (line 83)
- `runDomainAnalysis` (line 147)
- `runControlAnalysis` (line 198)
- `runHealthCheck` (line 287)
- `getStatistics` (line 323)
- `configure` (line 601)
- `evaluate` (line 608)
- `generateSuggestions` (line 695)
- `getPendingSuggestions` (line 741)
- `acceptSuggestion` (line 746)
- `rejectSuggestion` (line 751)


### Reasoning/DomainPuzzleBuilders.swift

- **Lines**: 1360
- **Public Types**: 9
- **Public Functions**: 13


**Public Types:**
- `struct IdentityPuzzleBuilder` (line 14)
- `struct StoragePuzzleBuilder` (line 200)
- `struct DSPSPuzzleBuilder` (line 328)
- `struct TranscriptumPuzzleBuilder` (line 578)
- `struct ConexusPuzzleBuilder` (line 778)
- `struct PragmaPuzzleBuilder` (line 868)
- `struct SecurityPuzzleBuilder` (line 968)
- `struct CodexPuzzleBuilder` (line 1188)
- `struct ObservatoriumPuzzleBuilder` (line 1278)



**Public Functions:**
- `buildSessionRiskPuzzle` (static) (line 17)
- `buildDeprovisioningPuzzle` (static) (line 93)
- `buildDisasterRecoveryPuzzle` (static) (line 203)
- `buildAccommodationCasePuzzle` (static) (line 331)
- `buildAltMediaWorkflowPuzzle` (static) (line 452)
- `buildDegreeAwardPuzzle` (static) (line 581)
- `buildEnrollmentConsistencyPuzzle` (static) (line 665)
- `buildPipelinePuzzle` (static) (line 781)
- `buildWorkflowDeadlockPuzzle` (static) (line 871)
- `buildBypassPathPuzzle` (static) (line 971)
- `buildKillSwitchPuzzle` (static) (line 1088)
- `buildPermissionPathPuzzle` (static) (line 1191)
- `buildProbeCoveragePuzzle` (static) (line 1281)


### Reasoning/DomainReasoningIntegration.swift

- **Lines**: 561
- **Public Types**: 4
- **Public Functions**: 8


**Public Types:**
- `struct DomainAnalysisResult` (line 507)
- `struct PlatformAnalysisReport` (line 519)
- `enum PlatformHealth` (line 526)
- `struct DomainReasoningIssue` (line 534)



**Public Functions:**
- `analyzeIdentity` (line 39)
- `analyzeStorage` (line 114)
- `analyzeDSPS` (line 168)
- `analyzeTranscriptum` (line 254)
- `analyzeSecurity` (line 345)
- `analyzeAllDomains` (line 415)
- `getLatestResult` (line 494)
- `getAllResults` (line 499)


### Reasoning/IRService.swift

- **Lines**: 762
- **Public Types**: 4
- **Public Functions**: 5


**Public Types:**
- `struct IRServiceConfig` (line 693)
- `struct IRRetentionPolicy` (line 712)
- `struct GraphPath` (line 728)
- `enum IRServiceError` (line 743)



**Public Functions:**
- `buildGraph` (line 42)
- `query` (line 334)
- `getGraph` (line 358)
- `getGraphHistory` (line 363)
- `cleanup` (line 368)


### Reasoning/MakerEngine.swift

- **Lines**: 570
- **Public Types**: 7
- **Public Functions**: 3


**Public Types:**
- `struct MakerEngineConfig` (line 473)
- `struct FailureRecord` (line 495)
- `struct EvaluatedCandidate` (line 508)
- `enum MakerEngineError` (line 523)
- `protocol CandidateGenerator` (line 546)
- `protocol StepExecutor` (line 551)
- `protocol QuarantineManager` (line 557)



**Public Functions:**
- `executeStep` (line 58)
- `getTrace` (line 217)
- `getFailureHistory` (line 222)


### Reasoning/MetaPuzzles.swift

- **Lines**: 967
- **Public Types**: 6
- **Public Functions**: 20


**Public Types:**
- `struct MetaPuzzle` (line 20)
- `enum MetaPuzzleCategory` (line 72)
- `struct MetaPuzzleResult` (line 95)
- `struct StandardMetaPuzzles` (line 144)
- `struct MetaPuzzleRunRecord` (line 941)
- `struct MetaPuzzleSuiteResult` (line 952)



**Public Functions:**
- `byCategory` (static) (line 172)
- `randomSubset` (static) (line 177)
- `triviallyUnbreakable` (static) (line 184)
- `isolatedStates` (static) (line 243)
- `strongInvariant` (static) (line 288)
- `trivialViolation` (static) (line 352)
- `twoStepViolation` (static) (line 399)
- `hiddenViolation` (static) (line 458)
- `impossibleGoal` (static) (line 519)
- `noTransitions` (static) (line 556)
- `conflictingPreconditions` (static) (line 588)
- `simpleLoop` (static) (line 638)
- `emptyState` (static) (line 685)
- `singleTransition` (static) (line 722)
- `configure` (line 779)
- `run` (line 785)
- `runAll` (line 851)
- `runHealthCheck` (line 868)
- `getRecentHistory` (line 886)
- `getPassRate` (line 891)


### Reasoning/PuzzleBuilders.swift

- **Lines**: 625
- **Public Types**: 6
- **Public Functions**: 11


**Public Types:**
- `struct AccessControlPuzzleBuilder` (line 63)
- `struct TenantIsolationPuzzleBuilder` (line 219)
- `struct UpdateSequencePuzzleBuilder` (line 296)
- `struct AutomationRulePuzzleBuilder` (line 384)
- `struct CompliancePuzzleBuilder` (line 471)
- `struct DataLifecyclePuzzleBuilder` (line 547)



**Public Functions:**
- `generateSymbol` (line 31)
- `anonymize` (line 37)
- `deanonymize` (line 48)
- `reset` (line 53)
- `buildUnauthorizedAccessPuzzle` (static) (line 66)
- `buildRBACVerificationPuzzle` (static) (line 153)
- `buildCrossTenantPuzzle` (static) (line 222)
- `buildMigrationSafetyPuzzle` (static) (line 299)
- `buildRuleLoopDetectionPuzzle` (static) (line 387)
- `buildControlBypassPuzzle` (static) (line 474)
- `buildLegalHoldPuzzle` (static) (line 550)


### Reasoning/ReasoningIntegration.swift

- **Lines**: 645
- **Public Types**: 24
- **Public Functions**: 9


**Public Types:**
- `struct AccessControlAnalysisContext` (line 390)
- `struct PrincipalSnapshot` (line 407)
- `struct ResourceSnapshot` (line 420)
- `struct SessionSnapshot` (line 433)
- `struct TenantIsolationAnalysisContext` (line 448)
- `struct SecurityAnalysisResult` (line 467)
- `enum SecurityAnalysisType` (line 479)
- `enum AnalysisStatus` (line 487)
- `struct SecurityIssue` (line 495)
- `enum ReasoningIssueSeverity` (line 507)
- `enum SecurityIssueCategory` (line 515)
- `struct AutomationAnalysisResult` (line 523)
- `struct AutomationIssue` (line 534)
- `enum AutomationIssueType` (line 544)
- `struct ComplianceAnalysisResult` (line 552)
- `enum ComplianceAnalysisStatus` (line 563)
- `struct ComplianceFinding` (line 570)
- `enum ComplianceFindingType` (line 581)
- `struct DataLifecycleAnalysisResult` (line 588)
- `struct DataLifecycleIssue` (line 598)
- `enum DataLifecycleIssueType` (line 608)
- `struct ReasoningServiceStatistics` (line 615)
- `enum ReasoningModule` (line 625)
- `struct ReasoningInfrastructure` (line 641)



**Public Functions:**
- `configure` (line 50)
- `setEnabled` (line 62)
- `analyzeAccessControl` (line 69)
- `analyzeTenantIsolation` (line 141)
- `analyzeAutomationRules` (line 211)
- `analyzeControlBypass` (line 263)
- `analyzeLegalHoldEnforcement` (line 309)
- `getStatistics` (line 376)
- `initialize` (static) (line 630)


### Reasoning/ReasoningKernel.swift

- **Lines**: 1041
- **Public Types**: 20
- **Public Functions**: 9


**Public Types:**
- `struct ReasoningPuzzle` (line 31)
- `enum PuzzleType` (line 88)
- `enum ReasoningDomain` (line 109)
- `struct AbstractState` (line 136)
- `enum SymbolValue` (line 161)
- `struct AbstractEdge` (line 179)
- `struct AbstractTransition` (line 192)
- `struct AbstractCondition` (line 224)
- `enum ConditionOp` (line 270)
- `struct AbstractEffect` (line 281)
- `enum EffectType` (line 326)
- `struct AbstractConstraint` (line 336)
- `enum ConstraintSeverity` (line 361)
- `struct PuzzleGoal` (line 371)
- `enum GoalType` (line 408)
- `struct ReasoningResult` (line 425)
- `enum ReasoningOutcome` (line 482)
- `struct ReasonerConfig` (line 985)
- `struct ReasonerStatistics` (line 1012)
- `enum ReasoningError` (line 1019)



**Public Functions:**
- `evaluate` (line 236)
- `apply` (line 293)
- `isSatisfied` (line 355)
- `reach` (static) (line 392)
- `violate` (static) (line 397)
- `proveInvariant` (static) (line 402)
- `setAuditLog` (line 533)
- `solve` (line 539)
- `getStatistics` (line 620)


### Reasoning/ReasoningOrchestrator.swift

- **Lines**: 492
- **Public Types**: 5
- **Public Functions**: 11


**Public Types:**
- `enum SpecializedKernelType` (line 22)
- `struct SpecializedKernelStatistics` (line 152)
- `struct EnsembleAnalysisResult` (line 162)
- `enum ReasoningRiskFactor` (line 468)
- `struct OrchestratorStatistics` (line 486)



**Public Functions:**
- `setAuditLog` (line 114)
- `solve` (line 119)
- `getStatistics` (line 136)
- `isSuitableFor` (line 146)
- `configure` (line 226)
- `dispatch` (line 236)
- `analyzeWithEnsemble` (line 250)
- `getDomainPriorities` (line 332)
- `updateDomainRisk` (line 338)
- `suggestNextAnalyses` (line 366)
- `getStatistics` (line 375)


### Reasoning/TwoTierReasoning.swift

- **Lines**: 819
- **Public Types**: 20
- **Public Functions**: 6


**Public Types:**
- `enum ReasoningTier` (line 24)
- `struct StructuredSubproblem` (line 36)
- `enum SubproblemType` (line 68)
- `struct GridState` (line 91)
- `struct ConstraintGraph` (line 129)
- `struct ConstraintVariable` (line 143)
- `struct GraphConstraint` (line 158)
- `enum GraphConstraintType` (line 173)
- `struct SchedulingProblem` (line 187)
- `struct SchedulingTask` (line 214)
- `struct SchedulingResource` (line 231)
- `struct TimeSlot` (line 246)
- `struct SchedulingConstraint` (line 257)
- `enum SchedulingConstraintType` (line 272)
- `struct SubsolverResult` (line 284)
- `enum SubsolverSolution` (line 310)
- `struct TwoTierConfig` (line 726)
- `struct TRMConfig` (line 758)
- `struct TwoTierResult` (line 782)
- `struct TwoTierStatistics` (line 812)



**Public Functions:**
- `fromFlat` (static) (line 110)
- `flatten` (line 121)
- `setAuditLog` (line 341)
- `solve` (line 346)
- `getStatistics` (line 549)
- `solve` (line 576)


### Security/CryptographicSecurity.swift

- **Lines**: 755
- **Public Types**: 8
- **Public Functions**: 22


**Public Types:**
- `enum KeyType` (line 27)
- `struct KeyUsage` (line 45)
- `struct KeyMetadata` (line 68)
- `struct EncryptionResult` (line 148)
- `struct SignatureResult` (line 234)
- `enum CryptoError` (line 664)
- `enum SecureRandom` (line 699)
- `enum HashUtilities` (line 728)



**Public Functions:**
- `serialize` (line 179)
- `deserialize` (static) (line 199)
- `setAuditLog` (line 273)
- `generateSymmetricKey` (line 278)
- `generateSigningKeyPair` (line 328)
- `deriveKey` (line 375)
- `encrypt` (line 436)
- `decrypt` (line 476)
- `sign` (line 510)
- `verify` (line 537)
- `getMetadata` (line 558)
- `listKeys` (line 563)
- `rotateKey` (line 578)
- `destroyKey` (line 631)
- `bytes` (static) (line 701)
- `uuid` (static) (line 711)
- `token` (static) (line 716)
- `sha256` (static) (line 730)
- `sha256Hex` (static) (line 735)
- `sha512` (static) (line 740)
- `hmacSHA256` (static) (line 745)
- `verifyHMACSHA256` (static) (line 751)


### Security/ExplainableAI.swift

- **Lines**: 563
- **Public Types**: 9
- **Public Functions**: 8


**Public Types:**
- `enum DecisionType` (line 24)
- `struct ContributingFactor` (line 50)
- `enum FactorInfluence` (line 96)
- `struct AIDecisionExplanation` (line 110)
- `struct AlternativeOutcome` (line 288)
- `protocol ExplainableDecisionProvider` (line 308)
- `struct XAIStatistics` (line 441)
- `struct LocalExplanationGenerator` (line 453)
- `struct FeatureContribution` (line 539)



**Public Functions:**
- `topFactors` (line 180)
- `generateReport` (line 195)
- `setAuditLog` (line 337)
- `record` (line 342)
- `get` (line 372)
- `query` (line 377)
- `statistics` (line 417)
- `generateExplanation` (line 463)


### Security/ModelIntegrity.swift

- **Lines**: 745
- **Public Types**: 11
- **Public Functions**: 17


**Public Types:**
- `struct RegisteredModel` (line 27)
- `struct ModelMetrics` (line 88)
- `enum DriftType` (line 142)
- `struct DriftEvent` (line 157)
- `enum PoisoningType` (line 220)
- `struct PoisoningAlert` (line 238)
- `struct InputValidator` (line 296)
- `struct FeatureBounds` (line 298)
- `struct InputValidationResult` (line 390)
- `struct ModelIntegrityResult` (line 707)
- `enum ModelHasher` (line 732)



**Public Functions:**
- `isValid` (line 312)
- `anomalyScore` (line 322)
- `validate` (line 350)
- `setAuditLog` (line 420)
- `registerModel` (line 425)
- `setValidator` (line 444)
- `verifyModelIntegrity` (line 449)
- `validateInput` (line 485)
- `checkForDrift` (line 517)
- `recordPoisoningAlert` (line 622)
- `getDriftEvents` (line 643)
- `getPoisoningAlerts` (line 658)
- `getModel` (line 673)
- `listModels` (line 678)
- `deactivateModel` (line 683)
- `computeHash` (static) (line 734)
- `computeHash` (static) (line 740)


### Security/PolicyEnforcement.swift

- **Lines**: 806
- **Public Types**: 10
- **Public Functions**: 28


**Public Types:**
- `enum ThreatLevel` (line 24)
- `enum EnforcementAction` (line 58)
- `struct DetectedThreat` (line 87)
- `struct EnforcementDecision` (line 145)
- `protocol EnforcementPolicy` (line 198)
- `struct ThreatLevelPolicy` (line 216)
- `struct ThreatTypePolicy` (line 268)
- `protocol PolicyEnforcementPoint` (line 314)
- `enum EnforcementError` (line 697)
- `struct ThreatFactory` (line 720)



**Public Functions:**
- `evaluate` (line 247)
- `expirationDuration` (line 255)
- `evaluate` (line 298)
- `expirationDuration` (line 305)
- `apply` (line 354)
- `revoke` (line 371)
- `isActive` (line 376)
- `shouldAllow` (line 384)
- `apply` (line 428)
- `revoke` (line 433)
- `isActive` (line 437)
- `isSessionTerminated` (line 442)
- `setAuditLog` (line 462)
- `registerPolicy` (line 467)
- `removePolicy` (line 473)
- `registerPEP` (line 478)
- `removePEP` (line 483)
- `enforce` (line 489)
- `enforceBlocking` (line 560)
- `revoke` (line 572)
- `getDecision` (line 603)
- `recentDecisions` (line 608)
- `cleanupExpired` (line 613)
- `evaluateAction` (line 633)
- `fromAccessDenial` (static) (line 724)
- `fromAnomaly` (static) (line 740)
- `fromPoisoningAttempt` (static) (line 765)
- `fromAuthFailures` (static) (line 783)


### Security/Security.swift

- **Lines**: 181
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `enum SecurityModule` (line 132)
- `struct SecurityInfrastructure` (line 172)



**Public Functions:**
- `initialize` (static) (line 137)


### Security/SecurityHardening.swift

- **Lines**: 1373
- **Public Types**: 21
- **Public Functions**: 46


**Public Types:**
- `struct BypassAttempt` (line 126)
- `struct BypassStatistics` (line 135)
- `enum BypassError` (line 143)
- `struct SessionRiskAssessment` (line 299)
- `enum RiskFactor` (line 310)
- `enum SessionActivityType` (line 322)
- `struct TenantOperationContext` (line 433)
- `struct CrossTenantAttempt` (line 441)
- `enum TenantIsolationError` (line 451)
- `struct OperationProfile` (line 562)
- `enum CheckpointProfileType` (line 597)
- `struct AuditAnchor` (line 761)
- `struct IntegrityVerificationResult` (line 771)
- `struct AutomationSandbox` (line 986)
- `struct SandboxedOperation` (line 1001)
- `struct SandboxViolation` (line 1024)
- `enum ViolationType` (line 1032)
- `enum ContainmentError` (line 1041)
- `enum HealthStatus` (line 1240)
- `struct SecurityHealthReport` (line 1247)
- `enum StandardOperationProfiles` (line 1262)



**Public Functions:**
- `setAuditLog` (line 46)
- `registerAccessPath` (line 51)
- `validateAccessPath` (line 56)
- `getStatistics` (line 101)
- `clearLockdown` (line 111)
- `setAuditLog` (line 188)
- `registerSession` (line 193)
- `recordActivity` (line 225)
- `requiresStepUp` (line 269)
- `shouldTerminate` (line 274)
- `removeSession` (line 280)
- `getAssessment` (line 285)
- `setAuditLog` (line 349)
- `registerTenant` (line 354)
- `beginOperation` (line 359)
- `validateAccess` (line 377)
- `endOperation` (line 422)
- `getCrossTenantAttempts` (line 427)
- `setAuditLog` (line 494)
- `setEnforcement` (line 499)
- `register` (line 504)
- `registerAll` (line 509)
- `getProfile` (line 516)
- `isAllowed` (line 536)
- `listOperations` (line 556)
- `configureSigning` (line 636)
- `record` (line 642)
- `createAnchor` (line 681)
- `verifyIntegrity` (line 713)
- `getAnchors` (line 755)
- `setAuditLog` (line 798)
- `createSandbox` (line 803)
- `validateOperation` (line 836)
- `closeSandbox` (line 924)
- `killAgent` (line 929)
- `reviveAgent` (line 944)
- `isAgentKilled` (line 959)
- `getViolations` (line 964)
- `setAuditLog` (line 1089)
- `registerSessionInvalidator` (line 1094)
- `registerCapabilityCacheInvalidator` (line 1099)
- `deprovision` (line 1104)
- `isDeprovisioned` (line 1139)
- `reprovision` (line 1144)
- `getDeprovisionedPrincipals` (line 1167)
- `healthCheck` (line 1208)


### Security/VulnerabilityDisclosure.swift

- **Lines**: 834
- **Public Types**: 9
- **Public Functions**: 16


**Public Types:**
- `enum VulnerabilitySeverity` (line 27)
- `enum VulnerabilityStatus` (line 63)
- `struct AffectedComponent` (line 92)
- `struct VulnerabilityRecord` (line 126)
- `struct VulnerabilityReference` (line 278)
- `enum ReferenceType` (line 291)
- `struct SecurityAdvisory` (line 305)
- `struct VulnerabilityStatistics` (line 804)
- `enum VulnerabilityError` (line 815)



**Public Functions:**
- `from` (static) (line 44)
- `toMarkdown` (line 395)
- `setAuditLog` (line 473)
- `reportVulnerability` (line 478)
- `confirmVulnerability` (line 527)
- `assignCVE` (line 587)
- `markFixed` (line 610)
- `publishAdvisory` (line 631)
- `getVulnerability` (line 698)
- `getVulnerability` (line 703)
- `getAdvisory` (line 708)
- `listVulnerabilities` (line 713)
- `listAdvisories` (line 736)
- `getUpcomingDisclosures` (line 754)
- `getOverdueDisclosures` (line 766)
- `getStatistics` (line 773)


### Storage/Storage.swift

- **Lines**: 724
- **Public Types**: 21
- **Public Functions**: 3


**Public Types:**
- `struct StorageBackendComponent` (line 21)
- `enum StorageType` (line 95)
- `enum StorageStatus` (line 113)
- `enum StorageEncryption` (line 131)
- `struct StorageReplication` (line 143)
- `enum ReplicationType` (line 161)
- `struct HealthCheckResult` (line 167)
- `struct BackupSnapshotComponent` (line 186)
- `enum BackupType` (line 276)
- `enum BackupStatus` (line 291)
- `struct RecoveryOperationComponent` (line 317)
- `enum RecoveryType` (line 389)
- `enum RecoveryStatus` (line 404)
- `struct StorageValidationResult` (line 428)
- `struct LegalHoldComponent` (line 449)
- `struct DataExportRequestComponent` (line 528)
- `enum DataExportType` (line 593)
- `enum DataExportStatus` (line 608)
- `enum ExportFormat` (line 618)
- `struct BackupScheduleComponent` (line 628)
- `struct DisasterRecoveryTargets` (line 688)



**Public Functions:**
- `holdsEntity` (line 510)
- `holdsSubject` (line 515)
- `holdsDomain` (line 520)


### Sync/SyncInfrastructure.swift

- **Lines**: 635
- **Public Types**: 17
- **Public Functions**: 11


**Public Types:**
- `enum DataAuthority` (line 22)
- `struct DomainSyncConfig` (line 37)
- `enum ConflictResolutionPolicy` (line 66)
- `struct SyncRecordId` (line 86)
- `struct SyncRecord` (line 95)
- `enum SyncOperation` (line 139)
- `enum SyncStatus` (line 149)
- `enum SyncDirection` (line 159)
- `struct SyncConflict` (line 165)
- `enum ConflictResolution` (line 191)
- `protocol ExternalSystemAdapter` (line 202)
- `struct ExternalRecord` (line 236)
- `enum AnyCodableValue` (line 262)
- `struct SyncStats` (line 537)
- `enum SyncError` (line 553)
- `struct SyncMetadataComponent` (line 585)
- `struct SyncedSystemInfo` (line 614)



**Public Functions:**
- `encode` (line 295)
- `registerDomain` (line 337)
- `getConfig` (line 342)
- `setAuthority` (line 347)
- `registerAdapter` (line 368)
- `linkRecord` (line 376)
- `getLinkedEntity` (line 386)
- `getLinkedExternalId` (line 395)
- `syncInbound` (line 410)
- `getHistory` (line 503)
- `getStats` (line 522)


### Telemetry/EnhancedTelemetryIntegration.swift

- **Lines**: 454
- **Public Types**: 7
- **Public Functions**: 10


**Public Types:**
- `struct PIIDetector` (line 15)
- `struct EnhancedTelemetryManifest` (line 62)
- `struct EnhancedManifestGenerator` (line 183)
- `struct TelemetryComplianceProbes` (line 213)
- `struct ProbeResult` (line 216)
- `struct InferenceTelemetryHelper` (line 321)
- `struct EnhancedTelemetryStatistics` (line 427)



**Public Functions:**
- `detectsPII` (line 34)
- `keyNameSuggestsPII` (line 53)
- `toMarkdown` (line 108)
- `generate` (line 188)
- `probePIIFree` (static) (line 231)
- `probeRetention` (static) (line 263)
- `probeNoBehaviorTracking` (static) (line 291)
- `createInferenceEvent` (static) (line 324)
- `createBehaviorEvent` (static) (line 362)
- `createDiffusionEvent` (static) (line 396)


### Telemetry/TelemetryService.swift

- **Lines**: 567
- **Public Types**: 8
- **Public Functions**: 19


**Public Types:**
- `enum TelemetryGateResult` (line 210)
- `struct TelemetryViolation` (line 221)
- `struct TelemetryStatistics` (line 445)
- `struct TelemetryManifestGenerator` (line 455)
- `struct TelemetryManifest` (line 538)
- `struct CategoryDescription` (line 549)
- `struct PurposeDescription` (line 554)
- `struct MetricDescription` (line 559)



**Public Functions:**
- `setPolicy` (line 30)
- `getPolicy` (line 35)
- `ensurePolicy` (line 40)
- `validate` (line 49)
- `registerMetric` (line 84)
- `getMetric` (line 89)
- `listMetrics` (line 94)
- `recentViolations` (line 117)
- `record` (line 245)
- `recordOperational` (line 272)
- `recordFeatureUsage` (line 294)
- `getEvents` (line 318)
- `getAggregates` (line 340)
- `aggregate` (line 359)
- `ensurePolicy` (line 408)
- `setPolicy` (line 413)
- `getPolicy` (line 418)
- `statistics` (line 425)
- `generate` (static) (line 458)


### Telemetry/TelemetryTypes.swift

- **Lines**: 370
- **Public Types**: 13
- **Public Functions**: 1


**Public Types:**
- `enum TelemetryCategory` (line 21)
- `enum TelemetryPurpose` (line 39)
- `struct TelemetryEvent` (line 59)
- `enum RoleCategory` (line 124)
- `enum RetentionTier` (line 135)
- `struct TelemetryPolicy` (line 161)
- `enum TelemetryMode` (line 202)
- `struct MetricDefinition` (line 238)
- `enum AggregationType` (line 270)
- `enum DashboardScope` (line 281)
- `struct AggregatedMetric` (line 298)
- `enum MetricPeriod` (line 333)
- `enum TelemetryError` (line 342)



**Public Functions:**
- `allows` (line 194)


### Tenant/Tenant.swift

- **Lines**: 562
- **Public Types**: 13
- **Public Functions**: 4


**Public Types:**
- `struct TenantComponent` (line 21)
- `enum TenantType` (line 99)
- `enum TenantStatus` (line 123)
- `struct WorkspaceComponent` (line 143)
- `enum WorkspaceType` (line 206)
- `struct WorkspaceUITheme` (line 233)
- `struct EnvironmentComponent` (line 248)
- `enum EnvironmentType` (line 303)
- `struct EnvironmentConfiguration` (line 321)
- `struct WorkspaceMembershipComponent` (line 417)
- `enum WorkspaceRole` (line 457)
- `struct TenantContext` (line 474)
- `enum StandardFeatures` (line 524)



**Public Functions:**
- `development` (static) (line 372)
- `staging` (static) (line 386)
- `production` (static) (line 400)
- `isFeatureEnabled` (line 515)


### Updates/Checkpointing.swift

- **Lines**: 490
- **Public Types**: 8
- **Public Functions**: 18


**Public Types:**
- `enum DraftState` (line 12)
- `struct DraftComponent` (line 23)
- `struct DraftMetadata` (line 61)
- `struct WorkflowCheckpoint` (line 92)
- `enum WorkflowCheckpointState` (line 142)
- `struct WorkflowCheckpointComponent` (line 154)
- `struct CheckpointSweepResult` (line 461)
- `struct CheckpointStatistics` (line 468)



**Public Functions:**
- `crossesVersion` (line 135)
- `createDraft` (line 181)
- `updateDraft` (line 200)
- `getDraft` (line 213)
- `getDrafts` (line 218)
- `getDrafts` (line 223)
- `submitDraft` (line 228)
- `abandonDraft` (line 237)
- `createCheckpoint` (line 248)
- `updateCheckpoint` (line 265)
- `getCheckpoint` (line 290)
- `getCheckpoints` (line 295)
- `pauseCheckpoint` (line 302)
- `markForReview` (line 321)
- `completeCheckpoint` (line 346)
- `checkpointSweep` (line 367)
- `cleanupExpired` (line 410)
- `getStatistics` (line 430)


### Updates/MigrationEngine.swift

- **Lines**: 594
- **Public Types**: 9
- **Public Functions**: 15


**Public Types:**
- `enum MigrationStatus` (line 12)
- `struct MigrationRecord` (line 24)
- `protocol Migration` (line 69)
- `struct MigrationContext` (line 103)
- `struct DetailedMigrationResult` (line 131)
- `struct MigrationPlan` (line 161)
- `struct MigrationExecutionResult` (line 520)
- `struct DryRunResult` (line 536)
- `struct DataTransformMigration` (line 551)



**Public Functions:**
- `success` (static) (line 149)
- `failure` (static) (line 153)
- `register` (line 206)
- `register` (line 211)
- `plan` (line 220)
- `planRollback` (line 244)
- `execute` (line 265)
- `rollback` (line 362)
- `dryRun` (line 458)
- `getCurrentVersion` (line 497)
- `getHistory` (line 502)
- `getPending` (line 507)
- `wasExecuted` (line 512)
- `up` (line 581)
- `down` (line 586)


### Updates/UpdateCodexIntegration.swift

- **Lines**: 746
- **Public Types**: 16
- **Public Functions**: 12


**Public Types:**
- `struct ReleaseDocumentation` (line 13)
- `enum ReleaseType` (line 75)
- `enum ChangeCategory` (line 84)
- `struct ChangeItem` (line 96)
- `struct MigrationNote` (line 116)
- `enum DataImpact` (line 145)
- `struct BreakingChange` (line 153)
- `struct KnownIssue` (line 173)
- `enum IssueSeverity` (line 193)
- `struct TestingInstruction` (line 201)
- `enum TestPriority` (line 224)
- `struct ReleaseDocumentationGenerator` (line 234)
- `struct CodexPageContent` (line 473)
- `enum ContentType` (line 479)
- `struct CodexPageMetadata` (line 499)
- `class ReleaseDocumentationBuilder` (line 530)



**Public Functions:**
- `generateMarkdown` (static) (line 239)
- `generateCodexPageContent` (static) (line 367)
- `generateStakeholderSummary` (static) (line 390)
- `summary` (line 540)
- `releaseType` (line 563)
- `addChange` (line 586)
- `addMigration` (line 615)
- `addBreakingChange` (line 641)
- `addKnownIssue` (line 667)
- `addStakeholderNote` (line 693)
- `affectedModules` (line 719)
- `build` (line 742)


### Updates/UpdateIntegration.swift

- **Lines**: 630
- **Public Types**: 7
- **Public Functions**: 20


**Public Types:**
- `struct UpdatePhaseCheck` (line 14)
- `struct DomainProfiles` (line 157)
- `struct UpdateCohort` (line 314)
- `enum CohortCriteria` (line 340)
- `enum CohortRolloutState` (line 511)
- `struct RolloutStatistics` (line 521)
- `struct StandardCohorts` (line 543)



**Public Functions:**
- `appliesTo` (line 33)
- `evaluate` (line 38)
- `register` (line 87)
- `registerModuleDefault` (line 99)
- `setGlobalDefault` (line 107)
- `registerBatch` (line 112)
- `getProfile` (line 121)
- `getProfile` (line 138)
- `listProfiles` (line 143)
- `matches` (line 350)
- `registerCohort` (line 390)
- `getCohort` (line 395)
- `listCohorts` (line 400)
- `assignClient` (line 405)
- `getClientCohort` (line 410)
- `autoAssignClient` (line 416)
- `setRolloutState` (line 443)
- `getRolloutState` (line 455)
- `isVersionAvailable` (line 463)
- `getRolloutStatistics` (line 481)


### Updates/UpdateObservability.swift

- **Lines**: 504
- **Public Types**: 18
- **Public Functions**: 6


**Public Types:**
- `struct UpdateTelemetryEvents` (line 12)
- `enum EventName` (line 15)
- `struct UpdateMetrics` (line 39)
- `enum MetricName` (line 42)
- `struct UpdateTelemetryPayload` (line 221)
- `struct MigrationTelemetryPayload` (line 229)
- `struct UpdateMetricsSnapshot` (line 239)
- `struct UpdateAlerts` (line 255)
- `enum AlertType` (line 258)
- `struct Thresholds` (line 269)
- `struct UpdateDashboardData` (line 289)
- `struct ClientVersionBreakdown` (line 324)
- `struct RolloutProgress` (line 346)
- `struct CohortProgress` (line 369)
- `struct UpdateEventSummary` (line 389)
- `struct MigrationSummary` (line 404)
- `struct UpdateAlertSummary` (line 423)
- `struct UpdateReportGenerator` (line 440)



**Public Functions:**
- `recordEvent` (line 87)
- `recordClientUpdate` (line 141)
- `markUpdateRequested` (line 157)
- `recordMigration` (line 162)
- `generateMetricsSnapshot` (line 178)
- `generateAdminSummary` (static) (line 443)


### Updates/UpdateOrchestrator.swift

- **Lines**: 614
- **Public Types**: 7
- **Public Functions**: 21


**Public Types:**
- `enum UpdatePhase` (line 12)
- `struct UpdateEvent` (line 25)
- `enum UpdateEventType` (line 57)
- `enum CheckpointProfile` (line 78)
- `struct UpdateDecision` (line 102)
- `enum RequiredAction` (line 136)
- `struct UpdateStatistics` (line 598)



**Public Functions:**
- `isAllowed` (line 85)
- `allow` (static) (line 126)
- `deny` (static) (line 130)
- `getPhase` (line 172)
- `getPlatformVersion` (line 177)
- `announceRelease` (line 182)
- `startDrainMode` (line 206)
- `blockOutdatedClients` (line 241)
- `enterMaintenance` (line 277)
- `completeDeployment` (line 293)
- `returnToStable` (line 316)
- `registerClient` (line 351)
- `updateClientActivity` (line 371)
- `markClientUpdated` (line 388)
- `getClientState` (line 417)
- `getAllClientStates` (line 422)
- `canProceed` (line 429)
- `setPolicy` (line 492)
- `getActivePolicy` (line 527)
- `getStatistics` (line 534)
- `getRecentEvents` (line 556)


### Updates/UpdateService.swift

- **Lines**: 491
- **Public Types**: 4
- **Public Functions**: 20


**Public Types:**
- `struct UpdateFlowResult` (line 443)
- `struct UpdatePreview` (line 454)
- `struct ClientRegistrationResult` (line 470)
- `struct UpdateStatus` (line 481)



**Public Functions:**
- `registerRelease` (line 44)
- `getAvailableReleases` (line 49)
- `getCurrentRelease` (line 54)
- `startUpdate` (line 61)
- `beginDrainMode` (line 96)
- `endGracePeriod` (line 112)
- `executeUpdate` (line 123)
- `performFullUpdate` (line 190)
- `previewUpdate` (line 232)
- `registerClient` (line 279)
- `canPerformOperation` (line 319)
- `createDraft` (line 329)
- `saveDraft` (line 346)
- `getDrafts` (line 351)
- `createWorkflowCheckpoint` (line 356)
- `updateWorkflowStep` (line 371)
- `getWorkflowCheckpoints` (line 384)
- `registerMigrations` (line 391)
- `getMigrationHistory` (line 396)
- `getStatus` (line 403)


### Updates/VersionManagement.swift

- **Lines**: 416
- **Public Types**: 16
- **Public Functions**: 7


**Public Types:**
- `struct SemanticVersion` (line 12)
- `struct PlatformVersion` (line 85)
- `enum DeploymentEnvironment` (line 108)
- `struct ReleaseManifest` (line 134)
- `struct ReleaseFlags` (line 185)
- `struct MigrationInfo` (line 208)
- `struct ClientVersionState` (line 236)
- `struct ClientCapabilities` (line 276)
- `enum ClientUpdateStatus` (line 296)
- `struct VersionPolicy` (line 307)
- `enum PolicyScope` (line 348)
- `enum EnforcementLevel` (line 356)
- `struct PlatformVersionComponent` (line 365)
- `struct ClientStateComponent` (line 378)
- `struct ReleaseManifestComponent` (line 393)
- `enum DeploymentStatus` (line 408)



**Public Functions:**
- `satisfies` (line 72)
- `isBreakingFrom` (line 77)
- `isMandatory` (line 171)
- `timeUntilMandatory` (line 177)
- `isVersionAcceptable` (line 270)
- `isInGracePeriod` (line 335)
- `isFullyEnforced` (line 341)


### Utilities/Configuration.swift

- **Lines**: 180
- **Public Types**: 4
- **Public Functions**: 16


**Public Types:**
- `protocol ConfigurationSource` (line 14)
- `struct EnvironmentConfigSource` (line 25)
- `struct DictionaryConfigSource` (line 47)
- `enum ConfigKey` (line 174)



**Public Functions:**
- `get` (line 32)
- `allKeys` (line 37)
- `get` (line 54)
- `allKeys` (line 58)
- `setSources` (line 77)
- `addSource` (line 83)
- `setDefaults` (line 93)
- `get` (line 98)
- `get` (line 117)
- `getInt` (line 122)
- `getInt` (line 127)
- `getDouble` (line 132)
- `getBool` (line 137)
- `getBool` (line 147)
- `allKeys` (line 152)
- `clearCache` (line 166)


### Utilities/Errors.swift

- **Lines**: 138
- **Public Types**: 3
- **Public Functions**: 4


**Public Types:**
- `protocol AnigmaError` (line 15)
- `enum ErrorCategory` (line 35)
- `struct CoreError` (line 61)



**Public Functions:**
- `configuration` (static) (line 92)
- `io` (static) (line 97)
- `validation` (static) (line 102)
- `wrapError` (line 128)


### Utilities/Logging.swift

- **Lines**: 233
- **Public Types**: 4
- **Public Functions**: 18


**Public Types:**
- `enum LogLevel` (line 14)
- `struct LogEntry` (line 52)
- `protocol LogHandler` (line 94)
- `struct ConsoleLogHandler` (line 99)



**Public Functions:**
- `log` (line 108)
- `setHandlers` (line 129)
- `addHandler` (line 134)
- `setDefaultCategory` (line 139)
- `setGlobalMetadata` (line 144)
- `log` (line 149)
- `trace` (line 180)
- `debug` (line 184)
- `info` (line 188)
- `warning` (line 192)
- `error` (line 196)
- `critical` (line 200)
- `logTrace` (line 210)
- `logDebug` (line 214)
- `logInfo` (line 218)
- `logWarning` (line 222)
- `logError` (line 226)
- `logCritical` (line 230)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
