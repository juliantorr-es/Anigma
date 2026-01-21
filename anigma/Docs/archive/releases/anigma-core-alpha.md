# Anigma Core Alpha Release

**Date:** 2025-12-06  
**Tag:** `anigma-core-baseline-2025-12-06`

## Summary

Baseline monorepo drop with governed inference (Themis/Bonkers++), the alt-media pipeline, and new domain modules scaffolded on a single ECS/job/governance core. Core + Diaplasion/Outlineum suites run; new modules compile and carry placeholder tests.

## What's Included

### Modules

| Module | Status | Description |
|--------|--------|-------------|
| **AnigmaCore** | ✅ Stable | ECS, jobs/workflows, governance (KillSwitch/WriteGate/OperatingModes), access control, privacy/lifecycle, audit log, telemetry, explainability, security utilities |
| **HarmoniaModule** | ✅ Alpha | Themis orchestrator, Bonkers++ reasoning safety, CI/CD gates, transparency bundles |
| **DiaplasionModule** | ✅ Implemented | Alt-media (OCR, chunking, EPUB/Braille/audio prep) workflows |
| **AccessumModule** | ⚠️ Minimal slice | Apertum Accesum pipeline (import → OCR → TTS → sync) with telemetry hooks |
| **OutlineumModule** | ✅ Implemented | Outline/zine generation, QA, export workflows |
| **PragmaModule** | ⚠️ Scaffolding | Work items, workflows, permissions; governance checks registered |
| **ConexusModule** | ⚠️ Scaffolding | CRM entities (contacts/orgs/pipelines/cases/activities) with governance checks |
| **CodexModule** | ⚠️ Scaffolding | Knowledge base entities (spaces/pages/templates/versions/comments) |
| **TranscriptumModule** | ⚠️ Scaffolding | Academic records entities (programs/courses/enrollments/grades) |
| **ObservatoriumModule** | ⚠️ Scaffolding | Telemetry/alert/error/feedback primitives |
| **PolytroposModule** | ⚠️ Plan/placeholder | Live-event video pipeline with native renderer + MLT/FFmpeg fallback plan |

### DiaplasionModule Systems

| System | Status | Description |
|--------|--------|-------------|
| DocumentIngestSystem | ✅ Implemented | PDF/image loading via CoreGraphics |
| OCRExtractionSystem | ✅ Implemented | Vision framework text recognition |
| TextChunkingSystem | ✅ Implemented | Paragraph/heading detection |
| EPUBExportSystem | ✅ Implemented | EPUB 3 with OPF/NCX generation |
| BrailleExportSystem | ✅ Implemented | UEB Grade 1/2, BRF/PEF output |
| AudioPrepSystem | ✅ Implemented | SSML generation for TTS |
| DiaplasionQASystem | ✅ Implemented | Quality validation pipeline |

### Workflows

| Workflow | Status |
|----------|--------|
| DocumentToEPUBWorkflow | ✅ Implemented |
| DocumentToBrailleWorkflow | ✅ Implemented |
| DocumentToAudioWorkflow | ✅ Implemented |
| OCROnlyWorkflow | ✅ Implemented |
| MultiFormatWorkflow | ⚠️ Partial (conditional branching pending) |

### Test Coverage

- Core + Diaplasion + Outlineum suites passing
- Harmonia governance/transparency helpers covered in alpha slice
- New module suites (Pragma/Conexus/Codex/Transcriptum/Observatorium/Polytropos) compile with placeholder cases; behavior coverage to follow

## MLX Audio Integration (Harmonia/OrchestrumCore)

The MLX audio stack is implemented in Harmonia's OrchestrumCore package and validated:

| Component | Status | Description |
|-----------|--------|-------------|
| MLXAudioEngine | ✅ Implemented | Wraps Kokoro/Orpheus from mlx-swift-audio |
| UnifiedAudioService | ✅ Implemented | Routes between MLX and system TTS |
| AudioExportSystem | ✅ Implemented | Diaplasion system using UnifiedAudioService |

**Harmonia Tag:** `harmonia-mlx-audio-2025-12-06`

### MLX Features Validated
- Kokoro voices (40+ options)
- Orpheus expressive voices (8 options with emotional tags)
- Chapter-based audiobook generation
- Streaming synthesis
- Backend auto-selection (MLX → System TTS fallback)

## What's Not Integrated Yet

- Full Apertum Accessum integration
- Legacy Harmonia bits (being migrated to OrchestrumCore)

## Known Issues

1. **Swift 6 Sendable Debt** (in OrchestrumCore)
   - `HarmoniaDatabase.query()` returns `[[String: Any?]]` which is not Sendable
   - Temporary workaround: Swift 5 language mode in OrchestrumCore
   - Plan: Refactor to return Codable types

2. **Quota Manager Tests** (3 failures in OrchestrumCore)
   - Pre-existing test logic issues
   - Not related to audio/accessibility work

## Architecture Notes

### Diaplasion Pipeline Flow

```
DocumentSourceComponent
         ↓
    [DocumentIngestSystem]
         ↓
  IngestedDocumentComponent
         ↓
    [OCRExtractionSystem]
         ↓
    OCRResultComponent
         ↓
    [TextChunkingSystem]
         ↓
   ChunkedTextComponent
         ↓
┌────────┼────────────┐
↓        ↓            ↓
[EPUB]  [Braille]   [Audio]
Export   Export      Prep
System   System      System
         ↓
   [DiaplasionQASystem]
         ↓
  AccessibleOutputComponent
```

### Key Constraints Followed

1. ✅ Uses AnigmaCore ECS/Job engine exclusively
2. ✅ Pure Swift implementation (Vision, CoreGraphics, Foundation)
3. ✅ No external runtimes (Python, Node, Tesseract CLI)
4. ✅ No GPL/AGPL dependencies
5. ✅ Test-driven with fixtures

## Next Steps

1. ✅ ~~Wire MLX audio from OrchestrumCore into Diaplasion workflows~~ (Done)
2. Add end-to-end integration test: PDF → EPUB + Audiobook
3. Create tiny vertical slice: text → MLXAudioEngine → WAV on disk
4. Implement AccessumModule for Apertum client shell
5. Clean up Swift 6 Sendable issues in database layer
