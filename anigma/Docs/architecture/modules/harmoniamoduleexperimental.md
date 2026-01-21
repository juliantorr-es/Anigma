# HarmoniaModuleExperimental

## Overview

HarmoniaModuleExperimental is a Swift module in the Anigma ecosystem with **19258 lines of code** across **39 files**.

## Statistics

- **Public Types**: 129
- **Public Functions**: 244  
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
- `AnigmaASTServices`
- `AnigmaPrimitives`
- `DatabaseCore`

## File Structure


### Inspiration/InspirationCLI.swift

- **Lines**: 420
- **Public Types**: 2
- **Public Functions**: 9


**Public Types:**
- `struct InspirationCommands` (line 13)
- `struct InspirationCLI` (line 269)



**Public Functions:**
- `index` (line 31)
- `listRepos` (line 46)
- `listPatterns` (line 68)
- `runPipeline` (line 94)
- `listTasks` (line 114)
- `status` (line 134)
- `reindex` (line 157)
- `importGitHub` (line 173)
- `searchAndImport` (line 203)


### Inspiration/InspirationIndex.swift

- **Lines**: 556
- **Public Types**: 7
- **Public Functions**: 9


**Public Types:**
- `struct InspirationRepo` (line 14)
- `struct InspirationPattern` (line 46)
- `enum PatternKind` (line 58)
- `struct PatternProposal` (line 97)
- `enum ProposalType` (line 108)
- `enum Priority` (line 116)
- `enum ProposalStatus` (line 126)



**Public Functions:**
- `saveRepo` (line 240)
- `getRepo` (line 263)
- `getAllRepos` (line 270)
- `savePattern` (line 279)
- `getPatterns` (line 304)
- `getPatternsByKind` (line 320)
- `saveProposal` (line 329)
- `getPendingProposals` (line 351)
- `getProposals` (line 358)


### Inspiration/InspirationIndexService.swift

- **Lines**: 414
- **Public Types**: 0
- **Public Functions**: 8




**Public Functions:**
- `indexInspirationDirectory` (line 35)
- `indexRepository` (line 62)
- `runScouts` (line 107)
- `getAllRepos` (line 325)
- `getPatterns` (line 330)
- `getPatternsByKind` (line 335)
- `needsReindexing` (line 340)
- `reindexIfNeeded` (line 364)


### Inspiration/InspirationPipelineService.swift

- **Lines**: 311
- **Public Types**: 0
- **Public Functions**: 7




**Public Functions:**
- `runPipeline` (line 36)
- `getPendingTasks` (line 272)
- `getStatus` (line 277)
- `markTaskCompleted` (line 284)
- `markTaskFailed` (line 296)
- `getTask` (line 302)
- `getAllTasks` (line 307)


### Inspiration/InspirationPolicy.swift

- **Lines**: 314
- **Public Types**: 5
- **Public Functions**: 18


**Public Types:**
- `enum LicenseCompatibility` (line 14)
- `struct InspirationPolicy` (line 22)
- `enum AllowedUse` (line 31)
- `struct LicenseDetector` (line 58)
- `struct UsageRecord` (line 246)



**Public Functions:**
- `detectCompatibility` (static) (line 61)
- `allowedUses` (static) (line 85)
- `isSnippetWithinLimits` (static) (line 97)
- `appearsToBeDirectCopy` (static) (line 103)
- `canExtractPattern` (line 124)
- `canUseCodeSnippet` (line 136)
- `validateNotDirectCopy` (line 154)
- `isFilePathAllowed` (line 165)
- `generateAttribution` (line 188)
- `getPolicy` (line 207)
- `setPolicy` (line 211)
- `removePolicy` (line 215)
- `createDefaultPolicy` (line 220)
- `isUseAllowed` (line 234)
- `recordUsage` (line 258)
- `getUsageRecords` (line 276)
- `getAllUsageRecords` (line 280)
- `generateUsageReport` (line 285)


### Inspiration/InspirationScout.swift

- **Lines**: 425
- **Public Types**: 1
- **Public Functions**: 5


**Public Types:**
- `protocol InspirationScout` (line 16)



**Public Functions:**
- `absolutePath` (line 52)
- `searchInRepo` (line 57)
- `readFile` (line 76)
- `extractExampleSnippet` (line 88)
- `createASTFingerprint` (line 117)


### Inspiration/InspirationScoutRegistry.swift

- **Lines**: 196
- **Public Types**: 0
- **Public Functions**: 4




**Public Functions:**
- `register` (line 23)
- `getScouts` (line 27)
- `allScouts` (line 32)
- `scout` (line 37)


### Inspiration/InspirationStateStore.swift

- **Lines**: 508
- **Public Types**: 4
- **Public Functions**: 8


**Public Types:**
- `struct InspirationPipelineState` (line 13)
- `struct InspirationTask` (line 39)
- `enum TaskType` (line 52)
- `enum TaskStatus` (line 62)



**Public Functions:**
- `saveState` (line 188)
- `getState` (line 209)
- `updateState` (line 224)
- `saveTask` (line 247)
- `getTask` (line 274)
- `getTasks` (line 281)
- `getPendingTasks` (line 297)
- `updateTaskStatus` (line 301)


### Inspiration/WebClient.swift

- **Lines**: 563
- **Public Types**: 6
- **Public Functions**: 13


**Public Types:**
- `struct WebClientConfig` (line 13)
- `struct GitHubRepo` (line 36)
- `struct GitHubLicense` (line 52)
- `struct HuggingFaceModel` (line 100)
- `enum WebClientError` (line 135)
- `protocol WebClient` (line 146)



**Public Functions:**
- `fetch` (line 179)
- `fetchWithRetry` (line 204)
- `fetchRepo` (line 274)
- `searchRepos` (line 288)
- `fetchReadme` (line 320)
- `cloneToInspiration` (line 355)
- `fetchModel` (line 390)
- `searchModels` (line 402)
- `fetchModelCard` (line 422)
- `importGitHubRepo` (line 452)
- `searchAndImportRepos` (line 477)
- `indexHuggingFaceModel` (line 512)
- `searchAndIndexModels` (line 543)


### Research/DeepResearchEngine.swift

- **Lines**: 317
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct DeepResearchEngine` (line 14)



**Public Functions:**
- `extractStructuredNotes` (line 29)


### Research/ResearchAwareStepEngine.swift

- **Lines**: 428
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct ModuleCreationTaskInfo` (line 350)
- `struct ResearchEnforcementStats` (line 371)



**Public Functions:**
- `update` (line 33)
- `handleResearchCompletion` (line 301)
- `getStatistics` (line 330)
- `createIntegratedEngine` (static) (line 391)
- `registerResearchDoctrine` (static) (line 409)


### Research/ResearchBundle.swift

- **Lines**: 607
- **Public Types**: 11
- **Public Functions**: 4


**Public Types:**
- `struct ResearchBundle` (line 16)
- `struct TopicSpec` (line 85)
- `struct PaperMetadata` (line 156)
- `struct ResearchNote` (line 260)
- `enum NoteType` (line 301)
- `struct ProvenanceRecord` (line 317)
- `enum ResearchCompliance` (line 361)
- `struct ResearchTask` (line 385)
- `enum TaskStatus` (line 446)
- `enum TaskPriority` (line 455)
- `struct ResearchDebtTask` (line 466)



**Public Functions:**
- `generateQueries` (line 131)
- `allowsSource` (line 368)
- `generateDossier` (line 521)
- `generateCitation` (line 589)


### Research/ResearchClient.swift

- **Lines**: 889
- **Public Types**: 5
- **Public Functions**: 4


**Public Types:**
- `struct ResearchClientConfig` (line 15)
- `struct OpenAlexConfig` (line 57)
- `struct ArxivConfig` (line 79)
- `enum ResearchClientError` (line 103)
- `protocol ResearchClient` (line 121)



**Public Functions:**
- `isSourceAllowed` (line 165)
- `searchPapers` (line 255)
- `fetchPaper` (line 298)
- `conductResearch` (line 692)


### Research/ResearchDoctrinePack.swift

- **Lines**: 678
- **Public Types**: 6
- **Public Functions**: 9


**Public Types:**
- `struct ResearchDoctrinePack` (line 15)
- `struct ResearchDoctrineContext` (line 445)
- `struct ResearchAdequacyCalculator` (line 484)
- `struct ResearchAdequacyMetrics` (line 613)
- `struct ResearchRecommendation` (line 635)
- `enum Priority` (line 641)



**Public Functions:**
- `calculateAdequacyScore` (line 252)
- `generateDebtTasks` (line 309)
- `requiresResearch` (line 398)
- `adequacyThreshold` (line 421)
- `getValue` (line 452)
- `calculateMetrics` (line 492)
- `generateRecommendations` (line 557)
- `register` (static) (line 650)
- `checkAdequacy` (static) (line 656)


### Research/ResearchEnforcementDemo.swift

- **Lines**: 430
- **Public Types**: 0
- **Public Functions**: 6




**Public Functions:**
- `demoModuleWithoutResearch` (line 32)
- `demoModuleWithInadequateResearch` (line 97)
- `demoModuleWithAdequateResearch` (line 156)
- `demoStepEngineIntegration` (line 198)
- `runAllDemos` (line 384)
- `testResearchEnforcement` (line 415)


### Research/ResearchGate.swift

- **Lines**: 579
- **Public Types**: 9
- **Public Functions**: 11


**Public Types:**
- `enum ResearchCheckResult` (line 397)
- `struct ResearchBlockingResult` (line 413)
- `enum BlockingReason` (line 420)
- `struct ResearchStatus` (line 427)
- `struct BlockedModule` (line 456)
- `struct ResearchCompletionResult` (line 467)
- `protocol ModuleCreationTask` (line 478)
- `struct ModuleProposal` (line 495)
- `struct ResearchGateStatistics` (line 559)



**Public Functions:**
- `checkModuleProposal` (line 39)
- `checkResearchAdequacy` (line 100)
- `createResearchDebtTasks` (line 105)
- `blockModuleCreation` (line 111)
- `checkBeforeScheduling` (line 216)
- `scheduleResearchBeforeModuleCreation` (line 248)
- `getResearchStatus` (line 278)
- `getBlockedModules` (line 322)
- `handleResearchCompletion` (line 347)
- `registerWithSecuritySpine` (static) (line 533)
- `getStatistics` (line 541)


### Research/ResearchRegistry.swift

- **Lines**: 95
- **Public Types**: 1
- **Public Functions**: 10


**Public Types:**
- `struct ResearchRegistryStats` (line 82)



**Public Functions:**
- `getLatestAdequateBundle` (line 29)
- `getBundle` (line 33)
- `saveBundle` (line 37)
- `hasAdequateResearch` (line 41)
- `getPendingResearchTasks` (line 47)
- `getPendingResearchTasks` (line 51)
- `saveResearchTask` (line 55)
- `getUnresolvedDebtTasks` (line 61)
- `saveResearchDebtTask` (line 65)
- `getStatistics` (line 71)


### Research/ResearchSchema.swift

- **Lines**: 380
- **Public Types**: 7
- **Public Functions**: 8


**Public Types:**
- `enum ResearchSchema` (line 13)
- `enum ResearchBundlesColumns` (line 26)
- `enum PapersColumns` (line 38)
- `enum ResearchNotesColumns` (line 57)
- `enum ResearchTasksColumns` (line 69)
- `enum ResearchDebtTasksColumns` (line 83)
- `enum BundleLinksColumns` (line 95)



**Public Functions:**
- `createTablesSQL` (static) (line 106)
- `migrationSQL` (static) (line 266)
- `encodeJSON` (static) (line 278)
- `decodeJSON` (static) (line 285)
- `encodeStringArray` (static) (line 294)
- `decodeStringArray` (static) (line 298)
- `encodeStringDict` (static) (line 302)
- `decodeStringDict` (static) (line 306)


### Research/ResearchStatusCommand.swift

- **Lines**: 824
- **Public Types**: 2
- **Public Functions**: 4


**Public Types:**
- `struct ResearchCommands` (line 14)
- `struct ResearchCLI` (line 721)



**Public Functions:**
- `status` (line 22)
- `bundles` (line 96)
- `papers` (line 200)
- `debt` (line 309)


### Research/ResearchTaskValidator.swift

- **Lines**: 318
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct ResearchTaskValidator` (line 13)



**Public Functions:**
- `createMigrationTaskWithResearchValidation` (line 28)


### Security/BlockedMigrationEngine.swift

- **Lines**: 497
- **Public Types**: 4
- **Public Functions**: 5


**Public Types:**
- `struct BlockedMigrationEngine` (line 18)
- `struct CapabilityDebtTask` (line 162)
- `enum DebtTaskStatus` (line 197)
- `enum DebtTaskPriority` (line 205)



**Public Functions:**
- `process` (line 36)
- `getPendingDebtTasks` (line 232)
- `getDebtTasks` (line 260)
- `updateDebtTaskStatus` (line 290)
- `getDebtTaskStatistics` (line 348)


### Security/CICDGate.swift

- **Lines**: 762
- **Public Types**: 4
- **Public Functions**: 13


**Public Types:**
- `struct CICDGateConfig` (line 16)
- `struct CICDGateResult` (line 88)
- `struct GitHubStatusCheck` (line 439)
- `enum GitHubStatusState` (line 459)



**Public Functions:**
- `failed` (static) (line 116)
- `passed` (static) (line 125)
- `check` (line 152)
- `checkPR` (line 241)
- `createGitHubStatusCheck` (line 258)
- `createPRComment` (line 282)
- `createStatusCheck` (line 486)
- `createPRComment` (line 502)
- `getPRFiles` (line 512)
- `createPipelineStatus` (line 538)
- `runChecks` (line 571)
- `runPRChecks` (line 604)
- `runFromCLI` (static) (line 717)


### Security/Capability.swift

- **Lines**: 15
- **Public Types**: 0
- **Public Functions**: 0





### Security/CapabilityValidator.swift

- **Lines**: 508
- **Public Types**: 5
- **Public Functions**: 3


**Public Types:**
- `struct CapabilityContext` (line 18)
- `protocol CapabilityValidating` (line 40)
- `struct DumbCapabilityValidator` (line 71)
- `enum CapabilityError` (line 320)
- `struct TaskCapabilityAnalyzer` (line 346)



**Public Functions:**
- `validateGrant` (line 304)
- `analyze` (static) (line 348)
- `determineZone` (static) (line 396)


### Security/MetricsCollector.swift

- **Lines**: 721
- **Public Types**: 11
- **Public Functions**: 9


**Public Types:**
- `struct SecurityMetrics` (line 13)
- `struct ZoneMetrics` (line 96)
- `struct EngineMetrics` (line 116)
- `struct TrustMetrics` (line 137)
- `struct SecurityViolation` (line 157)
- `enum ViolationType` (line 195)
- `enum ViolationSeverity` (line 206)
- `enum TimePeriod` (line 219)
- `struct SecurityRecommendation` (line 634)
- `enum RecommendationType` (line 635)
- `protocol MetricsStore` (line 667)



**Public Functions:**
- `recordTask` (line 258)
- `recordViolation` (line 296)
- `recordCapabilityDebtTask` (line 329)
- `getMetrics` (line 357)
- `getCurrentMetrics` (line 403)
- `getMetricsTrend` (line 408)
- `getEffectivenessScore` (line 413)
- `getRecommendations` (line 419)
- `reset` (line 489)


### Security/ModeCommand.swift

- **Lines**: 506
- **Public Types**: 2
- **Public Functions**: 4


**Public Types:**
- `struct ModeCommands` (line 14)
- `struct ModeCLI` (line 421)



**Public Functions:**
- `status` (line 22)
- `set` (line 95)
- `history` (line 147)
- `compare` (line 220)


### Security/ProcessIsolation.swift

- **Lines**: 183
- **Public Types**: 0
- **Public Functions**: 2




**Public Functions:**
- `run` (line 26)
- `runSwiftCode` (line 117)


### Security/SecretVault.swift

- **Lines**: 749
- **Public Types**: 4
- **Public Functions**: 9


**Public Types:**
- `enum SecretType` (line 19)
- `struct SecretMetadata` (line 70)
- `struct AccessControlPolicy` (line 125)
- `enum SecretVaultError` (line 633)



**Public Functions:**
- `canAccess` (line 150)
- `store` (line 216)
- `retrieve` (line 265)
- `rotate` (line 333)
- `delete` (line 398)
- `listSecrets` (line 441)
- `getStatistics` (line 471)
- `logSecretOperation` (line 599)
- `scan` (line 675)


### Security/SecurityAwareMigrationEngineFactory.swift

- **Lines**: 390
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct SecurityAwareMigrationEngineFactory` (line 19)



**Public Functions:**
- `engine` (line 50)


### Security/SecurityPropertyTests.swift

- **Lines**: 844
- **Public Types**: 0
- **Public Functions**: 0





### Security/SecurityStatusCommand.swift

- **Lines**: 593
- **Public Types**: 2
- **Public Functions**: 4


**Public Types:**
- `struct SecurityCommands` (line 14)
- `struct SecurityCLI` (line 505)



**Public Functions:**
- `status` (line 22)
- `initialize` (line 93)
- `events` (line 108)
- `trust` (line 201)


### Security/SupplyChainPolicy.swift

- **Lines**: 827
- **Public Types**: 9
- **Public Functions**: 7


**Public Types:**
- `enum DependencyType` (line 18)
- `struct DependencyInfo` (line 48)
- `struct VulnerabilityInfo` (line 122)
- `enum VulnerabilitySeverity` (line 148)
- `struct SupplyChainPolicyConfig` (line 183)
- `struct DependencyScanResult` (line 544)
- `struct SupplyChainViolation` (line 637)
- `enum VulnerabilityScannerType` (line 728)
- `struct CICDCheckResult` (line 751)



**Public Functions:**
- `scan` (line 277)
- `checkDependencies` (line 321)
- `generateReport` (line 563)
- `scan` (line 670)
- `scan` (line 682)
- `runCICDCheck` (line 738)
- `runFromCLI` (static) (line 774)


### Security/ThreatModel.swift

- **Lines**: 629
- **Public Types**: 10
- **Public Functions**: 7


**Public Types:**
- `enum ThreatActor` (line 17)
- `enum ThreatCapability` (line 81)
- `enum TrustZone` (line 102)
- `enum ZoneCapability` (line 157)
- `struct SecurityGoals` (line 176)
- `struct ThreatModel` (line 265)
- `enum AttackSurface` (line 401)
- `struct Mitigation` (line 433)
- `enum MitigationImplementation` (line 439)
- `enum ThreatValidationResult` (line 578)



**Public Functions:**
- `doctrineRules` (line 217)
- `defaultMitigations` (static) (line 296)
- `isMitigationImplemented` (line 373)
- `securityPostureScore` (line 386)
- `canPerform` (line 475)
- `requiredDoctrineChecks` (line 516)
- `validateEngineTrust` (line 539)


### Security/TrustRecalcScheduler.swift

- **Lines**: 313
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `struct SchedulerStats` (line 271)



**Public Functions:**
- `start` (line 42)
- `stop` (line 68)
- `runRecalculation` (line 74)
- `getStats` (line 258)


### Security/TrustSchedulerBootstrapper.swift

- **Lines**: 171
- **Public Types**: 1
- **Public Functions**: 8


**Public Types:**
- `struct TrustSchedulerCLI` (line 87)



**Public Functions:**
- `startIfNeeded` (line 26)
- `stop` (line 42)
- `getStats` (line 50)
- `triggerRecalculation` (line 55)
- `status` (line 95)
- `start` (line 128)
- `stop` (line 144)
- `trigger` (line 155)


### Security/TrustScoreCalculator.swift

- **Lines**: 492
- **Public Types**: 0
- **Public Functions**: 3




**Public Functions:**
- `calculateScore` (line 52)
- `processCriticalEvent` (line 112)
- `recalculateAll` (line 171)


### Security/TrustScoreCommand.swift

- **Lines**: 923
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct TrustScoreCommands` (line 16)
- `struct TrustScoreCLI` (line 789)



**Public Functions:**
- `score` (line 24)
- `setScore` (line 130)
- `history` (line 235)
- `recalc` (line 334)
- `stats` (line 424)


### Security/TrustScoringConfig.swift

- **Lines**: 241
- **Public Types**: 3
- **Public Functions**: 7


**Public Types:**
- `enum TrustEventType` (line 16)
- `struct TrustScoringConfig` (line 32)
- `enum TrustScoringError` (line 218)



**Public Functions:**
- `scoreToTier` (line 47)
- `tierToScore` (line 58)
- `defaultScore` (line 79)
- `weight` (line 115)
- `decayFactor` (line 131)
- `modeAdjustment` (line 177)
- `validate` (line 188)


### Security/TrustTierManager.swift

- **Lines**: 642
- **Public Types**: 0
- **Public Functions**: 9




**Public Functions:**
- `getTrustScore` (line 34)
- `getEffectiveTrust` (line 42)
- `resolveEffectiveTrust` (line 64)
- `setTrustScore` (line 112)
- `setTrust` (line 180)
- `degradeTrust` (line 200)
- `promoteTrust` (line 238)
- `getTrustStates` (line 279)
- `getTrustStats` (line 345)


