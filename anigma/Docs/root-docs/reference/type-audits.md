# Typealias Audit & Usage Matrix

This audit identifies how typealiases are used across the codebase to provide domain-specific names or bridge between modules.

## Executive Summary

- **Total Typealiases Found**: 300
- **Unique Alias Names**: 237

## Top 20 Most Frequent Typealias Names

| Alias Name | Unique Target Types | Modules Using It | Total Occurrences |
|---|---|---|---|
| Input | 7 | 3 | 10 |
| Output | 6 | 3 | 10 |
| MigrationResult | 2 | 2 | 3 |
| Resolution | 1 | 2 | 3 |
| PreviewResolution | 1 | 2 | 3 |
| AuditLog | 2 | 2 | 3 |
| MigrationTaskRow | 1 | 1 | 3 |
| PipelineStage | 1 | 1 | 3 |
| AllCases | 1 | 2 | 2 |
| MLWorkerEngine | 1 | 2 | 2 |
| MLTaskOptions | 1 | 2 | 2 |
| MLArtifactRef | 1 | 2 | 2 |
| MLWorkerRequest | 1 | 2 | 2 |
| ToolProgressCallback | 2 | 2 | 2 |
| UIImage | 2 | 1 | 2 |
| JobPriority | 1 | 1 | 2 |
| ErrorCode | 2 | 2 | 2 |
| MaturityReport | 1 | 1 | 2 |
| MaturityCategory | 1 | 1 | 2 |
| MaturitySuggestion | 1 | 1 | 2 |

## Backend Consolidation Strategy

Typealiases are powerful indicators of domain overlap. Here is how they help consolidate the backend:

1. **Identifying Shadow Domains**: When multiple modules alias different internal types to the same public name (e.g., `typealias Workspace = ...`), it suggests these modules are competing to own the same concept. These should be moved to a shared `ContractsCore` or `DomainCore`.
2. **Detecting Semantic Drift**: If an alias like `UserID` points to `String` in one module but `UUID` in another, it creates silent integration bugs. Consolidation requires standardizing these primitive aliases.
3. **Interface Bridging**: Many typealiases exist only to avoid importing a large module for a single type. If we see `typealias AppState = AnigmaAppMac.AppState` repeated, it's a sign that `AppState` should be extracted into a smaller interface module.
4. **Refactoring Targets**: High-frequency aliases with multiple target types (High 'Unique Target Types') are high-risk areas where the codebase is 'lying' about what a type actually is. These are the primary targets for protocol-based abstraction.

## Typealias Usage Matrix (Inconsistent Aliases)
Aliases that point to different types in different modules (potential semantic drift).

| Alias | Module -> Target Type Mapping |
|---|---|
| Input | **ProfileArtifact**: RendererKit;<br>**TabularIR**: RendererKit;<br>**BuildRequest**: HarmoniaModule;<br>**PDFIngestInput**: AnigmaCore;<br>**HybridSearchInput**: AnigmaCore;<br>**IndexEmbeddingsInput**: AnigmaCore;<br>**PDFRenderRequest**: AnigmaCore |
| Output | **RenderArtifact**: RendererKit;<br>**ToolCallResponse**: HarmoniaModule;<br>**PDFBlobArtifact**: AnigmaCore;<br>**HybridSearchResult**: AnigmaCore;<br>**IndexEmbeddingsOutput**: AnigmaCore;<br>**PDFRenderResult**: AnigmaCore |
| MigrationResult | **(oldID: String, newID: String, receipt: ReceiptWire)**: ExecutionCore;<br>**AnigmaPrimitives.MigrationResult**: AnigmaCore |
| AuditLog | **AuditLogging**: HarmoniaModule;<br>**AuditLogManager**: AnigmaCore |
| ToolProgressCallback | **@Sendable (Int, Int, String) async -> Void**: AnigmaPrimitives;<br>**AnigmaPrimitives.ToolProgressCallback**: HarmoniaModule |
| UIImage | **NSImage**: AnigmaSystemSpine;<br>**UIKit.UIImage**: AnigmaSystemSpine |
| ErrorCode | **Int32**: ImageDecodeCapsule;<br>**amfp_error_t**: MediaFingerprintCapsule |
| AnyCodable | **DocumentIRKit.AnyCodable**: DocumentRenderKit;<br>**AnigmaCore.AnyCodable**: AnigmaDaemonCore |
| PlatformView | **NSView**: DevelopumModule;<br>**UIView**: DevelopumModule |
| PlatformViewRepresentable | **NSViewRepresentable**: DevelopumModule;<br>**UIViewRepresentable**: DevelopumModule |
