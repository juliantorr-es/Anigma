# Dead Code Audit Report

Date: 2026-05-05 18:23:01Z
Command: `python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json`
Mode: gate

## Summary
- Swift files scanned: 2206
- Total declarations found: 100160
- Protected declarations: 19408
- Reachable declarations: 10967
- **Candidate dead declarations: 528**

## Stratification

### By Confidence
- high_confidence_candidate: 528

### By Source Category
- production: 426
- tests: 0
- app: 102
- scripts/generated: 0
- unknown: 0

### By Declaration Kind
- func: 416
- struct: 64
- let: 24
- var: 10
- enum: 7
- actor: 5
- class: 2

### By Module (Top 10)
- AnigmaAppMac: 80
- AnigmaDaemonCore: 37
- HarmoniaInference: 31
- AnigmaCLI: 22
- anigma: 20
- TurboQuantKVCache: 20
- MediaFingerprintCapsule: 18
- DocumentIRKit: 16
- IntelligenceContracts: 14
- AnigmaFoundation: 13

## High Confidence Candidates (Top 100)
| Symbol | Kind | Location | Ref Count |
|---|---|---|---|
| `ANEStats` | struct | `anigma/Packages/AnigmaStatusBar/Sources/AnigmaStatusBar/AnigmaStatusBarApp.swift:49` | 1 |
| `AccessibilityRequiredOverlay` | struct | `anigma/Sources/AnigmaAppMac/Services/AccessibilityService.swift:80` | 1 |
| `ActionConfirmationView` | struct | `anigma/App/MacApp/ActionConfirmationView.swift:3` | 2 |
| `ActionConfirmationView` | struct | `anigma/Sources/AnigmaAppMac/ActionConfirmationView.swift:3` | 2 |
| `AdvancedBenchmarkMain` | struct | `anigma/Tools/AdvancedLayoutBenchmark.swift:326` | 1 |
| `AnigmaArtifact` | struct | `anigma/Sources/AnigmaAppMac/Model/SpineObjects.swift:145` | 1 |
| `AnigmaDaemonApp` | struct | `anigma/Sources/AnigmaDaemonSimple/AnigmaDaemonSimpleApp.swift:1146` | 2 |
| `AnigmaDaemonApp` | struct | `anigma/Sources/anigmad/UI.swift:7` | 2 |
| `AnigmaProject` | struct | `anigma/Sources/AnigmaAppMac/Model/SpineObjects.swift:182` | 1 |
| `AnigmaStatusBarApp` | struct | `anigma/Packages/AnigmaStatusBar/Sources/AnigmaStatusBar/AnigmaStatusBarApp.swift:7` | 1 |
| `AnigmaTUIDemo` | struct | `anigma/Packages/AnigmaTUI/Sources/AnigmaTUIDemo/main.swift:5` | 1 |
| `AnigmaUIError` | enum | `anigma/App/MacApp/ErrorHandling.swift:7` | 2 |
| `AnigmaUIError` | enum | `anigma/Sources/AnigmaAppMac/ErrorHandling.swift:7` | 2 |
| `AssistantSourceChipView` | struct | `anigma/Sources/AnigmaAppMac/AssistantView.swift:813` | 1 |
| `BenchmarkCLI` | struct | `anigma/Anigma/Benchmarks/BenchmarkHarness/Sources/anigma-bench/main.swift:34` | 2 |
| `BenchmarkCLI` | struct | `anigma/Anigma/Benchmarks/BenchmarkHarness/Sources/anigma-capsule-bench/main.swift:131` | 2 |
| `BonkersInferenceFactory` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/BonkersInferenceInfrastructure.swift:574` | 1 |
| `CLIError` | struct | `anigma/Packages/AnigmaDaemon/CLI.swift:18` | 2 |
| `CLIError` | struct | `anigma/Packages/HarmoniaCLI/CLIUtilities.swift:10` | 2 |
| `CathedralSchemasError` | enum | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Systems/CathedralSchemas.swift:135` | 1 |
| `CharterRenderer` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/InstitutionalLearningSystem.swift:709` | 1 |
| `ChatError` | enum | `anigma/Packages/AnigmaCLI/Executable/ChatCommand.swift:230` | 1 |
| `CodeSymbol` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:155` | 1 |
| `CommandList` | struct | `anigma/Packages/HarmoniaCLI/CommandCommands/CommandCommand.swift:22` | 1 |
| `CompleteTrackingConfiguration` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/DataFlowTransparency.swift:526` | 1 |
| `ContextLensView` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/AtlasView.swift:83` | 1 |
| `DaemonControl` | struct | `anigma/Packages/AnigmaDaemonControl/main.swift:17` | 1 |
| `DefaultDoctrineClient` | struct | `anigma/Packages/AnigmaClientKit/Sources/AnigmaClientKit/AnigmaClientKit.swift:509` | 1 |
| `DemoMain` | struct | `anigma/Packages/Demo/main.swift:14` | 1 |
| `ErrorView` | struct | `anigma/App/MacApp/ErrorView.swift:3` | 2 |
| `ErrorView` | struct | `anigma/Sources/AnigmaAppMac/ErrorView.swift:3` | 2 |
| `ExampleClass` | class | `anigma/Sources/AnigmaAppMac/Components/TechDebtDashboardView.swift:551` | 1 |
| `FileAccessLogger` | actor | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:22` | 1 |
| `FileCachingManager` | actor | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:42` | 1 |
| `FileProviderExtensionLogic` | class | `anigma/Packages/AnigmaExtensions/FileProvider/FileProviderExtension.swift:20` | 1 |
| `FileSelectionSection` | struct | `anigma/Sources/AnigmaAppMac/Components/ModelSearchRow.swift:176` | 1 |
| `FileViewer` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/DevelopView.swift:696` | 1 |
| `GovernanceDetailsPanel` | struct | `anigma/App/MacApp/Components/GovernanceStrip.swift:147` | 2 |
| `GovernanceDetailsPanel` | struct | `anigma/Sources/AnigmaAppMac/Components/GovernanceStrip.swift:155` | 2 |
| `GovernanceSettings` | struct | `anigma/Sources/AnigmaAppMac/AnigmaRoles.swift:83` | 1 |
| `HarmoniaRootViewWithAssistant` | struct | `anigma/Sources/AnigmaAppMac/AssistantIntegrationExample.swift:13` | 1 |
| `HarnessCommand` | struct | `anigma/Packages/HarmoniaCLI/RealHarnessRunner.swift:13` | 1 |
| `LegacyDevelopView` | struct | `anigma/Sources/AnigmaAppMac/LegacyDevelopView.swift:10` | 1 |
| `LegacyHarnessRunCommand` | struct | `anigma/Packages/HarmoniaCLI/RealHarnessRunner.swift:73` | 1 |
| `MARKDOWN_RENDER_COMMONMARK` | let | `anigma/Anigma/Packages/MarkdownCapsule/Sources/MarkdownCapsule/MarkdownNativeBridge.swift:50` | 1 |
| `MARKDOWN_RENDER_HTML` | let | `anigma/Anigma/Packages/MarkdownCapsule/Sources/MarkdownCapsule/MarkdownNativeBridge.swift:47` | 1 |
| `MARKDOWN_RENDER_MAN` | let | `anigma/Anigma/Packages/MarkdownCapsule/Sources/MarkdownCapsule/MarkdownNativeBridge.swift:49` | 1 |
| `MARKDOWN_RENDER_PLAIN_TEXT` | let | `anigma/Anigma/Packages/MarkdownCapsule/Sources/MarkdownCapsule/MarkdownNativeBridge.swift:51` | 1 |
| `MARKDOWN_RENDER_XML` | let | `anigma/Anigma/Packages/MarkdownCapsule/Sources/MarkdownCapsule/MarkdownNativeBridge.swift:48` | 1 |
| `MediaFingerprintExample` | struct | `anigma/Packages/MediaFingerprintCapsule/Examples/MediaFingerprintExample.swift:6` | 1 |
| `MetalShaderManager` | actor | `anigma/Anigma/Packages/RendererKit/Sources/RendererKit/MetalRenderer.swift:234` | 2 |
| `MetalShaderManager` | actor | `anigma/Packages/RendererKit/Sources/RendererKit/MetalRenderer.swift:222` | 2 |
| `ModelHeaderCard` | struct | `anigma/Sources/AnigmaAppMac/Components/ModelSearchRow.swift:122` | 1 |
| `ModelRegistryCardView` | struct | `anigma/Sources/AnigmaAppMac/Components/ModelRegistryCard.swift:24` | 1 |
| `MonacoEditorView_Previews` | struct | `anigma/Packages/DevelopumModule/UI/MonacoEditorView.swift:311` | 1 |
| `OrchestrationPlanResponse` | struct | `anigma/Sources/AnigmaAppMac/Governance/LocalLLMOrchestrator.swift:510` | 1 |
| `PipelineStatusInfo` | struct | `anigma/Sources/AnigmaAppMac/AppStore.swift:53` | 1 |
| `PointerEvent` | struct | `anigma/RuntimeCore/Sources/KernelBridge.swift:448` | 1 |
| `PolicyPuzzleResult` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/SelfTuningArchitectureSelection.swift:677` | 1 |
| `PresetLearningCharters` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/RadicallyLegibleInfrastructure.swift:394` | 1 |
| `PrivilegedSurface` | enum | `anigma/App/MacApp/AnigmaRoles.swift:149` | 2 |
| `PrivilegedSurface` | enum | `anigma/Sources/AnigmaAppMac/AnigmaRoles.swift:212` | 2 |
| `ProcessingPolicy` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:62` | 1 |
| `ProcessingResult` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:73` | 1 |
| `ProcessingTask` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:94` | 1 |
| `ProjectLensView` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/AtlasView.swift:141` | 1 |
| `RadicallyLegibleService` | actor | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/RadicallyLegibleInfrastructure.swift:22` | 1 |
| `RedactionAuditTrailConfiguration` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:119` | 1 |
| `ScopedAccess` | struct | `anigma/App/MacApp/Services/BookmarkStore.swift:36` | 2 |
| `ScopedAccess` | struct | `anigma/Sources/AnigmaAppMac/Services/BookmarkStore.swift:36` | 2 |
| `SelectionPolicyPuzzleBuilder` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/SelfTuningArchitectureSelection.swift:592` | 1 |
| `SizeWarningCard` | struct | `anigma/Sources/AnigmaAppMac/Components/ModelSearchRow.swift:249` | 1 |
| `SourceIngestPayload` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/SourceConnectionWizard.swift:366` | 1 |
| `StatusDetailRow` | struct | `anigma/Sources/AnigmaAppMac/LauncherRootView.swift:787` | 1 |
| `StoreRetrievalEvidenceConfiguration` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaCore/Utils/UtilityTypes.swift:140` | 1 |
| `TechDebtAuditPayload` | struct | `anigma/Packages/HarmoniaCLI/TechDebtCommand.swift:106` | 1 |
| `TimelineLensView` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/AtlasView.swift:190` | 1 |
| `ToolDiscoverySheet` | struct | `anigma/Sources/AnigmaAppMac/Surfaces/OrchestratorView.swift:415` | 1 |
| `ToolErrorConfiguration` | struct | `anigma/Packages/HarmoniaMemory/Models/MemoryObservation.swift:276` | 1 |
| `ToolResultConfiguration` | struct | `anigma/Packages/HarmoniaMemory/Models/MemoryObservation.swift:248` | 1 |
| `TransparencyDashboardData` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/RadicallyLegibleInfrastructure.swift:495` | 1 |
| `VectorumOp` | enum | `anigma/Packages/VectorOpsKit/Sources/VectorOpsKit/VectorumMetalLane.swift:206` | 1 |
| `WorkspaceSnapshotEvent` | struct | `anigma/Packages/HarmoniaModule/Sources/HarmoniaSecurity/Governance/WorkspaceSnapshotCapture.swift:135` | 1 |
| `accentDark` | let | `anigma/App/MacApp/DesignSystem.swift:21` | 2 |
| `accentDark` | let | `anigma/Sources/AnigmaAppMac/DesignSystem.swift:21` | 2 |
| `acknowledgeAlert` | func | `anigma/Packages/ObservatoriumModule/Sources/ObservatoriumModule/Services/AlertService.swift:10` | 2 |
| `addBytes` | func | `anigma/Sources/MediaCore/Governance/MediaMemoryAuthority.swift:172` | 1 |
| `addDependency` | func | `anigma/Packages/ContractsCore/Sources/IntelligenceContracts/ArtifactRegistry.swift:489` | 1 |
| `addHost` | func | `anigma/App/MacApp/AppStore.swift:1162` | 1 |
| `addLocalModel` | func | `anigma/Sources/AnigmaCLI/CLI/CLIConfiguration.swift:125` | 1 |
| `addNotificationChannel` | func | `anigma/Packages/ObservatoriumModule/Sources/ObservatoriumModule/Services/AlertService.swift:13` | 2 |
| `addRunStep` | func | `anigma/Sources/AnigmaCLI/CLI/CLIDatabase.swift:301` | 1 |
| `afterExecute` | func | `anigma/Packages/AnigmaPrimitives/ToolContracts/ModernTool.swift:121` | 1 |
| `alertManagementWorkflow` | func | `anigma/Packages/HarmoniaModule/Sources/HarmoniaServices/Adapters/USAGE_EXAMPLES.swift:205` | 1 |
| `allKits` | func | `anigma/Packages/PolytroposModule/Music/MusicGenerationService.swift:406` | 2 |
| `allKits` | func | `anigma/Packages/PolytroposModule/Sources/PolytroposModule/Music/MusicGenerationService.swift:406` | 2 |
| `allProfiles` | func | `anigma/Packages/PolytroposModule/Music/MusicGenerationService.swift:399` | 7 |
| `allProfiles` | func | `anigma/Packages/PolytroposModule/Sources/PolytroposModule/Music/MusicGenerationService.swift:399` | 7 |
| `allowedValueKind` | func | `anigma/Packages/ContractsCore/Sources/GovernanceContracts/SecurityCore.swift:123` | 1 |
| `aneCapsuleDescriptor` | let | `anigma/Packages/HarmoniaModule/Sources/HarmoniaInference/Inference/CoreMLEmbeddingComputer.swift:77` | 1 |

... and 428 more high confidence candidates.

--- 
*Note: This report is advisory. Candidates should be reviewed by a human before removal. Reference counts are textual upper bounds (strings and comments may inflate reachability).*