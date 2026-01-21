# HarmoniaModule

## Overview

HarmoniaModule is a Swift module in the Anigma ecosystem with **52162 lines of code** across **149 files**.

## Statistics

- **Public Types**: 749
- **Public Functions**: 804  
- **Components**: 39
- **Systems**: 85
- **Services**: 0

## Architecture

### Components
- `Position`
- `Velocity`
- `Sprite`
- `InputControlled`
- `ActorRole`
- `Role`
- `FactionAlignment`
- `Faction`
- `RelationshipMeter`
- `Interactable`
- `InteractionKind`
- `InteractionZone`
- `DialogueNode`
- `SceneTrigger`
- `SceneState`
- `WorldState`
- `ChoiceEntry`
- `ChoiceHistory`
- `UIFlowchartView`
- `UIDialogueView`
- `StateEffect`
- `Kind`
- `SceneTransition`
- `EntityBlueprint`
- `SceneDefinition`
- `ChoiceDefinition`
- `ConcurrencyStateComponent`
- `PressureLevel`
- `HealthComponent`
- `HealthStatus`
- `MLTaskComponent`
- `MLResultComponent`
- `MetricsComponent`
- `RequestComponent`
- `RequestPhase`
- `SessionComponent`
- `SlotComponent`
- `SlotStatus`
- `ThroughputSampleComponent`

### Systems
- `ProjectCodingAgentSystem`
- `CodingSandboxConfig`
- `CodingContext`
- `ToolExecutionResults`
- `TestResults`
- `CodingIterationResult`
- `CodingSessionResult`
- `ProjectInitializerSystem`
- `ProjectSpecComponent`
- `FeatureTestCaseComponent`
- `ProjectInitializationConfig`
- `ProjectInitializationResult`
- `Logger`
- `InputSystem`
- `MovementSystem`
- `RenderingSystem`
- `InteractionSystem`
- `DialogueSystem`
- `SceneResolutionSystem`
- `PsychohistorySystem`
- `UISystem`
- `Aerodrome9Systems`
- `SemanticSearchResult`
- `TextSearchResult`
- `SearchResultItem`
- `DocumentWithProvenance`
- `ArtifactWithVerification`
- `CoverageReport`
- `RepoScanResult`
- `DiagnosticSearchResult`
- `RepoFile`
- `DiagnosticResult`
- `CustodyStep`
- `AgentError`
- `BuildIngestionResult`
- `EvidenceViolationSeverity`
- `EvidenceViolationType`
- `EnforcementActionType`
- `EvidenceApprovalStatus`
- `DocumentUnit`
- `VectorSearchResult`
- `ContentSearchResult`
- `EmbeddingIngestionResult`
- `EmbeddingIngestionError`
- `MLOperationType`
- `MLOperationResult`
- `OperationEvidence`
- `ForensicValidationResult`
- `RetrievalValidationResult`
- `EvidenceValidationResult`
- `EvidenceCheckResult`
- `EvidenceEnforcementResult`
- `CathedralError`
- `ForensicFileType`
- `ForensicAcquisitionMethod`
- `ForensicTransformationType`
- `ForensicTransmissionType`
- `ForensicAcquisition`
- `ForensicTransformation`
- `ForensicTransmission`
- `ForensicChain`
- `ForensicChainSummary`
- `ConcurrencySyncSystem`
- `MetricsAggregationSystem`
- `HealthCheckSystem`
- `ThroughputSamplingSystem`
- `RequestCleanupSystem`
- `SessionCleanupSystem`
- `SlotTimeoutSystem`
- `MLWorkerDispatchSystem`
- `SlotManagementSystem`
- `QueryEmbeddingResult`
- `RetrievalEvidence`
- `RetrievalResultItem`
- `RetrievalProvenance`
- `ExplainableRetrievalResult`
- `RetrievalAuditReport`
- `ReproducibilityReport`
- `ResultDifference`
- `ResultDifferenceType`
- `SecurityAwareMigrationEngineFactory`
- `BlockedMigrationEngine`
- `SlotManagementSystem`
- `StepEngine`
- `BundleExportFormat`

### Services
No services found

## Dependencies

- `DatabaseCore`
- `AnigmaCore`
- `ContractsCore`
- `AnigmaPrimitives`
- `AnigmaASTServices`
- `AnigmaASTServicesCore`

## File Structure


### Architecture/ArchitectureManifest.swift

- **Lines**: 300
- **Public Types**: 3
- **Public Functions**: 4


**Public Types:**
- `struct CanonicalAbstraction` (line 15)
- `enum Category` (line 17)
- `enum ArchitectureManifest` (line 84)



**Public Functions:**
- `findMatches` (static) (line 237)
- `abstractions` (static) (line 286)
- `abstraction` (static) (line 291)
- `abstraction` (static) (line 296)


### Architecture/ReuseGate.swift

- **Lines**: 329
- **Public Types**: 6
- **Public Functions**: 5


**Public Types:**
- `enum ReuseGatePolicy` (line 15)
- `struct ReuseGateResult` (line 29)
- `enum JustificationLevel` (line 34)
- `struct CreationContext` (line 118)
- `protocol ReuseGate` (line 162)
- `struct Statistics` (line 182)



**Public Functions:**
- `block` (static) (line 87)
- `requireJustification` (static) (line 98)
- `evaluate` (line 197)
- `logDecision` (line 250)
- `defaultReuseGate` (line 323)


### CLI/CathedralIntegrationDemo.swift

- **Lines**: 204
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `enum DemoOperationType` (line 178)
- `enum DemoCathedralError` (line 185)



**Public Functions:**
- `demonstrateEvidenceEnforcement` (line 22)


### CLI/SearchCommand.swift

- **Lines**: 102
- **Public Types**: 0
- **Public Functions**: 0





### Capability/SessionListingLegacyAdapter.swift

- **Lines**: 321
- **Public Types**: 2
- **Public Functions**: 4


**Public Types:**
- `struct LegacySessionTrustVerifier` (line 252)
- `enum SessionListingAdapterFactory` (line 290)



**Public Functions:**
- `verifySession` (line 255)
- `verifySessions` (line 268)
- `createLegacyAdapter` (static) (line 292)
- `createLegacyAdapter` (static) (line 305)


### Capability/SessionListingProviding.swift

- **Lines**: 201
- **Public Types**: 6
- **Public Functions**: 0


**Public Types:**
- `protocol SessionListingProviding` (line 27)
- `struct SessionListingAccessRequest` (line 106)
- `enum SessionListingOperation` (line 128)
- `enum SessionListingError` (line 135)
- `struct SessionTrustResult` (line 164)
- `protocol SessionTrustVerifier` (line 188)




### Capability/SessionListingService.swift

- **Lines**: 408
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct ProjectComponent` (line 399)




### Components/Aerodrome9Components.swift

- **Lines**: 327
- **Public Types**: 26
- **Public Functions**: 0


**Public Types:**
- `struct Position` (line 15)
- `struct Velocity` (line 26)
- `struct Sprite` (line 37)
- `struct InputControlled` (line 48)
- `struct ActorRole` (line 59)
- `enum Role` (line 60)
- `struct FactionAlignment` (line 74)
- `enum Faction` (line 75)
- `struct RelationshipMeter` (line 91)
- `struct Interactable` (line 104)
- `enum InteractionKind` (line 105)
- `struct InteractionZone` (line 122)
- `struct DialogueNode` (line 131)
- `struct SceneTrigger` (line 140)
- `struct SceneState` (line 153)
- `struct WorldState` (line 166)
- `struct ChoiceEntry` (line 177)
- `struct ChoiceHistory` (line 190)
- `struct UIFlowchartView` (line 201)
- `struct UIDialogueView` (line 210)
- `struct StateEffect` (line 223)
- `enum Kind` (line 224)
- `struct SceneTransition` (line 243)
- `struct EntityBlueprint` (line 254)
- `struct SceneDefinition` (line 265)
- `struct ChoiceDefinition` (line 303)




### Components/ConcurrencyStateComponent.swift

- **Lines**: 80
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct ConcurrencyStateComponent` (line 13)
- `enum PressureLevel` (line 65)




### Components/HealthComponent.swift

- **Lines**: 51
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct HealthComponent` (line 13)
- `enum HealthStatus` (line 36)




### Components/MLWorkerComponents.swift

- **Lines**: 75
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct MLTaskComponent` (line 11)
- `struct MLResultComponent` (line 45)




### Components/MetricsComponent.swift

- **Lines**: 62
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct MetricsComponent` (line 13)




### Components/RequestComponent.swift

- **Lines**: 59
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct RequestComponent` (line 13)
- `enum RequestPhase` (line 50)




### Components/SessionComponent.swift

- **Lines**: 47
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct SessionComponent` (line 13)




### Components/SlotComponent.swift

- **Lines**: 38
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct SlotComponent` (line 13)
- `enum SlotStatus` (line 33)




### Components/ThroughputSampleComponent.swift

- **Lines**: 34
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct ThroughputSampleComponent` (line 13)




### Config/RetentionPolicy.swift

- **Lines**: 1
- **Public Types**: 0
- **Public Functions**: 0





### Doctrine/ASTClient.swift

- **Lines**: 442
- **Public Types**: 3
- **Public Functions**: 3


**Public Types:**
- `struct ParseResult` (line 359)
- `struct AnalyzeResult` (line 367)
- `enum ASTError` (line 423)



**Public Functions:**
- `parseFile` (line 30)
- `analyzeFile` (line 40)
- `analyzeDirectory` (line 50)


### Doctrine/ConcreteLawCompliancePack.swift

- **Lines**: 795
- **Public Types**: 7
- **Public Functions**: 4


**Public Types:**
- `enum PIILevel` (line 17)
- `struct DataClassification` (line 25)
- `struct ConcreteLawCompliancePack` (line 48)
- `struct DoctrinePrinciple` (line 266)
- `struct PIIConfiguration` (line 662)
- `struct DoctrineDebtTask` (line 686)
- `enum TaskStatus` (line 700)



**Public Functions:**
- `classifyField` (static) (line 242)
- `checks` (static) (line 255)
- `scan` (line 297)
- `fromViolation` (static) (line 737)


### Doctrine/DoctrinalRegistry.swift

- **Lines**: 81
- **Public Types**: 1
- **Public Functions**: 5


**Public Types:**
- `protocol DoctrinalScout` (line 13)



**Public Functions:**
- `register` (line 33)
- `getScout` (line 37)
- `getAllScouts` (line 41)
- `scanFile` (line 45)
- `scanDirectory` (line 53)


### Doctrine/DoctrinalScouts.swift

- **Lines**: 235
- **Public Types**: 0
- **Public Functions**: 3




**Public Functions:**
- `scan` (line 21)
- `scan` (line 97)
- `scan` (line 162)


### Doctrine/DoctrineBridge.swift

- **Lines**: 167
- **Public Types**: 5
- **Public Functions**: 2


**Public Types:**
- `struct DoctrineBridgeRule` (line 12)
- `struct DoctrineBridgeViolationInput` (line 40)
- `struct DoctrineCheck` (line 83)
- `enum CheckImplementation` (line 92)
- `enum DoctrineBridge` (line 119)



**Public Functions:**
- `makeCheck` (static) (line 120)
- `makeViolation` (static) (line 133)


### Doctrine/DoctrineGuards.swift

- **Lines**: 646
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct DoctrineGuardResult` (line 39)
- `struct ComplianceProfile` (line 526)



**Public Functions:**
- `check` (line 78)
- `check` (line 216)
- `check` (line 341)
- `checkAll` (line 563)
- `getComplianceSummary` (line 623)


### Doctrine/DoctrineIntegration.swift

- **Lines**: 81
- **Public Types**: 0
- **Public Functions**: 6




**Public Functions:**
- `convertViolationsToDebtTasks` (line 22)
- `getBlockingDebtTasks` (line 28)
- `updateTaskStatus` (line 34)
- `getDoctrineHealthScore` (line 41)
- `getDoctrineStatistics` (line 64)
- `getUnresolvedViolations` (line 77)


### Doctrine/DoctrineMigrationIntegration.swift

- **Lines**: 259
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `struct DoctrineAwareMigrationEngineFactory` (line 162)



**Public Functions:**
- `process` (line 33)
- `engine` (static) (line 164)
- `update` (line 183)
- `getDoctrineHealth` (line 220)


### Doctrine/DoctrinePacks.swift

- **Lines**: 1
- **Public Types**: 0
- **Public Functions**: 0





### Doctrine/SecurityDoctrinePack.swift

- **Lines**: 351
- **Public Types**: 4
- **Public Functions**: 5


**Public Types:**
- `struct SecurityDoctrinePackV1` (line 19)
- `struct DoctrineEvaluationContext` (line 222)
- `struct DoctrineEvaluationResult` (line 239)
- `struct DoctrineWarning` (line 274)



**Public Functions:**
- `rule` (line 27)
- `canOverride` (line 31)
- `evaluate` (line 146)
- `scan` (line 296)
- `scan` (line 312)


### Doctrine/VersionedDoctrinePacks.swift

- **Lines**: 460
- **Public Types**: 6
- **Public Functions**: 12


**Public Types:**
- `protocol VersionedDoctrinePack` (line 16)
- `struct CSDoctrinePackV1` (line 49)
- `struct StatisticsDoctrinePackV1` (line 159)
- `struct LawComplianceDoctrinePackV1` (line 259)
- `struct DoctrineRule` (line 363)
- `enum RuleImplementation` (line 376)



**Public Functions:**
- `rule` (line 134)
- `canOverride` (line 138)
- `rule` (line 245)
- `canOverride` (line 249)
- `rule` (line 344)
- `canOverride` (line 348)
- `register` (line 420)
- `packs` (line 425)
- `pack` (line 430)
- `enabledPacks` (line 435)
- `canOverride` (line 440)
- `bootstrapDefaultPacks` (line 450)


### ExecutionCorePolicyEvaluator.swift

- **Lines**: 113
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `evaluatePhaseTransition` (line 24)


### HarmoniaModule.swift

- **Lines**: 352
- **Public Types**: 3
- **Public Functions**: 8


**Public Types:**
- `enum HarmoniaModuleVersion` (line 24)
- `enum HarmoniaModule` (line 42)
- `struct HarmoniaReasoningInfrastructure` (line 122)



**Public Functions:**
- `register` (static) (line 43)
- `createReasoningInfrastructure` (static) (line 86)
- `createBonkersInference` (static) (line 172)
- `createCCSFDSPSInference` (static) (line 180)
- `createRadicallyLegibleService` (static) (line 226)
- `createThemisOrchestrator` (static) (line 294)
- `createThemisOrchestrator` (static) (line 301)
- `createCCSFDSPSThemis` (static) (line 308)


### Harness/BanditConfigSelector.swift

- **Lines**: 226
- **Public Types**: 0
- **Public Functions**: 9




**Public Functions:**
- `selectConfig` (line 30)
- `getBestConfig` (line 46)
- `updateStats` (line 62)
- `getStats` (line 81)
- `resetStats` (line 97)
- `createEpilogueContext` (line 117)
- `updateFromReport` (line 141)
- `getPerformanceSummary` (line 162)
- `getRecommendations` (line 195)


### Harness/BanditPolicy.swift

- **Lines**: 304
- **Public Types**: 6
- **Public Functions**: 12


**Public Types:**
- `struct BanditArmStats` (line 11)
- `struct EpsilonGreedyPolicy` (line 31)
- `struct UCB1Policy` (line 119)
- `enum BanditPolicyFactory` (line 155)
- `struct BlessedConfig` (line 184)
- `enum BlessedConfigRegistry` (line 213)



**Public Functions:**
- `epsilon` (line 53)
- `selectArm` (line 69)
- `selectArm` (line 87)
- `selectArm` (line 93)
- `selectArm` (line 99)
- `selectArm` (line 129)
- `epsilonGreedy` (static) (line 157)
- `ucb1` (static) (line 170)
- `defaultPolicy` (static) (line 175)
- `configs` (static) (line 289)
- `configIds` (static) (line 296)
- `config` (static) (line 301)


### Harness/BanditTests.swift

- **Lines**: 345
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct BanditTests` (line 10)



**Public Functions:**
- `runAllTests` (static) (line 12)


### Harness/BehavioralHealthMetrics.swift

- **Lines**: 561
- **Public Types**: 3
- **Public Functions**: 5


**Public Types:**
- `struct GitDiffSummary` (line 12)
- `struct BehavioralHealthMetrics` (line 70)
- `enum Columns` (line 353)



**Public Functions:**
- `createTable` (static) (line 377)
- `computeBehavioralMetrics` (line 412)
- `saveBehavioralMetrics` (line 500)
- `getBehavioralMetrics` (line 509)
- `getHealthStatistics` (line 522)


### Harness/CodeQualityService.swift

- **Lines**: 281
- **Public Types**: 2
- **Public Functions**: 3


**Public Types:**
- `struct FormatterResults` (line 11)
- `struct LinterResults` (line 45)



**Public Functions:**
- `runFormatter` (line 86)
- `runLinter` (line 107)
- `withCodeQuality` (static) (line 259)


### Harness/GameProjectState.swift

- **Lines**: 390
- **Public Types**: 7
- **Public Functions**: 0


**Public Types:**
- `struct GamePlaytestOutcome` (line 10)
- `enum SceneTestStatus` (line 58)
- `struct SceneTest` (line 67)
- `struct GameTask` (line 116)
- `struct SceneSummary` (line 173)
- `struct GameProjectState` (line 249)
- `struct GameProjectPolicy` (line 351)




### Harness/GameStepIntent.swift

- **Lines**: 185
- **Public Types**: 4
- **Public Functions**: 2


**Public Types:**
- `enum GameStepIntent` (line 9)
- `protocol GameStepEngine` (line 33)
- `struct BasicGameStepEngine` (line 46)
- `enum GameStepEngineFactory` (line 173)



**Public Functions:**
- `chooseNextStep` (line 51)
- `create` (static) (line 177)


### Harness/GovernanceEventSinks.swift

- **Lines**: 200
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `enum EventVerbosity` (line 11)
- `struct GovernanceSummary` (line 138)



**Public Functions:**
- `emit` (line 32)
- `emit` (line 75)
- `getUserSummary` (line 85)
- `clear` (line 108)
- `emit` (line 123)


### Harness/GovernanceImplementations.swift

- **Lines**: 506
- **Public Types**: 2
- **Public Functions**: 20


**Public Types:**
- `struct BlessedPolicyRegistry` (line 15)
- `struct QuarantineStatus` (line 481)



**Public Functions:**
- `getConfigs` (line 18)
- `getConfigIds` (line 22)
- `getConfig` (line 26)
- `getAllCategories` (line 30)
- `getDefaultConfigs` (line 34)
- `getConfigs` (line 39)
- `normalizeConfigChoice` (line 57)
- `validateSessionPlan` (line 77)
- `selectConfig` (line 166)
- `recordOutcome` (line 193)
- `updateReward` (line 215)
- `evaluate` (line 254)
- `handleViolation` (line 296)
- `isProjectQuarantined` (line 317)
- `quarantineProject` (line 326)
- `releaseFromQuarantine` (line 345)
- `getQuarantineStatus` (line 362)
- `getQuarantineStatus` (line 366)
- `run` (line 393)
- `emit` (line 461)


### Harness/GovernanceProtocols.swift

- **Lines**: 337
- **Public Types**: 17
- **Public Functions**: 0


**Public Types:**
- `enum SessionTrustTier` (line 17)
- `struct SessionIntent` (line 24)
- `enum HarnessGovernanceDecision` (line 78)
- `enum GovernanceSeverity` (line 85)
- `struct GovernanceEvent` (line 92)
- `protocol PolicyRegistry` (line 118)
- `protocol Gatekeeper` (line 136)
- `protocol BanditGovernor` (line 146)
- `protocol SecurityEnforcer` (line 163)
- `protocol HarnessRunner` (line 184)
- `protocol GovernanceEventSink` (line 196)
- `enum PolicyDecision` (line 203)
- `enum SecurityOutcome` (line 211)
- `struct GovernanceFinding` (line 219)
- `enum SessionLane` (line 239)
- `struct GovernanceTrace` (line 252)
- `enum GovernanceError` (line 309)




### Harness/HarnessRegistration.swift

- **Lines**: 51
- **Public Types**: 1
- **Public Functions**: 3


**Public Types:**
- `enum HarnessRegistration` (line 9)



**Public Functions:**
- `registerSystems` (static) (line 11)
- `createTestWorld` (static) (line 21)
- `runTest` (static) (line 30)


### Harness/PrincipalityProjectController+Scouts.swift

- **Lines**: 581
- **Public Types**: 0
- **Public Functions**: 13




**Public Functions:**
- `runSwift6Scout` (line 19)
- `listPendingMigrationTasks` (line 33)
- `listMigrationTasks` (line 50)
- `listScoutFindings` (line 69)
- `runNextMigrationTask` (line 88)
- `runMigrationTask` (line 114)
- `runMigrationTasks` (line 177)
- `loadSwift6MigrationState` (line 200)
- `runSwift6Step` (line 277)
- `runSwift6Steps` (line 314)
- `loadGameProjectState` (line 430)
- `runGameStep` (line 469)
- `runGameSteps` (line 503)


### Harness/PrincipalityProjectController.swift

- **Lines**: 719
- **Public Types**: 4
- **Public Functions**: 19


**Public Types:**
- `struct ProjectStatusSummary` (line 526)
- `struct BanditStatsSummary` (line 563)
- `struct BanditCategoryStats` (line 572)
- `struct GovernanceStatus` (line 585)



**Public Functions:**
- `requireProject` (line 60)
- `runSession` (line 70)
- `getStatus` (line 213)
- `getGovernanceStatus` (line 255)
- `acknowledgeSession` (line 334)
- `acknowledgeAllUnhealthySessions` (line 349)
- `getBanditReport` (line 360)
- `listRecentSessions` (line 376)
- `recentSessionsStream` (line 395)
- `canListSessions` (line 432)
- `getSessionReports` (line 447)
- `getDeprecationRecommendations` (line 457)
- `getCriticalViolations` (line 464)
- `getWorstSession` (line 469)
- `getReportCard` (line 474)
- `forceReadLastReport` (line 479)
- `checkUnacknowledged` (line 484)
- `compareSessionsBrutally` (line 489)
- `bully` (line 499)


### Harness/PrincipalityProvider+SelfHost.swift

- **Lines**: 88
- **Public Types**: 0
- **Public Functions**: 6




**Public Functions:**
- `selfHostController` (line 11)
- `selfHostController` (line 17)
- `isSelfHostProject` (line 24)
- `getSelfHostProject` (line 29)
- `resolveProjectIdWithSelfHostDefault` (line 35)
- `controllerWithSelfHostDefault` (line 76)


### Harness/PrincipalityProvider.swift

- **Lines**: 347
- **Public Types**: 1
- **Public Functions**: 14


**Public Types:**
- `enum PrincipalityError` (line 323)



**Public Functions:**
- `controller` (line 31)
- `existingController` (line 64)
- `removeController` (line 71)
- `clearCache` (line 77)
- `cachedProjectIds` (line 83)
- `cacheCount` (line 89)
- `prewarmCache` (line 103)
- `controller` (line 137)
- `controller` (line 159)
- `resolveProjectId` (line 176)
- `controllerWithUserError` (line 236)
- `codingAgentSystem` (line 266)
- `initializerSystem` (line 284)
- `codingAgentService` (line 303)


### Harness/ProjectExecutionSurface.swift

- **Lines**: 161
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `protocol ProjectExecutionSurface` (line 13)
- `struct MakerStepContext` (line 78)



**Public Functions:**
- `runSession` (line 104)
- `runMakerStep` (line 122)


### Harness/ProjectHarnessModels.swift

- **Lines**: 1310
- **Public Types**: 14
- **Public Functions**: 35


**Public Types:**
- `enum ProjectStatus` (line 16)
- `enum FeatureTestStatus` (line 36)
- `struct ProjectSpec` (line 56)
- `enum Columns` (line 105)
- `struct FeatureBehavioralSnapshot` (line 380)
- `struct FeatureTestCase` (line 434)
- `enum Columns` (line 523)
- `struct ProjectProgressSnapshot` (line 584)
- `enum Columns` (line 633)
- `struct ConfigPolicyState` (line 806)
- `enum Columns` (line 856)
- `struct ToolUsageLog` (line 1140)
- `enum Columns` (line 1199)
- `enum HarnessError` (line 1291)



**Public Functions:**
- `createTable` (static) (line 116)
- `getBanditStats` (line 140)
- `updateBanditStats` (line 165)
- `getAllBanditStats` (line 202)
- `resetBanditStats` (line 218)
- `selectConfig` (line 245)
- `getBestConfig` (line 277)
- `getDeprecationCandidates` (line 305)
- `getPerformanceReport` (line 346)
- `createTable` (static) (line 542)
- `createTable` (static) (line 644)
- `getDBPool` (line 681)
- `initialize` (line 687)
- `createProjectSpec` (line 730)
- `saveProject` (line 740)
- `getProjectSpec` (line 745)
- `loadProject` (line 754)
- `updateProjectSpec` (line 760)
- `listProjectSpecs` (line 772)
- `loadAllProjects` (line 786)
- `createFeatureTestCases` (line 793)
- `createTable` (static) (line 866)
- `completeFeature` (line 887)
- `getFeatureBehavioralInsights` (line 933)
- `saveFeatures` (line 1057)
- `getFeatureTestCases` (line 1062)
- `loadFeatures` (line 1076)
- `updateFeatureTestCase` (line 1082)
- `saveFeature` (line 1094)
- `createProgressSnapshot` (line 1101)
- `getLatestProgressSnapshot` (line 1111)
- `getProgressSnapshots` (line 1123)
- `createTable` (static) (line 1212)
- `logToolUsage` (line 1237)
- `getToolUsageStats` (line 1246)


### Harness/ProjectHarnessStore+Scouts.swift

- **Lines**: 216
- **Public Types**: 0
- **Public Functions**: 14




**Public Functions:**
- `saveScoutFindings` (line 13)
- `listRecentSessions` (line 25)
- `getScoutFindings` (line 39)
- `getUnassignedScoutFindings` (line 67)
- `associateFindingWithTask` (line 83)
- `saveMigrationTasks` (line 101)
- `getMigrationTasks` (line 112)
- `getPendingMigrationTasks` (line 140)
- `updateMigrationTaskStatus` (line 154)
- `markMigrationTaskCompleted` (line 184)
- `markMigrationTaskFailed` (line 189)
- `getMigrationTask` (line 194)
- `scoutFindingNotFound` (static) (line 207)
- `migrationTaskNotFound` (static) (line 212)


### Harness/ProjectHarnessStoreExtensions.swift

- **Lines**: 253
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `updateFeatureBehavioralHistory` (line 13)
- `completeFeature` (line 59)
- `getFeatureBehavioralInsights` (line 105)
- `saveSessionReport` (line 233)
- `getSessionReports` (line 242)


### Harness/RudeCLICommands.swift

- **Lines**: 227
- **Public Types**: 1
- **Public Functions**: 11


**Public Types:**
- `struct RudeCLICommands` (line 15)



**Public Functions:**
- `bully` (line 41)
- `showWorstSession` (line 55)
- `checkUnacknowledged` (line 61)
- `showCriticalViolations` (line 77)
- `compareBrutally` (line 83)
- `generateReportCard` (line 96)
- `forceReadLastReport` (line 102)
- `showBanditReport` (line 108)
- `showDeprecationRecommendations` (line 124)
- `registerCommands` (static) (line 188)
- `helpText` (static) (line 207)


### Harness/ScoutModels.swift

- **Lines**: 244
- **Public Types**: 7
- **Public Functions**: 2


**Public Types:**
- `enum ScoutFindingSeverity` (line 12)
- `struct ScoutFinding` (line 30)
- `enum Columns` (line 94)
- `enum MigrationTaskStatus` (line 103)
- `struct MigrationTask` (line 112)
- `enum Columns` (line 171)
- `struct ScoutRunSummary` (line 180)



**Public Functions:**
- `createTable` (static) (line 205)
- `createTable` (static) (line 227)


### Harness/ScoutOrchestrator.swift

- **Lines**: 264
- **Public Types**: 2
- **Public Functions**: 10


**Public Types:**
- `protocol ProjectScout` (line 9)
- `enum ScoutError` (line 237)



**Public Functions:**
- `register` (line 35)
- `runScout` (line 45)
- `createMigrationTasks` (line 93)
- `nextPendingTasks` (line 136)
- `markTaskActive` (line 150)
- `markTaskCompleted` (line 158)
- `markTaskFailed` (line 166)
- `getTasks` (line 177)
- `getFindings` (line 198)
- `getUnassignedFindings` (line 217)


### Harness/SelfHostProjectConfig.swift

- **Lines**: 107
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `enum SelfHostProjectConfig` (line 10)



**Public Functions:**
- `ensureRegistered` (static) (line 66)
- `getPrincipality` (static) (line 102)


### Harness/SessionEpilogueRunner.swift

- **Lines**: 788
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `struct SessionEpilogueContext` (line 13)
- `struct SessionHealthSummary` (line 41)



**Public Functions:**
- `diffForSession` (line 87)
- `computeMetrics` (line 231)
- `runEpilogue` (line 301)
- `handlePostSession` (line 572)
- `acknowledgeSession` (line 642)
- `forceReadLastReport` (line 657)


### Harness/SessionReportGenerator.swift

- **Lines**: 771
- **Public Types**: 2
- **Public Functions**: 11


**Public Types:**
- `struct SessionReport` (line 13)
- `enum Columns` (line 625)



**Public Functions:**
- `generateReport` (line 257)
- `generateBatchReports` (line 475)
- `generateProjectSummary` (line 498)
- `exportReportsToMarkdown` (line 573)
- `createTable` (static) (line 639)
- `saveSessionReport` (line 673)
- `getSessionReports` (line 682)
- `acknowledgeSession` (line 695)
- `acknowledgeSessions` (line 719)
- `getUnacknowledgedSessions` (line 740)
- `getLatestUnacknowledgedUnhealthySession` (line 753)


### Harness/SimpleHarnessTest.swift

- **Lines**: 196
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct SimpleHarnessTest` (line 11)



**Public Functions:**
- `runTest` (static) (line 13)
- `testTools` (static) (line 121)


### Harness/SimpleTest.swift

- **Lines**: 91
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct SimpleComponentTest` (line 10)



**Public Functions:**
- `runTest` (static) (line 12)


### Harness/Swift6DiagnosticScout.swift

- **Lines**: 214
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct Swift6DiagnosticScout` (line 9)



**Public Functions:**
- `scan` (line 22)
- `selfHostScout` (static) (line 209)


### Harness/Swift6MigrationState.swift

- **Lines**: 213
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `struct Swift6SessionOutcome` (line 9)
- `struct Swift6FileSummary` (line 47)
- `struct Swift6MigrationState` (line 100)
- `struct Swift6MigrationPolicy` (line 174)




### Harness/Swift6StepEngine.swift

- **Lines**: 183
- **Public Types**: 4
- **Public Functions**: 2


**Public Types:**
- `enum Swift6StepIntent` (line 9)
- `protocol Swift6StepEngine` (line 33)
- `struct BasicSwift6StepEngine` (line 46)
- `enum Swift6StepEngineFactory` (line 171)



**Public Functions:**
- `chooseNextStep` (line 51)
- `create` (static) (line 175)


### Harness/Systems/ProjectCodingAgentSystem.swift

- **Lines**: 521
- **Public Types**: 7
- **Public Functions**: 3


**Public Types:**
- `struct ProjectCodingAgentSystem` (line 16)
- `struct CodingSandboxConfig` (line 345)
- `struct CodingContext` (line 388)
- `struct ToolExecutionResults` (line 422)
- `struct TestResults` (line 442)
- `struct CodingIterationResult` (line 465)
- `struct CodingSessionResult` (line 494)



**Public Functions:**
- `update` (line 38)
- `runCodingSession` (line 80)
- `buildPrompt` (line 399)


### Harness/Systems/ProjectInitializerSystem.swift

- **Lines**: 392
- **Public Types**: 6
- **Public Functions**: 4


**Public Types:**
- `struct ProjectInitializerSystem` (line 15)
- `struct ProjectSpecComponent` (line 55)
- `struct FeatureTestCaseComponent` (line 79)
- `struct ProjectInitializationConfig` (line 108)
- `struct ProjectInitializationResult` (line 137)
- `struct Logger` (line 383)



**Public Functions:**
- `update` (line 32)
- `initializeProject` (line 179)
- `info` (line 384)
- `error` (line 388)


### Harness/TestProjectExecutionSurface.swift

- **Lines**: 338
- **Public Types**: 0
- **Public Functions**: 13




**Public Functions:**
- `runSession` (line 88)
- `getStatus` (line 105)
- `getGovernanceStatus` (line 109)
- `listRecentSessions` (line 113)
- `acknowledgeSession` (line 117)
- `getBanditReport` (line 121)
- `getSessionReports` (line 125)
- `recentSessionsStream` (line 129)
- `canListSessions` (line 140)
- `setProjectStatus` (line 322)
- `setGovernanceStatus` (line 326)
- `getSessionCount` (line 330)
- `getAcknowledgedSessions` (line 334)


### Harness/ToolUsageInspector.swift

- **Lines**: 658
- **Public Types**: 5
- **Public Functions**: 5


**Public Types:**
- `struct BehavioralInvariants` (line 12)
- `struct InvariantViolation` (line 71)
- `enum ViolationType` (line 72)
- `struct ABComparisonResult` (line 563)
- `struct MetricComparison` (line 648)



**Public Functions:**
- `checkSessionInvariants` (line 124)
- `checkProjectInvariants` (line 211)
- `getHealthReport` (line 235)
- `exportBehavioralCSV` (line 295)
- `runABComparison` (line 316)


### Housekeeping/GarbageCollector.swift

- **Lines**: 338
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `struct GCReport` (line 305)
- `struct SessionCleanupReport` (line 325)
- `struct ArtifactCleanupReport` (line 332)



**Public Functions:**
- `runGC` (line 30)


### Inference/AdvancedArchitectures.swift

- **Lines**: 509
- **Public Types**: 10
- **Public Functions**: 6


**Public Types:**
- `enum AttentionArchitecture` (line 21)
- `enum GenerationMode` (line 45)
- `struct KVCacheProfile` (line 63)
- `struct QuantizationProfile` (line 125)
- `struct LongContextProfile` (line 168)
- `struct ArchitectureProfile` (line 202)
- `enum ArchitectureFeature` (line 270)
- `struct DiffusionLMProfile` (line 290)
- `enum DiffusionDomain` (line 332)
- `struct ArchitectureSchedulingHints` (line 387)



**Public Functions:**
- `getProfile` (line 358)
- `getDiffusionProfile` (line 363)
- `register` (line 368)
- `registeredFamilies` (line 379)
- `from` (static) (line 423)
- `architectureScore` (line 470)


### Inference/AgentBehaviorGovernance.swift

- **Lines**: 642
- **Public Types**: 12
- **Public Functions**: 15


**Public Types:**
- `enum AgentBehaviorFailure` (line 20)
- `enum BehaviorViolationSeverity` (line 41)
- `struct AgentBehaviorConstraints` (line 56)
- `struct AgentTurnState` (line 130)
- `struct ToolCallRecord` (line 178)
- `struct WriteOperationRecord` (line 197)
- `struct BehaviorViolation` (line 219)
- `enum ViolationAction` (line 243)
- `enum BehaviorCheckResult` (line 548)
- `struct AgentTurnSummary` (line 560)
- `struct BehaviorStatistics` (line 576)
- `struct GovernedInferenceContext` (line 600)



**Public Functions:**
- `hasExceededReasoningLimit` (line 160)
- `startTurn` (line 277)
- `endTurn` (line 284)
- `recordReasoning` (line 302)
- `recordToolCall` (line 334)
- `recordWrite` (line 383)
- `recordAnswer` (line 454)
- `acknowledgeUncertainty` (line 500)
- `setConstraints` (line 510)
- `statistics` (line 522)
- `pruneHistory` (line 538)
- `governedContext` (line 587)
- `recordReasoning` (line 606)
- `recordTool` (line 616)
- `recordWrite` (line 627)


### Inference/BonkersInferenceInfrastructure.swift

- **Lines**: 627
- **Public Types**: 12
- **Public Functions**: 8


**Public Types:**
- `struct BonkersInferenceConfig` (line 451)
- `struct InferenceSessionContext` (line 476)
- `struct BonkersSession` (line 484)
- `struct BonkersInferenceResult` (line 494)
- `struct InferenceProvenanceInfo` (line 507)
- `enum InfrastructureHealth` (line 515)
- `struct BonkersInferenceStatus` (line 524)
- `enum BonkersInferenceError` (line 533)
- `struct InfrastructureAdversarialReport` (line 543)
- `struct AdversarialIssue` (line 551)
- `enum AdversarialIssueSeverity` (line 559)
- `struct BonkersInferenceFactory` (line 569)



**Public Functions:**
- `runInference` (line 85)
- `startSession` (line 170)
- `endSession` (line 194)
- `getHealthStatus` (line 205)
- `getStatus` (line 210)
- `runAdversarialAnalysis` (line 225)
- `create` (static) (line 571)
- `createForCCSFDSPS` (static) (line 578)


### Inference/ClusterManager.swift

- **Lines**: 492
- **Public Types**: 9
- **Public Functions**: 16


**Public Types:**
- `struct NodeId` (line 15)
- `struct ComputeNode` (line 24)
- `struct NodeCapabilities` (line 60)
- `enum DataResidency` (line 92)
- `enum NodeStatus` (line 107)
- `struct NodeLoad` (line 116)
- `enum NodeSelectionPolicy` (line 387)
- `struct BatchDistribution` (line 395)
- `struct ClusterStatistics` (line 401)



**Public Functions:**
- `registerNode` (line 165)
- `updateNode` (line 173)
- `heartbeat` (line 192)
- `removeNode` (line 203)
- `allNodes` (line 210)
- `onlineNodes` (line 215)
- `selectNode` (line 222)
- `assignTask` (line 278)
- `completeTask` (line 290)
- `nodeForTask` (line 301)
- `distributeBatch` (line 308)
- `runHealthChecks` (line 337)
- `statistics` (line 360)
- `run` (line 435)
- `runBatch` (line 458)
- `clusterHealth` (line 488)


### Inference/DataFlowTransparency.swift

- **Lines**: 601
- **Public Types**: 12
- **Public Functions**: 18


**Public Types:**
- `struct DataFlowGraph` (line 15)
- `struct DataFlowNode` (line 43)
- `enum NodeType` (line 51)
- `enum Locality` (line 63)
- `enum SecurityLevel` (line 69)
- `struct DataFlowEdge` (line 103)
- `enum DataType` (line 111)
- `enum Transformation` (line 122)
- `struct DataFlowAnnotation` (line 153)
- `enum AnnotationType` (line 158)
- `struct DataFlowRenderer` (line 381)
- `struct TransparencyBundle` (line 580)



**Public Functions:**
- `hash` (line 95)
- `addNode` (line 192)
- `addEdge` (line 197)
- `annotate` (line 202)
- `build` (line 211)
- `recordInput` (line 223)
- `recordModelUsage` (line 236)
- `recordReasoning` (line 265)
- `recordOutput` (line 291)
- `recordTelemetry` (line 312)
- `recordLearning` (line 345)
- `renderASCII` (static) (line 384)
- `renderMermaid` (static) (line 460)
- `renderSummary` (static) (line 502)
- `beginTracking` (line 530)
- `completeTracking` (line 537)
- `getBuilder` (line 572)
- `renderFullReport` (line 586)


### Inference/DiffusionBackend.swift

- **Lines**: 549
- **Public Types**: 11
- **Public Functions**: 8


**Public Types:**
- `struct DiffusionInferenceConfig` (line 21)
- `struct DiffusionState` (line 111)
- `struct DiffusionReveal` (line 129)
- `struct DiffusionResult` (line 304)
- `struct DiffusionBackendStats` (line 320)
- `struct FIMConfig` (line 339)
- `struct FIMResult` (line 362)
- `struct OutputSchema` (line 396)
- `enum SchemaType` (line 413)
- `struct SchemaField` (line 421)
- `struct StructuredGenerationResult` (line 461)



**Public Functions:**
- `generate` (line 152)
- `getState` (line 220)
- `cancel` (line 225)
- `getStats` (line 230)
- `fillInMiddle` (line 371)
- `generateStructured` (line 435)
- `shouldUseDiffusion` (line 483)
- `runInference` (line 502)


### Inference/EnhancedInferenceScheduler.swift

- **Lines**: 655
- **Public Types**: 6
- **Public Functions**: 5


**Public Types:**
- `struct EnhancedSchedulingDecision` (line 21)
- `struct SchedulingContext` (line 387)
- `struct EnhancedSchedulingRecord` (line 407)
- `struct ArchitecturePerformanceMetrics` (line 422)
- `struct EnhancedSchedulerStatistics` (line 457)
- `struct IntegratedInferenceResult` (line 634)



**Public Functions:**
- `schedule` (line 106)
- `updateResources` (line 181)
- `recordPerformance` (line 186)
- `statistics` (line 360)
- `execute` (line 496)


### Inference/InferenceGovernance.swift

- **Lines**: 429
- **Public Types**: 4
- **Public Functions**: 10


**Public Types:**
- `struct InferencePolicy` (line 209)
- `struct InferenceValidationResult` (line 281)
- `enum InferenceGovernanceIssue` (line 288)
- `struct RateLimitResult` (line 338)



**Public Functions:**
- `setPolicy` (line 24)
- `getPolicy` (line 29)
- `validate` (line 36)
- `validateModel` (line 80)
- `validateNode` (line 117)
- `checkRateLimit` (line 156)
- `recordTokenUsage` (line 199)
- `strict` (static) (line 264)
- `run` (line 374)
- `setPolicy` (line 421)


### Inference/InferencePlaneInfrastructure.swift

- **Lines**: 552
- **Public Types**: 13
- **Public Functions**: 10


**Public Types:**
- `struct InferenceInfrastructureConfig` (line 21)
- `struct InferenceSession` (line 380)
- `struct InferenceSessionSummary` (line 393)
- `enum InfrastructureHealthStatus` (line 404)
- `enum ComponentHealthStatus` (line 412)
- `struct HealthCheckResult` (line 419)
- `struct InfrastructureHealthReport` (line 426)
- `struct PerformanceSnapshot` (line 433)
- `struct InfrastructureStatistics` (line 441)
- `struct InferencePlanePuzzleBuilder` (line 455)
- `struct AbstractInferenceTask` (line 505)
- `struct AbstractModel` (line 513)
- `struct InferenceRoutingPuzzle` (line 521)



**Public Functions:**
- `startSession` (line 187)
- `endSession` (line 205)
- `execute` (line 224)
- `getHealthStatus` (line 282)
- `runHealthCheck` (line 287)
- `getStatistics` (line 344)
- `setBehaviorConstraints` (line 364)
- `setTelemetryPolicy` (line 372)
- `buildRoutingPolicyPuzzle` (static) (line 457)
- `quickInference` (line 531)


### Inference/InferenceScheduler.swift

- **Lines**: 332
- **Public Types**: 5
- **Public Functions**: 12


**Public Types:**
- `enum SchedulingStrategy` (line 15)
- `struct SchedulingDecision` (line 30)
- `struct ResourceSnapshot` (line 52)
- `struct SchedulingRecord` (line 253)
- `struct SchedulerStatistics` (line 262)



**Public Functions:**
- `schedule` (line 104)
- `updateResources` (line 133)
- `currentResources` (line 138)
- `taskStarted` (line 145)
- `taskCompleted` (line 150)
- `activeTaskCount` (line 155)
- `statistics` (line 162)
- `execute` (line 274)
- `selectNode` (line 303)
- `updateLoad` (line 318)
- `taskStarted` (line 323)
- `taskCompleted` (line 328)


### Inference/InferenceService.swift

- **Lines**: 385
- **Public Types**: 4
- **Public Functions**: 11


**Public Types:**
- `struct BackendRequest` (line 315)
- `struct BackendParameters` (line 338)
- `struct BackendResponse` (line 361)
- `enum InferenceTelemetryEvent` (line 376)



**Public Functions:**
- `setTelemetryHandler` (line 33)
- `run` (line 40)
- `stream` (line 89)
- `complete` (line 125)
- `chat` (line 148)
- `embed` (line 171)
- `embedBatch` (line 197)
- `summarize` (line 220)
- `classify` (line 243)
- `listModels` (line 275)
- `registryStats` (line 282)


### Inference/InferenceTypes.swift

- **Lines**: 373
- **Public Types**: 20
- **Public Functions**: 0


**Public Types:**
- `enum InferenceTaskKind` (line 15)
- `enum QualityTier` (line 29)
- `enum CostTier` (line 43)
- `enum InferencePrivacyLevel` (line 56)
- `enum EnergyProfile` (line 64)
- `enum InferenceInput` (line 73)
- `struct ChatMessage` (line 81)
- `enum ChatRole` (line 94)
- `struct StructuredInput` (line 102)
- `struct InferenceConstraints` (line 115)
- `struct InferenceContext` (line 187)
- `struct InferenceTask` (line 212)
- `struct InferenceResult` (line 239)
- `enum InferenceOutput` (line 270)
- `struct InferenceToolCall` (line 280)
- `struct InferenceChunk` (line 293)
- `enum BackendKind` (line 310)
- `enum BackendStatus` (line 319)
- `enum ModelFormat` (line 329)
- `enum InferenceError` (line 339)




### Inference/InstitutionalLearningSystem.swift

- **Lines**: 755
- **Public Types**: 24
- **Public Functions**: 11


**Public Types:**
- `struct LearningCharter` (line 16)
- `struct LearningAuthoritativeSource` (line 70)
- `enum SourceType` (line 77)
- `struct LearningProhibition` (line 101)
- `enum Category` (line 107)
- `enum Severity` (line 116)
- `struct LearningApprover` (line 135)
- `enum ApprovalScope` (line 141)
- `struct LearningConfiguration` (line 163)
- `enum LearningMode` (line 174)
- `struct LearningBehavioralConstraints` (line 216)
- `enum AuditLevel` (line 223)
- `struct LearningTrace` (line 255)
- `struct TraceProvenance` (line 302)
- `enum InteractionClass` (line 309)
- `enum LearningContent` (line 331)
- `struct TraceAssessment` (line 338)
- `struct UserControl` (line 367)
- `enum TraceStatus` (line 395)
- `enum ComplianceResult` (line 479)
- `enum TraceSubmissionResult` (line 550)
- `struct LearningStats` (line 629)
- `struct LearningUPFTExtractor` (line 642)
- `struct CharterRenderer` (line 693)



**Public Functions:**
- `withConsent` (static) (line 390)
- `registerCharter` (line 417)
- `getCharter` (line 422)
- `checkCompliance` (line 427)
- `submitTrace` (line 491)
- `revokeTrace` (line 556)
- `getTraces` (line 587)
- `getStats` (line 606)
- `extractPrefix` (static) (line 645)
- `anonymize` (static) (line 669)
- `renderText` (static) (line 695)


### Inference/InstitutionalModelSystem.swift

- **Lines**: 848
- **Public Types**: 30
- **Public Functions**: 11


**Public Types:**
- `struct InstitutionalCharter` (line 23)
- `enum CharterDomain` (line 128)
- `struct AuthoritativeSource` (line 143)
- `enum SourceType` (line 150)
- `enum ProhibitedOptimization` (line 174)
- `enum ApproverRole` (line 186)
- `struct CharterBehaviorConstraints` (line 197)
- `struct EthicalGuardrails` (line 228)
- `struct CharterAuditRequirements` (line 264)
- `struct CharterAction` (line 289)
- `enum CharterValidationResult` (line 315)
- `enum CharterViolation` (line 326)
- `struct ModelProvenance` (line 338)
- `enum ProvenanceUpdateType` (line 366)
- `struct ProvenanceSource` (line 376)
- `enum ProvenanceSourceType` (line 399)
- `struct InstitutionalModelBundle` (line 411)
- `struct InstitutionalModelComponents` (line 457)
- `struct AdapterReference` (line 484)
- `struct ModelReference` (line 504)
- `struct SymbolicRule` (line 517)
- `enum DeploymentStatus` (line 540)
- `struct InstitutionalModelMetrics` (line 550)
- `struct ShadowComparison` (line 751)
- `struct ComparisonMetrics` (line 781)
- `enum PromotionDecision` (line 804)
- `struct LearningConsent` (line 812)
- `enum LearningScope` (line 829)
- `enum LearningRestriction` (line 836)
- `enum LearningSubmissionResult` (line 843)



**Public Functions:**
- `validate` (line 96)
- `check` (line 252)
- `registerCharter` (line 610)
- `getCharter` (line 615)
- `validateAction` (line 620)
- `registerBundle` (line 633)
- `getPrimaryBundle` (line 640)
- `getBundles` (line 645)
- `recordShadowComparison` (line 652)
- `evaluatePromotion` (line 677)
- `submitForLearning` (line 716)


### Inference/LearningImpactMeasurement.swift

- **Lines**: 648
- **Public Types**: 14
- **Public Functions**: 12


**Public Types:**
- `struct ReasoningTrace` (line 21)
- `enum TrainingDomain` (line 55)
- `struct TraceMetadata` (line 65)
- `enum TraceSourceType` (line 100)
- `struct TraceQuality` (line 108)
- `enum TraceQualityIssue` (line 150)
- `struct ImpactScore` (line 306)
- `struct LearningBenchmarkResults` (line 324)
- `struct CuratedTraceSet` (line 344)
- `struct UPFTConfig` (line 526)
- `struct ExtractedPrefix` (line 548)
- `struct PrefixStructure` (line 559)
- `enum PrefixElement` (line 569)
- `struct DomainTraceTemplates` (line 581)



**Public Functions:**
- `record` (line 182)
- `traces` (line 195)
- `scoreImpact` (line 202)
- `getImpactScore` (line 220)
- `selectHighImpactTraces` (line 225)
- `createCuratedSet` (line 249)
- `addToCuratedSet` (line 271)
- `getCuratedSet` (line 285)
- `configure` (line 372)
- `extractPrefix` (line 379)
- `extractConsensusPrefix` (line 410)
- `prefixes` (line 437)


### Inference/ModelIngestion.swift

- **Lines**: 598
- **Public Types**: 12
- **Public Functions**: 5


**Public Types:**
- `enum ModelSource` (line 15)
- `enum ConversionTarget` (line 30)
- `struct IngestionRequest` (line 40)
- `enum IngestionPriority` (line 66)
- `struct IngestionMetadata` (line 78)
- `struct IngestionResult` (line 103)
- `enum IngestionStatus` (line 118)
- `struct ValidationResult` (line 130)
- `struct ValidationCheck` (line 137)
- `struct BenchmarkResults` (line 144)
- `enum IngestionError` (line 152)
- `struct IngestionStatistics` (line 591)



**Public Functions:**
- `submit` (line 201)
- `status` (line 214)
- `result` (line 222)
- `cancel` (line 227)
- `statistics` (line 579)


### Inference/ModelRegistry.swift

- **Lines**: 514
- **Public Types**: 5
- **Public Functions**: 11


**Public Types:**
- `struct CapabilityProfile` (line 15)
- `struct ResourceProfile` (line 59)
- `enum DevicePreference` (line 96)
- `struct ModelDescriptor` (line 106)
- `struct RegistryStatistics` (line 508)



**Public Functions:**
- `hash` (line 155)
- `register` (line 180)
- `unregister` (line 185)
- `get` (line 190)
- `listAll` (line 195)
- `enableForTenant` (line 202)
- `disableForTenant` (line 213)
- `isAvailable` (line 220)
- `findCandidates` (line 236)
- `selectBest` (line 315)
- `statistics` (line 487)


### Inference/ProcessingReceipt.swift

- **Lines**: 863
- **Public Types**: 28
- **Public Functions**: 6


**Public Types:**
- `struct ProcessingReceipt` (line 16)
- `struct IngestionSummary` (line 86)
- `enum InputType` (line 93)
- `struct PipelineStage` (line 120)
- `enum StageCategory` (line 132)
- `enum StageStatus` (line 144)
- `struct EngineUsage` (line 183)
- `enum EngineType` (line 194)
- `struct DataLocalityReport` (line 232)
- `struct RemoteEndpointUsage` (line 239)
- `enum DataSentCategory` (line 245)
- `struct PersistenceReport` (line 285)
- `struct PersistedArtifact` (line 293)
- `enum ArtifactType` (line 299)
- `struct AppliedPolicyReport` (line 348)
- `enum BehaviorProfile` (line 355)
- `enum LearningMode` (line 362)
- `struct PolicyConstraintsSummary` (line 368)
- `struct BlockedAction` (line 418)
- `struct LearningEligibilityReport` (line 440)
- `struct EligibilityFactor` (line 447)
- `struct ReasoningExplanation` (line 484)
- `enum ReasoningTier` (line 492)
- `enum ConfidenceLevel` (line 500)
- `struct ReasoningStep` (line 507)
- `struct EvidenceSource` (line 529)
- `enum SourceType` (line 535)
- `struct ReceiptRenderer` (line 739)



**Public Functions:**
- `generateReceipt` (line 583)
- `getReceipt` (line 618)
- `getReceiptsForTask` (line 623)
- `renderText` (static) (line 742)
- `renderJSON` (static) (line 843)
- `renderSummary` (static) (line 852)


### Inference/RadicallyLegibleInfrastructure.swift

- **Lines**: 514
- **Public Types**: 6
- **Public Functions**: 10


**Public Types:**
- `struct TaskContext` (line 367)
- `struct TaskCompletionBundle` (line 380)
- `struct PresetLearningCharters` (line 389)
- `struct TransparencyDashboardData` (line 490)
- `struct CharterStatus` (line 497)
- `struct TaskSummary` (line 505)



**Public Functions:**
- `beginTask` (line 32)
- `recordModelUsage` (line 68)
- `recordReasoning` (line 88)
- `checkReasoningStep` (line 102)
- `recordReasoningStep` (line 111)
- `shouldTerminateEarly` (line 119)
- `completeTask` (line 127)
- `registerCharter` (line 319)
- `getCharter` (line 324)
- `generateReport` (line 331)


### Inference/RunnerManager.swift

- **Lines**: 348
- **Public Types**: 3
- **Public Functions**: 12


**Public Types:**
- `struct BackendInstanceId` (line 15)
- `struct BackendInstance` (line 28)
- `protocol BackendRunner` (line 265)



**Public Functions:**
- `registerRunner` (line 81)
- `ensureRunner` (line 88)
- `execute` (line 150)
- `stream` (line 181)
- `stopInstance` (line 207)
- `status` (line 221)
- `setLimits` (line 242)
- `start` (line 286)
- `stop` (line 292)
- `execute` (line 296)
- `stream` (line 322)
- `isAvailable` (line 344)


### Inference/SelfTuningArchitectureSelection.swift

- **Lines**: 667
- **Public Types**: 19
- **Public Functions**: 11


**Public Types:**
- `struct ArchitectureSelectionPolicy` (line 20)
- `enum SelectionDomain` (line 152)
- `enum ArchitectureFeatureKey` (line 162)
- `struct TaskRoutingRule` (line 173)
- `struct TaskPattern` (line 200)
- `struct RoutingConstraint` (line 228)
- `enum ConstraintType` (line 233)
- `struct PolicyScore` (line 269)
- `struct PolicyTrainingHistory` (line 277)
- `struct SelectionResult` (line 508)
- `struct SelectionObservation` (line 517)
- `struct PolicyStats` (line 553)
- `struct SelectionPolicyPuzzleBuilder` (line 566)
- `struct SelectionPolicyPuzzle` (line 606)
- `struct PolicyTestCase` (line 614)
- `struct ExpectedBehavior` (line 637)
- `enum ExpectedBehaviorType` (line 643)
- `struct PolicyPuzzleResult` (line 651)
- `struct FailedPolicyCase` (line 661)



**Public Functions:**
- `score` (line 70)
- `matches` (line 194)
- `matches` (line 218)
- `check` (line 247)
- `getPolicy` (line 336)
- `registerPolicy` (line 344)
- `selectModel` (line 353)
- `recordObservation` (line 401)
- `triggerLearning` (line 412)
- `getPolicyStats` (line 489)
- `build` (static) (line 568)


### Inference/SpeculativeExecution.swift

- **Lines**: 668
- **Public Types**: 14
- **Public Functions**: 3


**Public Types:**
- `enum ExecutionStrategy` (line 15)
- `struct SpeculativeConfig` (line 30)
- `struct CascadeConfig` (line 57)
- `enum CascadeTask` (line 79)
- `struct EnsembleConfig` (line 88)
- `enum EnsembleAggregation` (line 110)
- `struct SpeculativeResult` (line 290)
- `struct ExecutionPlan` (line 477)
- `struct ExecutionStep` (line 483)
- `enum StepType` (line 491)
- `struct StepResult` (line 500)
- `struct CascadeResult` (line 507)
- `struct ModelResult` (line 653)
- `struct EnsembleResult` (line 660)



**Public Functions:**
- `execute` (line 130)
- `execute` (line 312)
- `execute` (line 529)


### Inference/StructuredReasoningInference.swift

- **Lines**: 444
- **Public Types**: 6
- **Public Functions**: 9


**Public Types:**
- `enum StructuredTaskKind` (line 15)
- `struct StructuredReasoningInput` (line 39)
- `struct StructuredReasoningResult` (line 123)
- `struct StructuredReasoningModel` (line 160)
- `struct StructuredReasoningStatistics` (line 412)
- `enum StructuredReasoningError` (line 419)



**Public Functions:**
- `dspsWorkflow` (static) (line 58)
- `transcriptumIntegrity` (static) (line 80)
- `altMediaWorkflow` (static) (line 102)
- `register` (line 236)
- `findModel` (line 246)
- `allModels` (line 252)
- `setAuditLog` (line 278)
- `execute` (line 283)
- `getStatistics` (line 402)


### Inference/TestTimeComputeGovernance.swift

- **Lines**: 520
- **Public Types**: 12
- **Public Functions**: 11


**Public Types:**
- `struct ReasoningBudget` (line 15)
- `enum ReasoningStrategy` (line 23)
- `enum ReasoningTier` (line 31)
- `struct EarlyTerminationPolicy` (line 39)
- `struct StructuredReasoningTrace` (line 139)
- `struct ReasoningStep` (line 149)
- `enum ReasoningOutcome` (line 183)
- `struct ReasoningMetrics` (line 191)
- `struct BudgetViolation` (line 219)
- `enum ViolationType` (line 224)
- `enum ReasoningDecision` (line 377)
- `struct ReasoningTraceRenderer` (line 432)



**Public Functions:**
- `canProceed` (line 279)
- `recordStep` (line 316)
- `shouldTerminateEarly` (line 338)
- `hasMetMinimum` (line 346)
- `generateTrace` (line 351)
- `getBudget` (line 399)
- `setDomainBudget` (line 411)
- `setTenantOverride` (line 416)
- `listDomains` (line 424)
- `renderText` (static) (line 434)
- `renderSummary` (static) (line 501)


### Inference/ThemisInfrastructure.swift

- **Lines**: 911
- **Public Types**: 11
- **Public Functions**: 13


**Public Types:**
- `struct ThemisConfig` (line 628)
- `struct ThemisPreset` (line 653)
- `struct ThemisSessionContext` (line 742)
- `struct ThemisResult` (line 760)
- `struct LearningEligibility` (line 825)
- `enum ThemisHealth` (line 842)
- `struct ThemisStatus` (line 851)
- `enum ThemisError` (line 859)
- `struct ErisReport` (line 871)
- `struct ErisIssue` (line 879)
- `enum ErisSeverity` (line 887)



**Public Functions:**
- `create` (static) (line 133)
- `create` (static) (line 138)
- `startSession` (line 162)
- `endSession` (line 186)
- `runTask` (line 204)
- `registerCharter` (line 351)
- `getCharter` (line 356)
- `getHealth` (line 363)
- `getStatus` (line 368)
- `runAdversarialAnalysis` (line 382)
- `register` (line 606)
- `get` (line 612)
- `renderReport` (line 772)


### Inference/TriMemoryArchitecture.swift

- **Lines**: 796
- **Public Types**: 23
- **Public Functions**: 15


**Public Types:**
- `enum MemoryType` (line 19)
- `protocol MemoryItem` (line 31)
- `enum DataSensitivity` (line 41)
- `struct ShortTermMemory` (line 53)
- `enum ShortTermContentType` (line 120)
- `enum ShortTermSource` (line 130)
- `struct LongTermMemory` (line 141)
- `enum LongTermContentType` (line 225)
- `enum LongTermSource` (line 238)
- `enum RetentionReason` (line 250)
- `struct PersistentMemory` (line 263)
- `enum PersistentContentType` (line 328)
- `struct TriMemoryConfig` (line 589)
- `struct GovernanceDecision` (line 611)
- `struct ReleaseApproval` (line 629)
- `enum LongTermStoreResult` (line 642)
- `enum IntegrityCheckResult` (line 649)
- `struct MemoryAccessRecord` (line 656)
- `enum MemoryOperation` (line 665)
- `struct SubjectMemoryBundle` (line 675)
- `struct ContextPart` (line 767)
- `enum ContextPriority` (line 774)
- `struct BuiltMemoryContext` (line 782)



**Public Functions:**
- `storeShortTerm` (line 367)
- `getShortTerm` (line 376)
- `expireSession` (line 391)
- `cleanupExpiredShortTerm` (line 396)
- `storeLongTerm` (line 413)
- `getLongTerm` (line 430)
- `updateLongTerm` (line 450)
- `applyLegalHold` (line 486)
- `registerPersistent` (line 508)
- `getPersistent` (line 522)
- `verifyIntegrity` (line 529)
- `getAllMemoryForSubject` (line 542)
- `denied` (static) (line 623)
- `buildContext` (line 693)
- `render` (line 789)


### Integration/MakerIntegration.swift

- **Lines**: 21
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct MakerHarmoniaIntegration` (line 7)



**Public Functions:**
- `executeStep` (static) (line 8)


### ML/MLWorkerTypes.swift

- **Lines**: 22
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `enum MLWorkerError` (line 20)




### Models/ModelConcurrencyController.swift

- **Lines**: 353
- **Public Types**: 4
- **Public Functions**: 11


**Public Types:**
- `enum ModelKind` (line 16)
- `struct ConcurrencyLimits` (line 28)
- `struct ConcurrencyStats` (line 55)
- `enum ConcurrencyError` (line 340)



**Public Functions:**
- `limit` (line 43)
- `setLimit` (line 118)
- `setLimits` (line 125)
- `withSlot` (line 147)
- `tryWithSlot` (line 170)
- `withSlot` (line 197)
- `stats` (line 239)
- `hasAvailableSlot` (line 250)
- `inFlightCount` (line 257)
- `waitingCount` (line 262)
- `modelKinds` (line 266)


### Pipelines/PlaceholderPipelines.swift

- **Lines**: 54
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct CodeRefactorJobType` (line 22)
- `struct CodeRefactorWorkflow` (line 28)



**Public Functions:**
- `prepare` (line 35)
- `finalize` (line 42)


### Planning/PlanCompiler.swift

- **Lines**: 651
- **Public Types**: 14
- **Public Functions**: 3


**Public Types:**
- `struct PlanRequest` (line 364)
- `enum Priority` (line 370)
- `struct EvidenceRequirements` (line 379)
- `struct EvidenceValidation` (line 399)
- `struct RecentEvidence` (line 419)
- `struct EvidenceDependency` (line 433)
- `enum EvidenceType` (line 456)
- `struct EvidenceDigest` (line 465)
- `struct EvidenceProducedPlan` (line 485)
- `enum PlanStatus` (line 517)
- `enum PlanReason` (line 526)
- `struct ExecutionLease` (line 591)
- `struct ConflictResolution` (line 620)
- `enum ConflictStrategy` (line 637)



**Public Functions:**
- `generateEvidenceProducedPlan` (line 32)
- `allSatisfy` (line 424)
- `encode` (line 569)


### Reasoning/HarmoniaCICDGate.swift

- **Lines**: 559
- **Public Types**: 8
- **Public Functions**: 3


**Public Types:**
- `struct HarmoniaCICDGateResult` (line 22)
- `enum GateStatus` (line 49)
- `struct IndividualCheckResult` (line 76)
- `struct BlockingIssue` (line 93)
- `enum IssueSeverity` (line 101)
- `struct GateWarning` (line 124)
- `struct ChangeSet` (line 139)
- `struct CICDGateConfig` (line 516)



**Public Functions:**
- `configure` (line 217)
- `runGateCheck` (line 225)
- `getRecentResults` (line 350)


### Reasoning/HarmoniaPuzzleBuilders.swift

- **Lines**: 811
- **Public Types**: 17
- **Public Functions**: 6


**Public Types:**
- `enum HarmoniaReasoningDomain` (line 23)
- `struct ModuleIntegrationPuzzleBuilder` (line 57)
- `struct ModuleDependency` (line 60)
- `enum DependencyType` (line 65)
- `struct ArchitectureRule` (line 81)
- `struct WorkflowSafetyPuzzleBuilder` (line 269)
- `struct WorkflowStep` (line 272)
- `enum WorkflowRiskLevel` (line 279)
- `struct SafetyConstraint` (line 302)
- `struct RefactorSafetyPuzzleBuilder` (line 475)
- `struct RefactorOperation` (line 478)
- `enum OperationType` (line 485)
- `struct RefactorInvariant` (line 510)
- `struct ClusterOrchestrationPuzzleBuilder` (line 645)
- `struct ClusterNode` (line 648)
- `enum NodeType` (line 655)
- `struct Workload` (line 679)



**Public Functions:**
- `buildBoundaryViolationPuzzle` (static) (line 104)
- `buildSecuredWorldEnforcementPuzzle` (static) (line 192)
- `buildDangerousSequencePuzzle` (static) (line 325)
- `buildMacroLoopDetectionPuzzle` (static) (line 443)
- `buildRefactorSafetyPuzzle` (static) (line 523)
- `buildDataResidencyPuzzle` (static) (line 699)


### Reasoning/HarmoniaReasoningService.swift

- **Lines**: 531
- **Public Types**: 7
- **Public Functions**: 9


**Public Types:**
- `struct HarmoniaReasoningResult` (line 19)
- `enum OperationRiskLevel` (line 38)
- `struct HarmoniaRecommendation` (line 64)
- `enum RecommendationCategory` (line 71)
- `enum RecommendationPriority` (line 80)
- `struct HarmoniaReasoningConfig` (line 491)
- `struct HarmoniaReasoningStatistics` (line 525)



**Public Functions:**
- `configure` (line 128)
- `analyzeModuleIntegration` (line 136)
- `verifySecuredWorldEnforcement` (line 165)
- `analyzeWorkflowSafety` (line 189)
- `detectMacroLoops` (line 214)
- `analyzeRefactoringSafety` (line 234)
- `analyzeClusterScheduling` (line 260)
- `analyzeWithEnsemble` (line 286)
- `getStatistics` (line 342)


### Reasoning/HarmoniaScenarioLibrary.swift

- **Lines**: 427
- **Public Types**: 5
- **Public Functions**: 17


**Public Types:**
- `struct HarmoniaAdversarialScenario` (line 22)
- `enum ScenarioSeverity` (line 71)
- `enum ScenarioStatus` (line 78)
- `struct ScenarioLibraryStatistics` (line 409)
- `struct ScenarioTestFixture` (line 419)



**Public Functions:**
- `fromReasoningResult` (static) (line 124)
- `configure` (line 180)
- `add` (line 187)
- `get` (line 213)
- `updateStatus` (line 218)
- `linkToTask` (line 248)
- `linkToCodexPage` (line 255)
- `all` (line 264)
- `forDomain` (line 269)
- `forModule` (line 275)
- `withStatus` (line 281)
- `openScenarios` (line 287)
- `criticalOpenScenarios` (line 293)
- `search` (line 298)
- `statistics` (line 311)
- `exportAsTestFixtures` (line 335)
- `generateCodexContent` (line 349)


### Research/ResearchTaskValidator.swift

- **Lines**: 20
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `createMigrationTaskWithResearchValidation` (line 7)


### Retrieval/RetrievalEvidenceManager.swift

- **Lines**: 122
- **Public Types**: 0
- **Public Functions**: 3




**Public Functions:**
- `storeRetrievalEvidence` (line 22)
- `getRetrievalEvidence` (line 88)
- `replayRetrieval` (line 112)


### Retrieval/RetrievalLoopSignature.swift

- **Lines**: 17
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct RetrievalLoopSignature` (line 3)




### Retrieval/RetrievalService.swift

- **Lines**: 34
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `retrieve` (line 30)


### ScoutRegistry.swift

- **Lines**: 134
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `register` (line 34)
- `scout` (line 40)
- `allScoutIds` (line 44)
- `scoutDisplayName` (line 48)
- `persistScoutFindings` (static) (line 120)


### Security/BundleTemplate.swift

- **Lines**: 22
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct BundleTemplate` (line 5)




### Security/Canonicalizer.swift

- **Lines**: 174
- **Public Types**: 1
- **Public Functions**: 3


**Public Types:**
- `struct Canonicalizer` (line 10)



**Public Functions:**
- `canonicalJSON` (static) (line 13)
- `canonicalEvidenceHead` (static) (line 26)
- `canonicalBundleManifest` (static) (line 39)


### Security/EvidenceRedactionSystem.swift

- **Lines**: 608
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `redactBundle` (line 43)
- `redactDocumentContent` (line 114)
- `generatePrivilegeLog` (line 172)
- `verifyRedaction` (line 197)
- `generateTransparencyReport` (line 233)


### Security/EvidenceSigningSystem.swift

- **Lines**: 630
- **Public Types**: 0
- **Public Functions**: 6




**Public Functions:**
- `signEvidenceHead` (line 26)
- `signBundleManifest` (line 71)
- `verifyEvidenceAuthenticity` (line 110)
- `verifyBundleAuthenticity` (line 148)
- `rotateSigningKey` (line 186)
- `revokeKey` (line 217)


### Security/KeyCustodySystem.swift

- **Lines**: 891
- **Public Types**: 20
- **Public Functions**: 15


**Public Types:**
- `enum KeyType` (line 651)
- `enum KeyStatus` (line 668)
- `enum KeyAccessControl` (line 675)
- `struct KeyMetadata` (line 682)
- `struct HardwareBinding` (line 696)
- `struct HardwareAttestation` (line 703)
- `struct ProductionSignature` (line 716)
- `struct VerificationStep` (line 730)
- `struct VerificationResult` (line 737)
- `struct VerificationBundle` (line 745)
- `struct OfflineVerificationBundle` (line 752)
- `struct TimeRange` (line 763)
- `struct CertificateData` (line 768)
- `struct RevocationList` (line 777)
- `struct RevokedKey` (line 783)
- `enum KeyCustodyError` (line 792)
- `class SecureKeyStorage` (line 820)
- `protocol SecurePrivateKey` (line 855)
- `protocol SecurePublicKey` (line 859)
- `class HardwareAttestationService` (line 865)



**Public Functions:**
- `refreshCurrentKeyFingerprint` (line 25)
- `createProductionKey` (line 32)
- `signWithProductionKey` (line 96)
- `verifyProductionSignature` (line 156)
- `rotateProductionKey` (line 207)
- `revokeKey` (line 253)
- `createOfflineVerificationBundle` (line 295)
- `generateKey` (line 822)
- `sign` (line 831)
- `verify` (line 836)
- `getCurrentKeyFingerprint` (line 845)
- `deleteKey` (line 850)
- `attestToKeyCreation` (line 867)
- `attestToOperation` (line 876)
- `verifyAttestation` (line 886)


### Security/ThreatModel.swift

- **Lines**: 673
- **Public Types**: 11
- **Public Functions**: 7


**Public Types:**
- `enum ThreatActor` (line 19)
- `enum ThreatCapability` (line 83)
- `enum TrustZone` (line 104)
- `enum ZoneCapability` (line 159)
- `struct SecurityGoals` (line 178)
- `struct ThreatModel` (line 267)
- `enum AttackSurface` (line 403)
- `struct Mitigation` (line 435)
- `enum MitigationImplementation` (line 441)
- `enum ValidationResult` (line 542)
- `enum ThreatValidationResult` (line 622)



**Public Functions:**
- `doctrineRules` (line 219)
- `defaultMitigations` (static) (line 298)
- `isMitigationImplemented` (line 375)
- `securityPostureScore` (line 388)
- `canPerform` (line 477)
- `requiredDoctrineChecks` (line 518)
- `validateEngineTrust` (line 583)


### Security/TrustedTimestampingSystem.swift

- **Lines**: 771
- **Public Types**: 6
- **Public Functions**: 5


**Public Types:**
- `struct TimestampClaim` (line 621)
- `struct BundleTimestampClaim` (line 634)
- `struct TimeSourceClaim` (line 648)
- `struct TimestampVerificationResult` (line 696)
- `struct TemporalOrdering` (line 722)
- `enum TimestampingLevel` (line 751)



**Public Functions:**
- `timestampEvidenceHead` (line 26)
- `timestampBundleExport` (line 88)
- `verifyTimestampClaim` (line 153)
- `getTemporalOrdering` (line 198)
- `encode` (line 664)


### Session/SessionManager.swift

- **Lines**: 359
- **Public Types**: 3
- **Public Functions**: 8


**Public Types:**
- `struct SessionContext` (line 297)
- `struct SessionResult` (line 329)
- `enum SessionError` (line 340)



**Public Functions:**
- `createSession` (line 25)
- `getSession` (line 70)
- `getSessionDbPath` (line 78)
- `deleteSession` (line 83)
- `updateSessionStatus` (line 91)
- `mergeSession` (line 110)
- `terminateSession` (line 132)
- `getActiveSessions` (line 153)


### Storage/ArtifactStore.swift

- **Lines**: 266
- **Public Types**: 3
- **Public Functions**: 6


**Public Types:**
- `struct ArtifactInfo` (line 238)
- `struct EligibleArtifact` (line 249)
- `struct StorageStats` (line 259)



**Public Functions:**
- `storeArtifact` (line 25)
- `getArtifact` (line 79)
- `linkArtifact` (line 111)
- `getEligibleArtifacts` (line 129)
- `deleteArtifact` (line 170)
- `getStorageStats` (line 187)


### Systems/Aerodrome9Systems.swift

- **Lines**: 140
- **Public Types**: 9
- **Public Functions**: 8


**Public Types:**
- `struct InputSystem` (line 16)
- `struct MovementSystem` (line 30)
- `struct RenderingSystem` (line 44)
- `struct InteractionSystem` (line 58)
- `struct DialogueSystem` (line 72)
- `struct SceneResolutionSystem` (line 87)
- `struct PsychohistorySystem` (line 101)
- `struct UISystem` (line 115)
- `enum Aerodrome9Systems` (line 129)



**Public Functions:**
- `update` (line 21)
- `update` (line 35)
- `update` (line 49)
- `update` (line 63)
- `update` (line 77)
- `update` (line 92)
- `update` (line 106)
- `update` (line 120)


### Systems/AgentDatabaseTools.swift

- **Lines**: 504
- **Public Types**: 12
- **Public Functions**: 11


**Public Types:**
- `struct SemanticSearchResult` (line 364)
- `struct TextSearchResult` (line 370)
- `struct SearchResultItem` (line 375)
- `struct DocumentWithProvenance` (line 385)
- `struct ArtifactWithVerification` (line 391)
- `struct CoverageReport` (line 399)
- `struct RepoScanResult` (line 406)
- `struct DiagnosticSearchResult` (line 414)
- `struct RepoFile` (line 419)
- `struct DiagnosticResult` (line 431)
- `struct CustodyStep` (line 459)
- `enum AgentError` (line 476)



**Public Functions:**
- `semanticSearch` (line 19)
- `textSearch` (line 58)
- `getDocument` (line 91)
- `getArtifact` (line 108)
- `searchDiagnostics` (line 147)
- `getCoverageReport` (line 164)
- `repoScanFallback` (line 182)
- `requireEmbeddingsCoverage` (line 309)
- `requireFullTextCoverage` (line 317)
- `requireDiagnosticCoverage` (line 325)
- `logPolicyViolation` (line 341)


### Systems/BuildOutputIngestionPipeline.swift

- **Lines**: 646
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct BuildIngestionResult` (line 597)



**Public Functions:**
- `ingestBuild` (line 16)


### Systems/CathedralSchemas.swift

- **Lines**: 137
- **Public Types**: 4
- **Public Functions**: 0


**Public Types:**
- `enum EvidenceViolationSeverity` (line 97)
- `enum EvidenceViolationType` (line 104)
- `enum EnforcementActionType` (line 111)
- `enum EvidenceApprovalStatus` (line 117)




### Systems/DocumentUnitDatabase.swift

- **Lines**: 387
- **Public Types**: 3
- **Public Functions**: 7


**Public Types:**
- `struct DocumentUnit` (line 345)
- `struct VectorSearchResult` (line 367)
- `struct ContentSearchResult` (line 378)



**Public Functions:**
- `createDocumentUnit` (line 16)
- `getDocumentUnit` (line 52)
- `getOrCreateEmbeddingRecipe` (line 91)
- `storeEmbedding` (line 135)
- `searchEmbeddings` (line 162)
- `searchContent` (line 216)
- `query` (line 256)


### Systems/EmbeddingIngestionPipeline.swift

- **Lines**: 326
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct EmbeddingIngestionResult` (line 281)
- `enum EmbeddingIngestionError` (line 310)



**Public Functions:**
- `ingestDocument` (line 20)


### Systems/EvidenceSubstrate.swift

- **Lines**: 703
- **Public Types**: 9
- **Public Functions**: 5


**Public Types:**
- `enum MLOperationType` (line 526)
- `struct MLOperationResult` (line 534)
- `struct OperationEvidence` (line 545)
- `struct ForensicValidationResult` (line 571)
- `struct RetrievalValidationResult` (line 582)
- `struct EvidenceValidationResult` (line 602)
- `struct EvidenceCheckResult` (line 628)
- `struct EvidenceEnforcementResult` (line 647)
- `enum CathedralError` (line 655)



**Public Functions:**
- `performMLOperation` (line 47)
- `getOperationEvidence` (line 123)
- `validateOperationEvidence` (line 144)
- `enforceEvidenceSubstrate` (line 167)
- `generateLegalDiscoveryBundle` (line 247)


### Systems/ForensicMetadataTracker.swift

- **Lines**: 779
- **Public Types**: 9
- **Public Functions**: 5


**Public Types:**
- `enum ForensicFileType` (line 656)
- `enum ForensicAcquisitionMethod` (line 665)
- `enum ForensicTransformationType` (line 676)
- `enum ForensicTransmissionType` (line 689)
- `struct ForensicAcquisition` (line 698)
- `struct ForensicTransformation` (line 715)
- `struct ForensicTransmission` (line 730)
- `struct ForensicChain` (line 742)
- `struct ForensicChainSummary` (line 748)



**Public Functions:**
- `recordDocumentAcquisition` (line 18)
- `recordTransformation` (line 85)
- `recordTransmission` (line 136)
- `getForensicChain` (line 172)
- `generateChainSummary` (line 185)


### Systems/HarmoniaSystems.swift

- **Lines**: 450
- **Public Types**: 7
- **Public Functions**: 7


**Public Types:**
- `struct ConcurrencySyncSystem` (line 49)
- `struct MetricsAggregationSystem` (line 133)
- `struct HealthCheckSystem` (line 227)
- `struct ThroughputSamplingSystem` (line 301)
- `struct RequestCleanupSystem` (line 350)
- `struct SessionCleanupSystem` (line 372)
- `struct SlotTimeoutSystem` (line 395)



**Public Functions:**
- `update` (line 68)
- `update` (line 149)
- `update` (line 243)
- `update` (line 310)
- `update` (line 359)
- `update` (line 381)
- `update` (line 404)


### Systems/MLWorkerDispatchSystem.swift

- **Lines**: 83
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct MLWorkerDispatchSystem` (line 14)



**Public Functions:**
- `update` (line 23)


### Systems/PlaceholderSystems.swift

- **Lines**: 54
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct SlotManagementSystem` (line 25)



**Public Functions:**
- `update` (line 30)


### Systems/RetrievalExplainabilitySystem.swift

- **Lines**: 745
- **Public Types**: 9
- **Public Functions**: 5


**Public Types:**
- `struct QueryEmbeddingResult` (line 646)
- `struct RetrievalEvidence` (line 654)
- `struct RetrievalResultItem` (line 669)
- `struct RetrievalProvenance` (line 678)
- `struct ExplainableRetrievalResult` (line 686)
- `struct RetrievalAuditReport` (line 693)
- `struct ReproducibilityReport` (line 703)
- `struct ResultDifference` (line 714)
- `enum ResultDifferenceType` (line 720)



**Public Functions:**
- `explainableSemanticSearch` (line 27)
- `explainableTextSearch` (line 99)
- `getRetrievalEvidence` (line 164)
- `generateRetrievalAuditReport` (line 175)
- `verifyRetrievalReproducibility` (line 244)


### Systems/SecurityEngineStubs.swift

- **Lines**: 34
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct SecurityAwareMigrationEngineFactory` (line 8)
- `struct BlockedMigrationEngine` (line 23)



**Public Functions:**
- `engine` (line 16)
- `process` (line 30)


### Systems/SlotManagementSystem.swift

- **Lines**: 56
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct SlotManagementSystem` (line 15)



**Public Functions:**
- `update` (line 24)


### Systems/StepEngine.swift

- **Lines**: 257
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct StepEngine` (line 16)



**Public Functions:**
- `update` (line 29)


### Systems/TamperEvidenceSystem.swift

- **Lines**: 523
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `enum BundleExportFormat` (line 499)



**Public Functions:**
- `appendEvent` (line 23)
- `createBundle` (line 88)
- `exportBundle` (line 157)
- `verifyChain` (line 224)


### TestFiles/TestSendableIdempotence.swift

- **Lines**: 39
- **Public Types**: 0
- **Public Functions**: 0





### Tools/CodeIndexStore.swift

- **Lines**: 389
- **Public Types**: 4
- **Public Functions**: 8


**Public Types:**
- `struct CodeIndexConfig` (line 15)
- `struct CodeChunk` (line 40)
- `enum Columns` (line 101)
- `enum CodeIndexError` (line 374)



**Public Functions:**
- `encode` (line 127)
- `initialize` (line 154)
- `indexFile` (line 256)
- `searchChunks` (line 290)
- `getChunksForFile` (line 314)
- `deleteFileChunks` (line 331)
- `computeFileHash` (static) (line 346)
- `close` (line 366)


### Tools/EditTool.swift

- **Lines**: 315
- **Public Types**: 6
- **Public Functions**: 1


**Public Types:**
- `struct EditToolRequest` (line 13)
- `enum EditStrategy` (line 26)
- `struct EditToolResponse` (line 44)
- `struct FileChange` (line 67)
- `enum ChangeType` (line 90)
- `enum EditError` (line 291)



**Public Functions:**
- `performEdit` (line 101)


### Tools/EvidenceRecorder.swift

- **Lines**: 315
- **Public Types**: 3
- **Public Functions**: 7


**Public Types:**
- `struct EvidenceRecord` (line 223)
- `enum LegacyEvidenceStatus` (line 277)
- `struct EvidenceStats` (line 296)



**Public Functions:**
- `startToolCall` (line 24)
- `recordSuccess` (line 52)
- `recordFailure` (line 90)
- `getSessionEvidence` (line 159)
- `getSessionStats` (line 199)
- `totalCalls` (line 305)
- `successRate` (line 309)


### Tools/FileToolRuntime.swift

- **Lines**: 20
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct FileToolRuntime` (line 12)



**Public Functions:**
- `resolvePath` (static) (line 14)


### Tools/PolicyGate.swift

- **Lines**: 237
- **Public Types**: 3
- **Public Functions**: 3


**Public Types:**
- `enum Permission` (line 154)
- `enum SessionStatus` (line 201)
- `enum PolicyError` (line 210)



**Public Functions:**
- `validateToolCall` (line 34)
- `resetSessionUsage` (line 141)
- `getSessionUsage` (line 146)


### Tools/ReadTool.swift

- **Lines**: 163
- **Public Types**: 4
- **Public Functions**: 1


**Public Types:**
- `struct ReadToolRequest` (line 13)
- `struct ReadToolResponse` (line 26)
- `struct FilePermissions` (line 52)
- `enum ReadError` (line 135)



**Public Functions:**
- `readFile` (line 68)


### Tools/SimpleCodeAnalysisTool.swift

- **Lines**: 141
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `enum SimpleCodeAnalysisTool` (line 12)



**Public Functions:**
- `registerTools` (static) (line 125)


### Tools/SimpleToolBootstrap.swift

- **Lines**: 222
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct SimpleToolBootstrap` (line 145)
- `struct Config` (line 147)
- `enum Mode` (line 152)



**Public Functions:**
- `configure` (static) (line 165)
- `createMinimalRegistry` (static) (line 217)


### Tools/SimpleToolRegistry.swift

- **Lines**: 145
- **Public Types**: 7
- **Public Functions**: 8


**Public Types:**
- `protocol ToolHandlerProtocol` (line 12)
- `struct AnyToolHandler` (line 16)
- `struct ToolRequest` (line 32)
- `struct ToolResponse` (line 46)
- `enum SimpleToolError` (line 106)
- `enum SimpleToolResult` (line 113)
- `struct SimpleToolAdapter` (line 121)



**Public Functions:**
- `handle` (line 25)
- `success` (static) (line 57)
- `failure` (static) (line 61)
- `register` (line 75)
- `handler` (line 80)
- `execute` (line 85)
- `allToolNames` (line 94)
- `adapt` (static) (line 122)


### Tools/SwiftCodeChunker.swift

- **Lines**: 52
- **Public Types**: 2
- **Public Functions**: 2


**Public Types:**
- `struct SwiftCodeChunker` (line 13)
- `enum ChunkerError` (line 45)



**Public Functions:**
- `extractChunks` (static) (line 20)
- `computeFileHash` (static) (line 32)


### Tools/ToolCallLoopBreaker.swift

- **Lines**: 159
- **Public Types**: 3
- **Public Functions**: 5


**Public Types:**
- `struct LoopSignature` (line 26)
- `enum RecoveryStrategy` (line 35)
- `enum CallResult` (line 43)



**Public Functions:**
- `checkCall` (line 52)
- `checkCall` (line 70)
- `checkRetrievalCall` (line 100)
- `resetSession` (line 124)
- `clearAll` (line 130)


### Tools/ToolRouter.swift

- **Lines**: 72
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct ToolCallRequest` (line 18)
- `struct ToolCallResponse` (line 38)



**Public Functions:**
- `route` (line 65)


### Utilities/DatabaseInitializer.swift

- **Lines**: 634
- **Public Types**: 1
- **Public Functions**: 3


**Public Types:**
- `struct DatabaseInitializer` (line 14)



**Public Functions:**
- `initializeDatabase` (static) (line 21)
- `isDatabaseInitialized` (static) (line 583)
- `getDatabaseStats` (static) (line 601)


### Utilities/GitGuardRails.swift

- **Lines**: 133
- **Public Types**: 1
- **Public Functions**: 3


**Public Types:**
- `struct GitGuardRails` (line 13)



**Public Functions:**
- `checkRepositorySafety` (static) (line 18)
- `createBackupBranch` (static) (line 103)
- `getModifiedFiles` (static) (line 117)


### Utilities/MigrationCircuitBreaker.swift

- **Lines**: 124
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `enum CircuitBreakerState` (line 97)



**Public Functions:**
- `recordFailure` (line 30)
- `recordSuccess` (line 58)
- `reset` (line 70)
- `getState` (line 77)


### Utilities/MigrationTaskCreator.swift

- **Lines**: 154
- **Public Types**: 0
- **Public Functions**: 2




**Public Functions:**
- `createMigrationTask` (line 15)
- `createTasksForFindings` (line 117)


### Utilities/SQLiteHelpers.swift

- **Lines**: 179
- **Public Types**: 0
- **Public Functions**: 0





### Workers/WorkerSupervisor.swift

- **Lines**: 227
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `enum WorkerError` (line 11)



**Public Functions:**
- `dispatch` (line 25)


