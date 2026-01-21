# PolytroposModule

## Overview

PolytroposModule is a Swift module in the Anigma ecosystem with **18187 lines of code** across **36 files**.

## Statistics

- **Public Types**: 417
- **Public Functions**: 187  
- **Components**: 122
- **Systems**: 13
- **Services**: 32

## Architecture

### Components
- `AudioAnalysisComponent`
- `TimeRange`
- `AudioSegment`
- `AudioSegmentType`
- `ContentSegment`
- `ContentType`
- `AudioQualityAssessment`
- `VideoAnalysisComponent`
- `FrameAnalysis`
- `NormalizedRect`
- `FrameSceneType`
- `SubjectDetection`
- `SubjectType`
- `VideoQualityAssessment`
- `SceneBoundaryComponent`
- `SceneBoundary`
- `SceneBoundaryType`
- `BrandingProfileComponent`
- `WatermarkPosition`
- `SocialPlatform`
- `LowerThirdConfig`
- `LowerThirdStyle`
- `LowerThirdAnimation`
- `IntroOutroConfig`
- `CardType`
- `BackgroundStyle`
- `CaptionStyleComponent`
- `CaptionStyle`
- `ExportPresetComponent`
- `ExportPlatform`
- `ExportResolution`
- `VideoCodec`
- `AudioCodec`
- `CaptionFormat`
- `ColorSpace`
- `ExportJobComponent`
- `ExportJobStatus`
- `ReframeInstructionsComponent`
- `ReframeKeyframe`
- `ReframeEasing`
- `AutoReframeMode`
- `SystemExportPresets`
- `MLModelConsentComponent`
- `MLModelType`
- `ConsentState`
- `PrivacyPreferences`
- `NetworkPermissions`
- `AnonymizationLevel`
- `ApprovalRecord`
- `ApprovalMethod`
- `ModelPackRegistryComponent`
- `ModelInstallationRecordComponent`
- `ConsentFlowUIComponent`
- `ModelDownloadInfo`
- `AuthMethod`
- `InstallationStatus`
- `ModelVerification`
- `VerificationResult`
- `ResourceRequirements`
- `OSRequirements`
- `ModelPackMetadata`
- `InstallationAttempt`
- `InstallationState`
- `ApprovalStatus`
- `ModelHealthStatus`
- `ConsentFlowStep`
- `InteractionState`
- `UserAction`
- `UIPreferences`
- `FlowContext`
- `FlowUrgency`
- `MediaAssetComponent`
- `MediaType`
- `MediaAssetStatus`
- `TemporalMetadataComponent`
- `VideoMetadataComponent`
- `AudioMetadataComponent`
- `DeviceMetadataComponent`
- `WaveformComponent`
- `ThumbnailComponent`
- `MulticamClusterComponent`
- `ClusterStatus`
- `SyncDataComponent`
- `SyncMethod`
- `CameraClassificationComponent`
- `CameraAngleType`
- `SubjectCoverage`
- `StabilityRating`
- `SyncMarkerComponent`
- `SyncMarker`
- `SyncMarkerType`
- `PolytroposProjectId`
- `ProjectComponent`
- `ProjectStatus`
- `ProjectReferencesComponent`
- `EventMetadataComponent`
- `EventType`
- `EditProfileHints`
- `CutDensity`
- `TimelineComponent`
- `TimelineStatus`
- `AspectRatio`
- `TimelineTracksComponent`
- `ClipSegment`
- `OverlaySegment`
- `OverlayType`
- `OverlayContent`
- `OverlayAnimation`
- `TransitionDefinition`
- `TransitionType`
- `SceneComponent`
- `PolytroposSceneType`
- `SceneStatus`
- `TranscriptComponent`
- `TranscriptSegment`
- `TranscriptWord`
- `CaptionTrackComponent`
- `CaptionEntry`
- `WordTiming`
- `SpeakerDiarizationComponent`
- `SpeakerInfo`
- `SpeakerSegment`

### Systems
- `MLModelProvisioningSystem`
- `DownloadStatus`
- `DownloadResult`
- `NetworkBlocker`
- `MediaIngestSystem`
- `AudioSyncSystem`
- `AudioAnalysisSystem`
- `VideoAnalysisSystem`
- `AutoEditSystem`
- `CaptionSystem`
- `BrandingSystem`
- `ReframeSystem`
- `ExportSystem`

### Services
- `PolytroposHarmoniaJobs`
- `IngestJob`
- `SyncJob`
- `AudioAnalysisJob`
- `VideoAnalysisJob`
- `AutoEditJob`
- `CaptionJob`
- `ExportJob`
- `EditProfileOverridesDTO`
- `ProxyQuality`
- `PolytroposJobResult`
- `IngestResult`
- `SyncResultDTO`
- `AudioAnalysisResultDTO`
- `VideoAnalysisResultDTO`
- `AutoEditResultDTO`
- `CaptionResultDTO`
- `ExportResultDTO`
- `JobPriority`
- `HarmoniaJobStatus`
- `PolytroposHarmoniaError`
- `PolytroposWorkerInfo`
- `WorkerCapabilities`
- `WorkerLoad`
- `PolytroposError`
- `AutoEditError`
- `ExportError`
- `ExportReport`
- `Configuration`
- `SyncResult`
- `AssetSyncResult`
- `SyncError`

## Dependencies

- `AnigmaCore`

## File Structure


### Backend/BackendProtocol.swift

- **Lines**: 444
- **Public Types**: 17
- **Public Functions**: 6


**Public Types:**
- `protocol RendererBackend` (line 16)
- `struct RendererBackendId` (line 50)
- `struct RendererCapabilities` (line 63)
- `enum BackendVideoCodec` (line 122)
- `enum BackendAudioCodec` (line 137)
- `enum ContainerFormat` (line 149)
- `struct BackendResolution` (line 161)
- `struct MediaAssetInfo` (line 179)
- `struct RenderProgress` (line 216)
- `enum RenderPhase` (line 245)
- `struct RenderResult` (line 259)
- `struct RenderWarning` (line 291)
- `struct RenderError` (line 304)
- `enum PreviewBackendResolution` (line 319)
- `struct PreviewFrame` (line 326)
- `enum PixelFormat` (line 349)
- `enum BackendRequirement` (line 438)



**Public Functions:**
- `register` (line 372)
- `backend` (line 377)
- `defaultBackend` (line 382)
- `setDefaultBackend` (line 387)
- `allBackends` (line 394)
- `bestBackend` (line 399)


### Backend/FFmpegUtils.swift

- **Lines**: 721
- **Public Types**: 7
- **Public Functions**: 10


**Public Types:**
- `struct FFmpegResult` (line 484)
- `enum FFmpegError` (line 493)
- `struct TranscodeSettings` (line 500)
- `struct MediaProbeResult` (line 529)
- `struct FormatInfo` (line 533)
- `struct StreamInfo` (line 542)
- `struct FFmpegConcatBuilder` (line 651)



**Public Functions:**
- `isAvailable` (line 51)
- `render` (line 87)
- `cancelRender` (line 214)
- `generatePreview` (line 221)
- `run` (line 336)
- `probe` (line 371)
- `transcode` (line 403)
- `generateProxy` (line 572)
- `buildConcatFile` (static) (line 654)
- `buildFilterGraph` (static) (line 670)


### Backend/MLTBridge.swift

- **Lines**: 521
- **Public Types**: 6
- **Public Functions**: 14


**Public Types:**
- `struct MLTProjectAdapter` (line 224)
- `struct MLTImportResult` (line 330)
- `struct MLTClipAdapter` (line 339)
- `struct MLTFilterAdapter` (line 375)
- `struct EDLAdapter` (line 455)
- `struct FCPXMLAdapter` (line 504)



**Public Functions:**
- `isAvailable` (line 47)
- `render` (line 73)
- `cancelRender` (line 188)
- `generatePreview` (line 195)
- `convert` (static) (line 227)
- `parse` (static) (line 299)
- `toProducer` (static) (line 342)
- `fromProducer` (static) (line 359)
- `colorGradeToFilter` (static) (line 378)
- `audioProcessingToFilter` (static) (line 387)
- `exportToMLT` (line 429)
- `importFromMLT` (line 444)
- `exportCMX3600` (static) (line 458)
- `export` (static) (line 507)


### Backend/ProjectInterchange.swift

- **Lines**: 758
- **Public Types**: 11
- **Public Functions**: 8


**Public Types:**
- `protocol ProjectInterchangeFormat` (line 15)
- `struct InterchangeFormatId` (line 37)
- `struct ProjectMetadata` (line 52)
- `struct InterchangeImportResult` (line 81)
- `struct ImportedAssetInfo` (line 111)
- `struct ImportWarning` (line 134)
- `struct ImportError` (line 147)
- `struct MLTXMLFormat` (line 162)
- `struct EDLFormat` (line 336)
- `struct FCPXMLFormat` (line 486)
- `struct OTIOFormat` (line 595)



**Public Functions:**
- `export` (static) (line 167)
- `export` (static) (line 341)
- `export` (static) (line 491)
- `export` (static) (line 600)
- `availableFormats` (line 691)
- `export` (line 696)
- `importProject` (line 712)
- `resolveAssets` (line 727)


### Compatibility/LegacyTypes.swift

- **Lines**: 22
- **Public Types**: 0
- **Public Functions**: 0





### Components/AnalysisComponents.swift

- **Lines**: 397
- **Public Types**: 17
- **Public Functions**: 2


**Public Types:**
- `struct AudioAnalysisComponent` (line 14)
- `struct TimeRange` (line 61)
- `struct AudioSegment` (line 84)
- `enum AudioSegmentType` (line 104)
- `struct ContentSegment` (line 122)
- `enum ContentType` (line 135)
- `struct AudioQualityAssessment` (line 145)
- `struct VideoAnalysisComponent` (line 170)
- `struct FrameAnalysis` (line 202)
- `struct NormalizedRect` (line 270)
- `enum FrameSceneType` (line 288)
- `struct SubjectDetection` (line 300)
- `enum SubjectType` (line 323)
- `struct VideoQualityAssessment` (line 333)
- `struct SceneBoundaryComponent` (line 358)
- `struct SceneBoundary` (line 368)
- `enum SceneBoundaryType` (line 388)



**Public Functions:**
- `contains` (line 74)
- `overlaps` (line 78)


### Components/BrandingComponents.swift

- **Lines**: 335
- **Public Types**: 11
- **Public Functions**: 0


**Public Types:**
- `struct BrandingProfileComponent` (line 14)
- `enum WatermarkPosition` (line 106)
- `enum SocialPlatform` (line 116)
- `struct LowerThirdConfig` (line 132)
- `enum LowerThirdStyle` (line 169)
- `enum LowerThirdAnimation` (line 179)
- `struct IntroOutroConfig` (line 192)
- `enum CardType` (line 234)
- `enum BackgroundStyle` (line 243)
- `struct CaptionStyleComponent` (line 254)
- `enum CaptionStyle` (line 326)




### Components/ExportComponents.swift

- **Lines**: 449
- **Public Types**: 14
- **Public Functions**: 0


**Public Types:**
- `struct ExportPresetComponent` (line 14)
- `enum ExportPlatform` (line 96)
- `struct ExportResolution` (line 140)
- `enum VideoCodec` (line 165)
- `enum AudioCodec` (line 174)
- `enum CaptionFormat` (line 183)
- `enum ColorSpace` (line 191)
- `struct ExportJobComponent` (line 201)
- `enum ExportJobStatus` (line 278)
- `struct ReframeInstructionsComponent` (line 302)
- `struct ReframeKeyframe` (line 319)
- `enum ReframeEasing` (line 349)
- `enum AutoReframeMode` (line 359)
- `enum SystemExportPresets` (line 369)




### Components/MLConsentComponents.swift

- **Lines**: 641
- **Public Types**: 29
- **Public Functions**: 1


**Public Types:**
- `struct MLModelConsentComponent` (line 14)
- `enum MLModelType` (line 85)
- `enum ConsentState` (line 97)
- `struct PrivacyPreferences` (line 106)
- `struct NetworkPermissions` (line 129)
- `enum AnonymizationLevel` (line 152)
- `struct ApprovalRecord` (line 159)
- `enum ApprovalMethod` (line 185)
- `struct ModelPackRegistryComponent` (line 195)
- `struct ModelInstallationRecordComponent` (line 247)
- `struct ConsentFlowUIComponent` (line 297)
- `struct ModelDownloadInfo` (line 336)
- `enum AuthMethod` (line 365)
- `enum InstallationStatus` (line 373)
- `struct ModelVerification` (line 385)
- `enum VerificationResult` (line 407)
- `struct ResourceRequirements` (line 416)
- `struct OSRequirements` (line 442)
- `struct ModelPackMetadata` (line 459)
- `struct InstallationAttempt` (line 491)
- `enum InstallationState` (line 520)
- `enum ApprovalStatus` (line 531)
- `enum ModelHealthStatus` (line 539)
- `enum ConsentFlowStep` (line 548)
- `struct InteractionState` (line 559)
- `struct UserAction` (line 579)
- `struct UIPreferences` (line 592)
- `struct FlowContext` (line 612)
- `enum FlowUrgency` (line 635)



**Public Functions:**
- `expiresWithin` (line 76)


### Components/MediaAssetComponents.swift

- **Lines**: 305
- **Public Types**: 9
- **Public Functions**: 0


**Public Types:**
- `struct MediaAssetComponent` (line 14)
- `enum MediaType` (line 61)
- `enum MediaAssetStatus` (line 69)
- `struct TemporalMetadataComponent` (line 80)
- `struct VideoMetadataComponent` (line 114)
- `struct AudioMetadataComponent` (line 164)
- `struct DeviceMetadataComponent` (line 203)
- `struct WaveformComponent` (line 247)
- `struct ThumbnailComponent` (line 282)




### Components/MulticamComponents.swift

- **Lines**: 256
- **Public Types**: 11
- **Public Functions**: 0


**Public Types:**
- `struct MulticamClusterComponent` (line 14)
- `enum ClusterStatus` (line 66)
- `struct SyncDataComponent` (line 78)
- `enum SyncMethod` (line 122)
- `struct CameraClassificationComponent` (line 142)
- `enum CameraAngleType` (line 174)
- `enum SubjectCoverage` (line 186)
- `enum StabilityRating` (line 195)
- `struct SyncMarkerComponent` (line 206)
- `struct SyncMarker` (line 216)
- `enum SyncMarkerType` (line 248)




### Components/ProjectComponents.swift

- **Lines**: 315
- **Public Types**: 8
- **Public Functions**: 0


**Public Types:**
- `struct PolytroposProjectId` (line 14)
- `struct ProjectComponent` (line 34)
- `enum ProjectStatus` (line 96)
- `struct ProjectReferencesComponent` (line 125)
- `struct EventMetadataComponent` (line 154)
- `enum EventType` (line 191)
- `struct EditProfileHints` (line 278)
- `enum CutDensity` (line 286)




### Components/TimelineComponents.swift

- **Lines**: 404
- **Public Types**: 14
- **Public Functions**: 0


**Public Types:**
- `struct TimelineComponent` (line 14)
- `enum TimelineStatus` (line 61)
- `enum AspectRatio` (line 70)
- `struct TimelineTracksComponent` (line 97)
- `struct ClipSegment` (line 124)
- `struct OverlaySegment` (line 195)
- `enum OverlayType` (line 241)
- `struct OverlayContent` (line 251)
- `enum OverlayAnimation` (line 278)
- `struct TransitionDefinition` (line 290)
- `enum TransitionType` (line 316)
- `struct SceneComponent` (line 327)
- `enum PolytroposSceneType` (line 384)
- `enum SceneStatus` (line 397)




### Components/TranscriptComponents.swift

- **Lines**: 330
- **Public Types**: 9
- **Public Functions**: 1


**Public Types:**
- `struct TranscriptComponent` (line 14)
- `struct TranscriptSegment` (line 72)
- `struct TranscriptWord` (line 118)
- `struct CaptionTrackComponent` (line 152)
- `struct CaptionEntry` (line 184)
- `struct WordTiming` (line 225)
- `struct SpeakerDiarizationComponent` (line 266)
- `struct SpeakerInfo` (line 288)
- `struct SpeakerSegment` (line 314)



**Public Functions:**
- `encode` (line 254)


### EditProfiles/EditProfileConfiguration.swift

- **Lines**: 705
- **Public Types**: 12
- **Public Functions**: 1


**Public Types:**
- `struct EditProfile` (line 17)
- `struct CutTimingProfile` (line 85)
- `struct CameraSelectionProfile` (line 151)
- `struct MusicAlignmentProfile` (line 211)
- `struct CrowdShotProfile` (line 269)
- `struct EnergyMappingProfile` (line 343)
- `struct TransitionProfile` (line 407)
- `enum DissolveCondition` (line 455)
- `struct SceneDetectionProfile` (line 466)
- `enum SystemEditProfiles` (line 514)
- `struct EditProfileComponent` (line 666)
- `struct EditProfileOverrides` (line 680)



**Public Functions:**
- `profileFor` (static) (line 645)


### Music/BuiltInVibeProfiles.swift

- **Lines**: 729
- **Public Types**: 1
- **Public Functions**: 4


**Public Types:**
- `enum BuiltInVibeProfiles` (line 14)



**Public Functions:**
- `profile` (line 713)
- `allProfiles` (line 717)
- `profilesInCategory` (line 721)
- `registerCustomProfile` (line 725)


### Music/MusicComponents.swift

- **Lines**: 880
- **Public Types**: 29
- **Public Functions**: 0


**Public Types:**
- `struct MusicCueComponent` (line 23)
- `enum MusicCueStatus` (line 95)
- `struct MusicGenerationInfo` (line 104)
- `struct MusicalKey` (line 132)
- `enum NoteName` (line 147)
- `enum KeyMode` (line 163)
- `struct VibeProfileId` (line 177)
- `struct VibeProfileComponent` (line 205)
- `enum VibeCategory` (line 271)
- `struct InstrumentationProfile` (line 285)
- `enum DrumStyle` (line 322)
- `enum BassStyle` (line 334)
- `enum InstrumentType` (line 345)
- `struct RhythmProfile` (line 369)
- `struct TimeSignature` (line 401)
- `struct HarmonyProfile` (line 416)
- `struct ProductionProfile` (line 448)
- `struct SymbolicSourceComponent` (line 492)
- `enum SymbolicSourceType` (line 564)
- `enum LicenseStatus` (line 573)
- `struct UserInstrumentKitComponent` (line 585)
- `enum InstrumentKitCategory` (line 632)
- `struct SampleMapping` (line 644)
- `struct MusicGenerationJobComponent` (line 692)
- `enum MusicJobStatus` (line 764)
- `enum MusicGenerationStage` (line 773)
- `struct GeneratedMusicAssetComponent` (line 787)
- `struct MusicProvenance` (line 819)
- `enum StemType` (line 871)




### Music/MusicGenerationService.swift

- **Lines**: 685
- **Public Types**: 22
- **Public Functions**: 3


**Public Types:**
- `struct TargetMusicParameters` (line 339)
- `struct MusicGenerationResult` (line 347)
- `enum MusicGenerationError` (line 356)
- `protocol SymbolicLibrary` (line 385)
- `protocol VibeProfileRegistry` (line 397)
- `protocol UserKitRegistry` (line 404)
- `protocol SymbolicTransformer` (line 411)
- `protocol ArrangementGenerator` (line 422)
- `protocol MusicAudioRenderer` (line 439)
- `enum RenderQuality` (line 472)
- `struct MusicRenderResult` (line 479)
- `struct SymbolicData` (line 494)
- `struct SymbolicNote` (line 517)
- `struct SymbolicChord` (line 534)
- `enum ChordQuality` (line 549)
- `struct TransformedSymbolicData` (line 562)
- `struct SymbolicTrack` (line 577)
- `struct ArrangementData` (line 590)
- `struct ArrangementTrack` (line 613)
- `struct ArrangementEvent` (line 639)
- `enum ArrangementEventType` (line 654)
- `struct ArrangementSection` (line 663)



**Public Functions:**
- `generateMusic` (line 62)
- `generatePreview` (line 165)
- `render` (line 453)


### Music/MusicLearningIntegration.swift

- **Lines**: 509
- **Public Types**: 8
- **Public Functions**: 16


**Public Types:**
- `struct MusicInteraction` (line 24)
- `enum MusicInteractionType` (line 34)
- `struct MusicInteractionContext` (line 48)
- `struct MusicInteractionOutcome` (line 61)
- `enum RejectionReason` (line 253)
- `struct LearnedVibePreferences` (line 271)
- `struct UserMusicPreferences` (line 281)
- `struct MusicLearningBridge` (line 485)



**Public Functions:**
- `recordGeneration` (line 89)
- `recordAcceptance` (line 106)
- `recordRejection` (line 130)
- `recordVibeChange` (line 148)
- `recordIntensityAdjustment` (line 169)
- `recordComplexityAdjustment` (line 190)
- `recordReplacement` (line 211)
- `flush` (line 242)
- `processBatch` (line 296)
- `preferences` (line 431)
- `recommendedVibes` (line 436)
- `adjustedParameters` (line 454)
- `exportPreferences` (line 470)
- `importPreferences` (line 475)
- `createObserver` (static) (line 488)
- `createTrainer` (static) (line 505)


### Music/MusicSystems.swift

- **Lines**: 399
- **Public Types**: 6
- **Public Functions**: 3


**Public Types:**
- `struct MusicGenerationSystem` (line 15)
- `struct MusicCueAttachmentSystem` (line 189)
- `struct MusicMixingSystem` (line 260)
- `struct ProjectMusicSettingsComponent` (line 304)
- `struct MusicMixInfoComponent` (line 346)
- `enum MusicSystemError` (line 380)



**Public Functions:**
- `update` (line 30)
- `update` (line 195)
- `update` (line 266)


### Pipelines/PolytroposWorkflows.swift

- **Lines**: 171
- **Public Types**: 5
- **Public Functions**: 6


**Public Types:**
- `struct FullEventWorkflow` (line 14)
- `struct QuickClipWorkflow` (line 79)
- `struct ReExportWorkflow` (line 113)
- `struct CaptionOnlyWorkflow` (line 142)
- `struct AnalysisOnlyWorkflow` (line 156)



**Public Functions:**
- `prepare` (line 33)
- `finalize` (line 50)
- `shouldRunSystem` (line 66)
- `prepare` (line 95)
- `finalize` (line 102)
- `prepare` (line 126)


### PolytroposModule.swift

- **Lines**: 232
- **Public Types**: 12
- **Public Functions**: 3


**Public Types:**
- `enum PolytroposModuleVersion` (line 55)
- `enum PolytroposModule` (line 65)
- `enum PolytroposJobType` (line 167)
- `struct FullEventJobType` (line 186)
- `struct QuickClipJobType` (line 191)
- `struct ExportJobType` (line 196)
- `struct MusicGenerationJobType` (line 201)
- `struct MusicMixingJobType` (line 206)
- `struct ProxyGenerationJobType` (line 213)
- `struct MLTRenderJobType` (line 218)
- `struct FFmpegTranscodeJobType` (line 223)
- `struct ProjectInterchangeJobType` (line 228)



**Public Functions:**
- `register` (static) (line 77)
- `defaultWorkDirectory` (static) (line 146)
- `createQuickClipPipeline` (static) (line 152)


### Pro/AudioProcessing.swift

- **Lines**: 711
- **Public Types**: 20
- **Public Functions**: 6


**Public Types:**
- `struct AudioProcessingComponent` (line 15)
- `enum AudioProcessingScope` (line 46)
- `struct AudioEffect` (line 56)
- `enum AudioEffectType` (line 79)
- `struct AudioEffectParameters` (line 120)
- `enum CompressorPresets` (line 137)
- `enum LimiterPresets` (line 180)
- `enum EQPresets` (line 204)
- `enum NoiseReductionPresets` (line 266)
- `struct AssetAudioAnalysisComponent` (line 308)
- `struct WaveformData` (line 340)
- `struct LoudnessData` (line 380)
- `struct FrequencyData` (line 412)
- `struct FrequencyBand` (line 426)
- `enum SpectralBalance` (line 439)
- `struct AudioContentClassification` (line 449)
- `enum AudioContentType` (line 481)
- `struct AudioDuckingComponent` (line 492)
- `struct DuckingConfig` (line 514)
- `enum BuiltInAudioPresets` (line 640)



**Public Functions:**
- `encode` (line 370)
- `analyzeAudio` (line 571)
- `createProcessingChain` (line 591)
- `autoEnhanceDialog` (line 607)
- `normalizeLoudness` (line 617)
- `generateDuckingAutomation` (line 628)


### Pro/ColorGrading.swift

- **Lines**: 640
- **Public Types**: 20
- **Public Functions**: 6


**Public Types:**
- `struct ColorGradeComponent` (line 15)
- `enum ColorGradeScope` (line 81)
- `struct PrimaryColorCorrection` (line 91)
- `struct ColorWheelSettings` (line 142)
- `struct ColorWheelValue` (line 171)
- `struct CurveSettings` (line 193)
- `struct CurvePoints` (line 237)
- `struct CurvePoint` (line 252)
- `struct HSLSettings` (line 265)
- `struct HSLChannelAdjustment` (line 299)
- `struct WhiteBalanceSettings` (line 321)
- `struct LUTReference` (line 343)
- `enum LUTType` (line 366)
- `enum FilmEmulationPreset` (line 376)
- `struct ScopesComponent` (line 434)
- `enum ScopeType` (line 456)
- `struct ScopeDisplaySettings` (line 464)
- `enum ScopeColorMode` (line 484)
- `struct ScopeData` (line 561)
- `enum BuiltInColorPresets` (line 570)



**Public Functions:**
- `createColorGrade` (line 502)
- `applyGrade` (line 513)
- `autoWhiteBalance` (line 526)
- `autoExposure` (line 532)
- `copyGrade` (line 538)
- `generateScopeData` (line 550)


### Pro/ManualEditing.swift

- **Lines**: 726
- **Public Types**: 10
- **Public Functions**: 29


**Public Types:**
- `protocol EditOperation` (line 15)
- `struct AddClipOperation` (line 32)
- `struct RemoveClipOperation` (line 82)
- `struct MoveClipOperation` (line 127)
- `struct TrimClipStartOperation` (line 215)
- `struct TrimClipEndOperation` (line 280)
- `struct SplitClipOperation` (line 340)
- `struct RippleDeleteOperation` (line 424)
- `struct AddTrackOperation` (line 495)
- `enum EditError` (line 533)



**Public Functions:**
- `execute` (line 47)
- `undo` (line 72)
- `execute` (line 107)
- `undo` (line 115)
- `execute` (line 165)
- `undo` (line 199)
- `execute` (line 253)
- `undo` (line 266)
- `execute` (line 316)
- `undo` (line 327)
- `execute` (line 363)
- `undo` (line 403)
- `execute` (line 454)
- `undo` (line 474)
- `execute` (line 509)
- `undo` (line 521)
- `execute` (line 573)
- `undo` (line 589)
- `redo` (line 597)
- `clearHistory` (line 605)
- `undoDescription` (line 611)
- `redoDescription` (line 616)
- `addClip` (line 644)
- `removeClip` (line 661)
- `splitClip` (line 679)
- `undo` (line 697)
- `redo` (line 707)
- `canUndo` (line 717)
- `canRedo` (line 722)


### Pro/PolytroposProRoadmap.swift

- **Lines**: 642
- **Public Types**: 9
- **Public Functions**: 2


**Public Types:**
- `enum PolytroposProVersion` (line 15)
- `enum RoadmapPhase` (line 29)
- `enum RoadmapFeature` (line 150)
- `enum FeaturePriority` (line 294)
- `struct PolytroposProFeatureFlags` (line 313)
- `struct RoadmapStatus` (line 454)
- `enum FeatureStatus` (line 549)
- `enum CompetitiveAnalysis` (line 561)
- `enum PolytroposProModule` (line 599)



**Public Functions:**
- `completionForPhase` (line 470)
- `register` (static) (line 602)


### Pro/ProComponents.swift

- **Lines**: 783
- **Public Types**: 27
- **Public Functions**: 0


**Public Types:**
- `struct MultiTrackTimelineComponent` (line 15)
- `struct VideoTrack` (line 65)
- `struct AudioTrack` (line 94)
- `struct ProClipSegment` (line 129)
- `struct ProAudioSegment` (line 204)
- `struct ClipTransform` (line 282)
- `struct TransformKeyframe` (line 328)
- `struct AutomationKeyframe` (line 360)
- `enum EasingCurve` (line 380)
- `struct FadeDefinition` (line 390)
- `enum BlendMode` (line 403)
- `enum AudioBusType` (line 423)
- `struct MasterAudioSettings` (line 435)
- `enum LoudnessTarget` (line 455)
- `struct TimelineMarker` (line 476)
- `enum MarkerColor` (line 502)
- `enum MarkerType` (line 507)
- `struct SnapSettings` (line 518)
- `struct EditHistoryComponent` (line 546)
- `struct EditAction` (line 582)
- `enum EditActionType` (line 611)
- `struct ProxySettingsComponent` (line 663)
- `enum ProxyResolution` (line 700)
- `enum ProxyCodec` (line 715)
- `enum ProxyGenerationStatus` (line 722)
- `struct MediaRelinkComponent` (line 733)
- `struct MissingMediaEntry` (line 757)




### Pro/ProExport.swift

- **Lines**: 872
- **Public Types**: 18
- **Public Functions**: 6


**Public Types:**
- `struct ProExportConfiguration` (line 15)
- `struct ExportRange` (line 67)
- `enum ExportDestination` (line 80)
- `enum UploadPlatform` (line 125)
- `enum HardwareAcceleration` (line 135)
- `enum ProExportPreset` (line 145)
- `struct ExportSettings` (line 447)
- `struct ProResolution` (line 485)
- `enum ProVideoCodec` (line 500)
- `enum ProAudioCodec` (line 512)
- `enum ProColorSpace` (line 521)
- `struct ProExportJobComponent` (line 531)
- `enum ProExportStatus` (line 603)
- `enum ExportPhase` (line 615)
- `struct ProExportError` (line 626)
- `struct BatchExportConfiguration` (line 641)
- `enum NamingPattern` (line 683)
- `enum ExportServiceError` (line 850)



**Public Functions:**
- `encode` (line 108)
- `queueExport` (line 704)
- `queueBatchExport` (line 728)
- `startExport` (line 756)
- `cancelExport` (line 774)
- `getJobStatus` (line 844)


### Pro/ProSystems.swift

- **Lines**: 325
- **Public Types**: 10
- **Public Functions**: 10


**Public Types:**
- `struct MultiTrackTimelineSystem` (line 14)
- `struct ColorGradingSystem` (line 46)
- `struct AudioProcessingSystem` (line 75)
- `struct ProxyGenerationSystem` (line 99)
- `struct MediaRelinkSystem` (line 130)
- `struct ScopesAnalysisSystem` (line 163)
- `struct ExportQueueSystem` (line 192)
- `struct EditHistorySystem` (line 235)
- `struct ProAudioAnalysisSystem` (line 261)
- `enum ProSystemsRegistration` (line 288)



**Public Functions:**
- `update` (line 19)
- `update` (line 51)
- `update` (line 80)
- `update` (line 108)
- `update` (line 135)
- `update` (line 168)
- `update` (line 201)
- `update` (line 240)
- `update` (line 266)
- `registerAll` (static) (line 290)


### Services/HarmoniaPolytroposIntegration.swift

- **Lines**: 507
- **Public Types**: 24
- **Public Functions**: 7


**Public Types:**
- `enum PolytroposHarmoniaJobs` (line 15)
- `struct IngestJob` (line 18)
- `struct SyncJob` (line 38)
- `struct AudioAnalysisJob` (line 58)
- `struct VideoAnalysisJob` (line 81)
- `struct AutoEditJob` (line 104)
- `struct CaptionJob` (line 124)
- `struct ExportJob` (line 144)
- `struct EditProfileOverridesDTO` (line 173)
- `enum ProxyQuality` (line 202)
- `enum PolytroposJobResult` (line 212)
- `struct IngestResult` (line 221)
- `struct SyncResultDTO` (line 227)
- `struct AudioAnalysisResultDTO` (line 234)
- `struct VideoAnalysisResultDTO` (line 241)
- `struct AutoEditResultDTO` (line 247)
- `struct CaptionResultDTO` (line 254)
- `struct ExportResultDTO` (line 261)
- `enum JobPriority` (line 366)
- `enum HarmoniaJobStatus` (line 374)
- `enum PolytroposHarmoniaError` (line 384)
- `struct PolytroposWorkerInfo` (line 407)
- `struct WorkerCapabilities` (line 427)
- `struct WorkerLoad` (line 486)



**Public Functions:**
- `toOverrides` (line 191)
- `submitJob` (line 291)
- `getJobStatus` (line 308)
- `awaitJob` (line 314)
- `cancelJob` (line 320)
- `processFullEvent` (line 331)
- `processQuickClip` (line 348)


### Services/PolytroposService.swift

- **Lines**: 356
- **Public Types**: 1
- **Public Functions**: 14


**Public Types:**
- `enum PolytroposError` (line 331)



**Public Functions:**
- `createProject` (line 36)
- `getProject` (line 68)
- `listProjects` (line 73)
- `importMedia` (line 89)
- `createCluster` (line 151)
- `processProject` (line 185)
- `quickClip` (line 200)
- `createExportJob` (line 217)
- `getExportStatus` (line 245)
- `createBrandingProfile` (line 252)
- `setBrandingProfile` (line 272)
- `getScenes` (line 288)
- `updateSceneStatus` (line 302)
- `setSceneRating` (line 315)


### Services/Specialized/AutoEditEngine.swift

- **Lines**: 600
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `enum AutoEditError` (line 581)



**Public Functions:**
- `generateEdit` (line 27)


### Services/Specialized/ExportService.swift

- **Lines**: 348
- **Public Types**: 2
- **Public Functions**: 8


**Public Types:**
- `enum ExportError` (line 276)
- `struct ExportReport` (line 305)



**Public Functions:**
- `queueExport` (line 28)
- `startExport` (line 68)
- `getJobStatus` (line 109)
- `cancelExport` (line 114)
- `listJobs` (line 131)
- `queueBatchExport` (line 147)
- `queueSceneExports` (line 162)
- `generateReport` (line 332)


### Services/Specialized/SyncService.swift

- **Lines**: 361
- **Public Types**: 4
- **Public Functions**: 3


**Public Types:**
- `struct Configuration` (line 19)
- `struct SyncResult` (line 301)
- `struct AssetSyncResult` (line 310)
- `enum SyncError` (line 336)



**Public Functions:**
- `syncCluster` (line 62)
- `applyManualSync` (line 165)
- `verifySync` (line 184)


### Systems/MLModelProvisioningSystem.swift

- **Lines**: 508
- **Public Types**: 4
- **Public Functions**: 8


**Public Types:**
- `struct MLModelProvisioningSystem` (line 16)
- `enum DownloadStatus` (line 333)
- `struct DownloadResult` (line 340)
- `protocol NetworkBlocker` (line 488)



**Public Functions:**
- `update` (line 33)
- `continueDownload` (line 363)
- `cancelDownload` (line 397)
- `verify` (line 448)
- `install` (line 456)
- `uninstall` (line 464)
- `checkHealth` (line 481)
- `optimize` (line 500)


### Systems/PolytroposSystems.swift

- **Lines**: 600
- **Public Types**: 9
- **Public Functions**: 9


**Public Types:**
- `struct MediaIngestSystem` (line 14)
- `struct AudioSyncSystem` (line 114)
- `struct AudioAnalysisSystem` (line 174)
- `struct VideoAnalysisSystem` (line 245)
- `struct AutoEditSystem` (line 316)
- `struct CaptionSystem` (line 410)
- `struct BrandingSystem` (line 471)
- `struct ReframeSystem` (line 511)
- `struct ExportSystem` (line 544)



**Public Functions:**
- `update` (line 25)
- `update` (line 119)
- `update` (line 179)
- `update` (line 250)
- `update` (line 321)
- `update` (line 415)
- `update` (line 476)
- `update` (line 516)
- `update` (line 553)


