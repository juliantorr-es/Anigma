# MAKER Engine Enhancements Implementation Roadmap

## Overview
This roadmap outlines the implementation of four key native library integrations that materially improve MAKER's core capabilities while maintaining parallel-agent safety and governance compliance.

**STATUS: Superseded by ROADMAP.Aligned-2025-Q1.md**

**Note**: This roadmap has been superseded by the aligned roadmap based on current codebase implementation status. Refer to ROADMAP.Aligned-2025-Q1.md for current priorities.

**IMPLEMENTATION STATUS UPDATE (2025-01-27):**
- **Maker Engine Core: COMPLETE** - Implemented in Packages/AnigmaCore/Reasoning/MakerEngine.swift
- **Enhancement Layer: COMPLETE** - MakerEnhancementLayer with adapters implemented
- **Native Integrations: PARTIAL** - tree-sitter integrated, libgit2/RE2/WASM pending

## Implementation Priority

### Phase 1: libgit2 Integration (Highest Priority) - Q1 2025
**STATUS: NOT IMPLEMENTED** - Not found in codebase or dependencies

**Why First:** Foundational for parallel agent operations
- **Week 1-2:** Native library intake and basic Swift wrapper
- **Week 3-4:** GitEngine actor with deterministic diff generation
- **Week 5-6:** Parallel worktree support and base commit anchoring
- **Week 7-8:** Evidence generation and governance integration
- **Week 9-10:** Testing, performance optimization, documentation

**Success Criteria:**
- 10+ concurrent agents operating safely on same repository
- Deterministic diff generation in <100ms for typical changes
- Complete evidence trail for all git operations
- Integration with existing MAKER quarantine system

### Phase 2: tree-sitter Integration (High Priority) - Q1 2025
**STATUS: INTEGRATED** - Dependency added in Package.swift, referenced in syntax modules

**Why Second:** Quality/scale improvements for symbol indexing
- **Week 1-2:** Native library intake with language grammars
- **Week 3-4:** RepoMapIndexer actor with Swift parsing
- **Week 5-6:** Incremental parsing and cache management
- **Week 7-8:** Multi-language support and symbol resolution
- **Week 9-10:** Integration with candidate generation pipeline

**Success Criteria:**
- Replace grep-based heuristics with syntax-aware indexing
- Incremental parsing under 10ms for <1000 line changes
- Support Swift, TypeScript, Python, Rust grammars
- Type-aware symbol search with cross-language resolution

### Phase 3: RE2 Integration (Medium Priority) - Q2 2025
**STATUS: NOT IMPLEMENTED** - Not found in codebase or dependencies

**Why Third:** Reliability guarantees for candidate validation
- **Week 1-2:** Native library intake and SafeRegexEngine actor
- **Week 3-4:** Bounded execution with time/memory limits
- **Week 5-6:** Deterministic match ordering and validation
- **Week 7-8:** Integration with candidate generation and validation
- **Week 9-10:** Performance optimization and DoS protection

**Success Criteria:**
- Replace NSRegularExpression in candidate validation
- Bounded execution guarantees (no catastrophic backtracking)
- Performance under 50ms for large text processing
- Protection against regex DoS attacks

### Phase 4: WASM Integration (Advanced Priority) - Q2 2025
**STATUS: NOT IMPLEMENTED** - Only found in swift-syntax build error, not as integrated feature

**Why Fourth:** Advanced policy execution without dynamic language risks
- **Week 1-2:** Native library intake and PolicyExecutor actor
- **Week 3-4:** Host function whitelisting and resource limits
- **Week 5-6:** Deterministic execution and fuel management
- **Week 7-8:** Custom policy module loading and validation
- **Week 9-10:** Integration with PolicyEnforcementEngine

**Success Criteria:**
- Sandbox for custom policy predicates
- Deterministic execution across platforms
- Resource limits enforced (fuel, memory)
- Safe host function interface

## Parallel Development Strategy

### Overlapping Workstreams
- **Week 1-4:** All four native library intake contracts can proceed in parallel
- **Week 5-8:** Adapter implementation with periodic integration testing
- **Week 9-10:** Final integration, performance optimization, and governance validation

### Cross-Cutting Concerns
All phases must address:
- **Parallel Safety:** Actor isolation and concurrent operation support
- **Evidence Generation:** Receipt generation for all native operations
- **Performance:** Benchmarks vs current implementations
- **Governance:** Integration with existing MAKER governance systems
- **Testing:** Unit, integration, fuzz, and performance testing

## Risk Mitigation

### Technical Risks
- **Native Library Complexity:** Start with minimal viable implementations
- **Performance Regression:** Comprehensive benchmarking before/after
- **Memory Safety:** Extensive fuzz testing and validation
- **Platform Compatibility:** Test across macOS, iOS, Linux targets

### Governance Risks
- **Receipt Generation:** Implement evidence generation from day one
- **Policy Compliance:** Regular validation with governance gates
- **Quarantine Integration:** Early testing with MAKER quarantine system
- **Audit Trail:** Complete operation logging and traceability

## Success Metrics

### Quantitative Metrics
- **Parallel Agents:** 10+ concurrent agents without conflicts
- **Performance:** 2x+ improvement in candidate generation quality
- **Reliability:** Zero catastrophic backtracking incidents
- **Coverage:** Syntax-aware indexing for 5+ programming languages

### Qualitative Metrics
- **Determinism:** Same inputs always produce same outputs
- **Safety:** No memory safety violations or crashes
- **Governance:** Complete audit trail for all operations
- **Maintainability:** Clear separation of concerns and documentation

## Handoff Criteria
Each phase must meet all acceptance criteria before proceeding:
1. **Contract Compliance:** All native library contracts satisfied
2. **Parallel Safety:** Concurrent agent testing passes
3. **Governance Integration:** Evidence generation validated
4. **Performance:** Benchmarks meet or exceed targets
5. **Documentation:** Complete API docs and integration guides

This roadmap ensures systematic, risk-managed implementation of MAKER engine enhancements while maintaining Anigma's high standards for safety, governance, and performance.
