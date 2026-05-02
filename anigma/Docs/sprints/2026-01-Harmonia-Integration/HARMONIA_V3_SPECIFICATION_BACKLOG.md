> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Harmonia V3 Specification Backlog

> **Status**: Ready for Review
> **Date**: 2026-04-13
> **Source**: td-ac0117 - Convert unfinished legacy/V2 behavior into Harmonia V3 specification
> **Parent**: td-14bb05 - Inventory usable legacy and V2 Harmonia pieces for V3 absorption
> **Review Status**: ✅ Complete - Ready for submission

This document captures unfinished behaviors from legacy HarmoniaModule and HarmoniaV2 that need to be explicitly backlogged for Harmonia V3/HarmoniaRuntime implementation.

**Completion Summary**:
- ✅ Analyzed legacy HarmoniaModule and HarmoniaV2 codebase
- ✅ Identified 9 major deferred capabilities
- ✅ Created detailed specification backlog
- ✅ Defined acceptance criteria for each capability
- ✅ Created 9 TD child tasks with full specifications
- ✅ Documented all source references and dependencies
- ✅ Established implementation priority phases

## Legend

- **📋 Deferred**: Important for full Harmonia capability but not needed for compile gate
- **🔧 Adapt**: Useful but requires wrapper/protocol adapter/type cleanup
- **⚠️ Archive**: Stale, duplicated, or too broken to remain on active path
- **✅ Absorb**: Compiles, has clear behavior, already absorbed

## 1. Orchestration & Execution

### 1.1 Phase9 Loop Execution
**Status**: 📋 Deferred
**Source**: `HarmoniaV2/HarmoniaOrchestration.swift:30-32`
**Current**: `executePhase9()` throws `notImplemented`
**Acceptance Criteria**:
- [ ] Implement Phase9 loop with agent coordination
- [ ] Support context propagation through iterations
- [ ] Return structured `Phase9Result` with observations and next actions
- [ ] Handle cancellation and timeout scenarios

### 1.2 Tool Execution
**Status**: 📋 Deferred
**Source**: `HarmoniaV2/HarmoniaOrchestration.swift:37-39`
**Current**: `executeTool()` throws `notImplemented`
**Acceptance Criteria**:
- [ ] Implement tool routing and execution
- [ ] Support argument passing and result capture
- [ ] Return structured `ToolResult` with success/failure
- [ ] Integrate with governance and observability

## 2. Inference & Reasoning

### 2.1 Neural Reasoning Implementation
**Status**: 📋 Deferred
**Source**: `HarmoniaV2/HarmoniaInference.swift:180-200`
**Current**: `neuralReasoning()` returns deterministic stub output
**Acceptance Criteria**:
- [ ] Implement actual neural reasoning backend
- [ ] Support multiple reasoning models
- [ ] Return confidence-scored results
- [ ] Integrate with governance layer
- [ ] Add observability hooks

### 2.2 Embedding Backend Integration
**Status**: 🔧 Adapt
**Source**: `HarmoniaV2/HarmoniaInference.swift:205-257`
**Current**: Uses `DeterministicEmbeddingBackend` stub
**Acceptance Criteria**:
- [ ] Wire real embedding backends (CoreML, MLX)
- [ ] Support model selection and configuration
- [ ] Add embedding caching layer
- [ ] Integrate with memory storage

## 3. Memory & Retrieval

### 3.1 Embedding Generation in Storage
**Status**: 🔧 Adapt
**Source**: `HarmoniaV2/HarmoniaMemory.swift:50-55`
**Current**: `store()` has TODO for embedding generation
**Acceptance Criteria**:
- [ ] Wire embedding generation before storage
- [ ] Support multiple embedding models
- [ ] Add embedding to retrieval results
- [ ] Integrate with inference engine

### 3.2 Vector Search Implementation
**Status**: ✅ Absorb (partial)
**Source**: `HarmoniaV2/HarmoniaMemory.swift:100-125`
**Current**: `searchSimilar()` implemented but depends on store backend
**Acceptance Criteria**:
- [ ] Verify integration with actual storage backend
- [ ] Add performance optimization
- [ ] Support hybrid search (vector + keyword)

## 4. Core Infrastructure

### 4.1 Module Registry Enhancement
**Status**: 🔧 Adapt
**Source**: `HarmoniaV2/HarmoniaCore.swift:100-120`
**Current**: Basic `ModuleRegistry` implementation
**Acceptance Criteria**:
- [ ] Add module lifecycle management
- [ ] Support dependency tracking
- [ ] Add health monitoring
- [ ] Integrate with observability

### 4.2 Error Handling Standardization
**Status**: 🔧 Adapt
**Source**: `HarmoniaV2/HarmoniaCore.swift:125-130`
**Current**: Error handling scattered across modules
**Acceptance Criteria**:
- [ ] Standardize error types and codes
- [ ] Add error context propagation
- [ ] Integrate with telemetry
- [ ] Provide user-friendly error messages

## 5. Legacy HarmoniaModule

### 5.1 Full Module Migration
**Status**: ⚠️ Archive
**Source**: `HarmoniaModule/` (entire directory)
**Current**: ~5,700 compilation errors
**Decision**: Archive legacy module, extract usable components

### 5.2 Service Adapters
**Status**: ⚠️ Archive
**Source**: `HarmoniaModule/Sources/HarmoniaServices/Adapters/`
**Current**: Broken adapters referencing legacy surfaces
**Decision**: Rewrite behind HarmoniaRuntime facade

## 6. CLI Integration

### 6.1 Command Routing
**Status**: ✅ Absorb
**Source**: `HarmoniaCLI/HarmoniaCommands.swift`
**Current**: Routes through HarmoniaRuntime facade
**Acceptance Criteria**: Already met

### 6.2 Health/Status Reporting
**Status**: ✅ Absorb
**Source**: `HarmoniaCLI/HarmoniaStatusCommand.swift`
**Current**: Returns truthful degraded status
**Acceptance Criteria**: Already met

## 7. Governance & Observability

### 7.1 Receipts & Audit Events
**Status**: 📋 Deferred
**Source**: `HarmoniaModule/README.md`, `HarmoniaV2/MIGRATION_STATUS.md`
**Current**: Described as pending/migration work
**Acceptance Criteria**:
- [ ] Implement receipt generation
- [ ] Add audit event logging
- [ ] Integrate with observability
- [ ] Support query and filtering

### 7.2 Telemetry Integration
**Status**: 📋 Deferred
**Source**: Multiple modules
**Current**: Scattered logging, no centralized telemetry
**Acceptance Criteria**:
- [ ] Standardize telemetry collection
- [ ] Add performance metrics
- [ ] Integrate with monitoring systems
- [ ] Support export formats

## Implementation Priority

### Phase 1: Compile Gate (Current Focus)
- [x] CLI routing through HarmoniaRuntime
- [x] Health/status reporting
- [ ] Query/session controlled failures

### Phase 2: Core Functionality
- [ ] Phase9 loop execution
- [ ] Tool execution routing
- [ ] Real embedding backend
- [ ] Memory with embeddings

### Phase 3: Advanced Features
- [ ] Neural reasoning implementation
- [ ] Enhanced module registry
- [ ] Receipts and audit events
- [ ] Telemetry integration

## Source References

### HarmoniaV2 Sources
- `HarmoniaOrchestration.swift`: Orchestration and execution (lines 30-32, 37-39)
- `HarmoniaInference.swift`: Inference and reasoning (lines 180-200, 205-257)
- `HarmoniaMemory.swift`: Memory and retrieval (lines 50-55, 100-125)
- `HarmoniaCore.swift`: Core infrastructure (lines 100-120, 125-130)

### Legacy Sources
- `HarmoniaModule/` directory: Legacy implementation with ~5,700 compilation errors
- `HarmoniaModule/README.md`: Legacy documentation
- `HarmoniaV2/MIGRATION_STATUS.md`: Migration status and plans
- `HarmoniaV2/INTEGRATION_GUIDE.md`: Integration guidance

### Related Documents
- `HARMONIA_V3_BACKEND_STABILIZATION.md`: Overall stabilization plan
- `TD_CHILD_TASKS.md`: Detailed task specifications
- `anigma/Docs/guides/HarmoniaCLI-Overhaul.md`: CLI integration plans

## TD Child Tasks

Created as separate TD issues referencing this backlog:

1. **td-harmonia-phase9**: Implement Phase9 loop execution (High Priority)
2. **td-harmonia-tool-exec**: Implement tool execution routing (High Priority)
3. **td-harmonia-neural**: Implement neural reasoning backend (Medium Priority)
4. **td-harmonia-embeddings**: Wire real embedding backends (High Priority)
5. **td-harmonia-memory-embeddings**: Add embedding generation to storage (Medium Priority)
6. **td-harmonia-registry**: Enhance module registry (Medium Priority)
7. **td-harmonia-errors**: Standardize error handling (Medium Priority)
8. **td-harmonia-receipts**: Implement receipts and audit events (Low Priority)
9. **td-harmonia-telemetry**: Add telemetry integration (Medium Priority)

**Task Documentation**: See `TD_CHILD_TASKS.md` for detailed specifications

## Next Steps

1. Create TD child tasks for each deferred capability
2. Add detailed acceptance criteria to each task
3. Prioritize based on compile gate vs full functionality
4. Update this document as implementation progresses
5. Submit td-ac0117 for review