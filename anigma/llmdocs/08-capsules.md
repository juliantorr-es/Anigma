# Capsule System

## Capsule Core
- The capsule base layer lives in `Packages/CapsuleCore/Sources/CapsuleCore` and provides shared interfaces for native-backed capabilities.
- Native bridges are centralized in `Native/Shims` with C/C++ adapters referenced by capsules.

## Core Capsules
- Vector and geometry: `Packages/VectorCapsule`, `Packages/VectorIndexCapsule`, `Packages/GeometryCapsule`.
- Rendering and layout: `Packages/LayoutEngineCapsule`, `Packages/SceneGraphCapsule`, `Packages/RenderPlanCapsule`, `Packages/HitTestCapsule`.
- Text and document processing: `Packages/TextChunkingCapsule`, `Packages/TextPipelineCapsule`, `Packages/PDFCapsule`, `Packages/MarkdownCapsule`, `Packages/SyntaxCapsule`.
- Media and aggregation: `Packages/MediaFingerprintCapsule`, `Packages/MediaContainerCapsule`, `Packages/VizAggregationCapsule`.

## Capsule APIs
- API-level documentation is under `Docs/API/Capsules` for supported capsule contracts.
- Capsule specs are formalized in `Docs/Templates/CapsuleSpecification.md`.

## Key References
- `Package.swift`
- `Packages/CapsuleCore/Sources/CapsuleCore`
- `Docs/API/Capsules`
