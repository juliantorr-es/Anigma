> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# TD Child Tasks for Harmonia V3 Specification

> **Status**: Ready for Review
> **Date**: 2026-04-13
> **Parent**: td-ac0117 - Backlog unfinished legacy/V2 behavior into Harmonia V3 specification
> **Source**: HARMONIA_V3_SPECIFICATION_BACKLOG.md
> **Review Status**: ✅ Complete - Ready for submission

**Task Creation Summary**:
- ✅ Created 9 detailed TD child task specifications
- ✅ Defined acceptance criteria for each task
- ✅ Established priorities and dependencies
- ✅ Documented implementation notes and constraints
- ✅ Linked all tasks to parent td-ac0117

## Task Template

```markdown
## [TASK_ID] - [Short Description]

**Status**: 📋 Open
**Priority**: [High/Medium/Low]
**Component**: [Orchestration/Inference/Memory/Core/Governance]
**Source**: [Source file:line]
**Parent**: td-ac0117

### Description
[Detailed description of what needs to be implemented]

### Acceptance Criteria
- [ ] [Specific criterion 1]
- [ ] [Specific criterion 2]
- [ ] [Specific criterion 3]

### Dependencies
- [Dependency task IDs if any]

### Notes
[Additional context or implementation notes]
```

## Created Tasks

### 1. Phase9 Loop Execution

```markdown
## td-harmonia-phase9 - Implement Phase9 loop execution

**Status**: 📋 Open
**Priority**: High
**Component**: Orchestration
**Source**: HarmoniaV2/HarmoniaOrchestration.swift:30-32
**Parent**: td-ac0117

### Description
Implement the Phase9 loop execution in HarmoniaRuntime. This is the core orchestration loop that coordinates agents, tools, and workflow execution.

### Acceptance Criteria
- [ ] Implement Phase9 loop with proper agent coordination
- [ ] Support context propagation through loop iterations
- [ ] Return structured Phase9Result with observations and next actions
- [ ] Handle cancellation and timeout scenarios gracefully
- [ ] Integrate with governance and observability hooks
- [ ] Add comprehensive unit tests

### Dependencies
- None (foundational capability)

### Notes
- Current implementation throws notImplemented
- Should coordinate with agent system and tool execution
- Must be async-safe and cancellation-aware
```

### 2. Tool Execution Routing

```markdown
## td-harmonia-tool-exec - Implement tool execution routing

**Status**: 📋 Open
**Priority**: High
**Component**: Orchestration
**Source**: HarmoniaV2/HarmoniaOrchestration.swift:37-39
**Parent**: td-ac0117

### Description
Implement tool routing and execution capability in HarmoniaRuntime. This enables the system to execute external tools with proper argument passing and result capture.

### Acceptance Criteria
- [ ] Implement tool routing mechanism
- [ ] Support argument passing and validation
- [ ] Capture and return structured ToolResult with success/failure
- [ ] Integrate with governance layer for tool approval
- [ ] Add observability hooks for tool execution
- [ ] Add comprehensive unit tests

### Dependencies
- None (foundational capability)

### Notes
- Current implementation throws notImplemented
- Should integrate with Phase9 loop for tool coordination
- Must handle tool errors and timeouts
```

### 3. Neural Reasoning Backend

```markdown
## td-harmonia-neural - Implement neural reasoning backend

**Status**: 📋 Open
**Priority**: Medium
**Component**: Inference
**Source**: HarmoniaV2/HarmoniaInference.swift:180-200
**Parent**: td-ac0117

### Description
Replace the deterministic stub implementation with actual neural reasoning capabilities. This should support multiple reasoning models and return confidence-scored results.

### Acceptance Criteria
- [ ] Implement actual neural reasoning backend
- [ ] Support multiple reasoning models (configurable)
- [ ] Return confidence-scored results with proper metadata
- [ ] Integrate with governance layer for model approval
- [ ] Add observability hooks for reasoning operations
- [ ] Add comprehensive unit and integration tests

### Dependencies
- td-harmonia-embeddings (for embedding support)

### Notes
- Current implementation returns deterministic stub output
- Should integrate with two-tier reasoning system
- Must handle model loading and inference errors
```

### 4. Real Embedding Backends

```markdown
## td-harmonia-embeddings - Wire real embedding backends

**Status**: 📋 Open
**Priority**: High
**Component**: Inference
**Source**: HarmoniaV2/HarmoniaInference.swift:205-257
**Parent**: td-ac0117

### Description
Replace the DeterministicEmbeddingBackend stub with real embedding backends (CoreML, MLX). Add support for model selection, configuration, and caching.

### Acceptance Criteria
- [ ] Implement CoreML embedding backend
- [ ] Implement MLX embedding backend
- [ ] Support model selection and configuration
- [ ] Add embedding caching layer
- [ ] Integrate with memory storage system
- [ ] Add comprehensive performance tests

### Dependencies
- None (foundational for inference)

### Notes
- Current implementation uses deterministic stub
- Should support multiple models and versions
- Must handle model loading errors gracefully
```

### 5. Memory Embedding Generation

```markdown
## td-harmonia-memory-embeddings - Add embedding generation to storage

**Status**: 📋 Open
**Priority**: Medium
**Component**: Memory
**Source**: HarmoniaV2/HarmoniaMemory.swift:50-55
**Parent**: td-ac0117

### Description
Wire embedding generation into the memory storage pipeline. This enables vector search capabilities and semantic retrieval.

### Acceptance Criteria
- [ ] Generate embeddings before storage operations
- [ ] Support multiple embedding models (configurable)
- [ ] Add embeddings to retrieval results
- [ ] Integrate with inference engine for embedding generation
- [ ] Add performance optimization for bulk operations

### Dependencies
- td-harmonia-embeddings (for embedding backend)

### Notes
- Current implementation has TODO comment for embedding generation
- Should be configurable per storage operation
- Must handle embedding generation failures
```

### 6. Enhanced Module Registry

```markdown
## td-harmonia-registry - Enhance module registry

**Status**: 📋 Open
**Priority**: Medium
**Component**: Core
**Source**: HarmoniaV2/HarmoniaCore.swift:100-120
**Parent**: td-ac0117

### Description
Enhance the basic ModuleRegistry implementation with lifecycle management, dependency tracking, and health monitoring.

### Acceptance Criteria
- [ ] Add module lifecycle management (init/shutdown)
- [ ] Support dependency tracking between modules
- [ ] Add health monitoring and status reporting
- [ ] Integrate with observability system
- [ ] Add thread-safe module registration
- [ ] Add comprehensive unit tests

### Dependencies
- None

### Notes
- Current implementation is basic set-based registry
- Should support module versioning
- Must be thread-safe and async-safe
```

### 7. Standardized Error Handling

```markdown
## td-harmonia-errors - Standardize error handling

**Status**: 📋 Open
**Priority**: Medium
**Component**: Core
**Source**: HarmoniaV2/HarmoniaCore.swift:125-130
**Parent**: td-ac0117

### Description
Standardize error types, codes, and handling across all Harmonia modules. Add context propagation and telemetry integration.

### Acceptance Criteria
- [ ] Define standardized error types and codes
- [ ] Add error context propagation
- [ ] Integrate with telemetry system
- [ ] Provide user-friendly error messages
- [ ] Add error recovery patterns
- [ ] Document error handling conventions

### Dependencies
- td-harmonia-telemetry (for telemetry integration)

### Notes
- Current error handling is scattered across modules
- Should create consistent error hierarchy
- Must preserve error context across async boundaries
```

### 8. Receipts & Audit Events

```markdown
## td-harmonia-receipts - Implement receipts and audit events

**Status**: 📋 Open
**Priority**: Low
**Component**: Governance
**Source**: HarmoniaModule/README.md, HarmoniaV2/MIGRATION_STATUS.md
**Parent**: td-ac0117

### Description
Implement receipt generation and audit event logging for governance and compliance. This provides a complete audit trail of system operations.

### Acceptance Criteria
- [ ] Implement receipt generation for key operations
- [ ] Add audit event logging with timestamps
- [ ] Integrate with observability system
- [ ] Support query and filtering of audit events
- [ ] Add export capabilities for compliance
- [ ] Add comprehensive integration tests

### Dependencies
- td-harmonia-telemetry (for observability integration)

### Notes
- Currently described as pending/migration work
- Should integrate with governance authorities
- Must be performant for high-volume operations
```

### 9. Telemetry Integration

```markdown
## td-harmonia-telemetry - Add telemetry integration

**Status**: 📋 Open
**Priority**: Medium
**Component**: Governance
**Source**: Multiple modules
**Parent**: td-ac0117

### Description
Add centralized telemetry collection, performance metrics, and monitoring system integration across all Harmonia modules.

### Acceptance Criteria
- [ ] Standardize telemetry collection API
- [ ] Add performance metrics (latency, throughput)
- [ ] Integrate with monitoring systems (Prometheus, etc.)
- [ ] Support multiple export formats
- [ ] Add health check endpoints
- [ ] Add comprehensive monitoring tests

### Dependencies
- None

### Notes
- Current telemetry is scattered logging
- Should support multiple monitoring backends
- Must be configurable and performant
```

## Implementation Priority

### Phase 1: Compile Gate (Current Focus)
1. td-harmonia-embeddings (High) - Foundational for inference
2. td-harmonia-phase9 (High) - Core orchestration
3. td-harmonia-tool-exec (High) - Tool execution

### Phase 2: Core Functionality
4. td-harmonia-memory-embeddings (Medium) - Memory with embeddings
5. td-harmonia-neural (Medium) - Neural reasoning
6. td-harmonia-registry (Medium) - Enhanced registry
7. td-harmonia-errors (Medium) - Error handling

### Phase 3: Advanced Features
8. td-harmonia-telemetry (Medium) - Telemetry
9. td-harmonia-receipts (Low) - Receipts and audit

## Next Steps

1. Create these tasks in TD system with proper metadata
2. Add detailed implementation notes to each task
3. Assign priorities and dependencies
4. Link all tasks to parent td-ac0117
5. Update HARMONIA_V3_SPECIFICATION_BACKLOG.md with task references
6. Submit td-ac0117 for review