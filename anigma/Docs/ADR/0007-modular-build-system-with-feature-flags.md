# ADR-0007: Modular Build System with Feature Flags

> **Status:** Proposed  
> **Date:** 2025-12-17  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

Anigma's current build system uses Swift Package Manager with basic build configurations, but lacks the ability to selectively compile capability modules based on deployment requirements. Inspiration from MuseScore Studio's comprehensive CMake feature flag system demonstrates how large projects can benefit from modular compilation to reduce binary size, customize feature sets, and simplify testing.

The current system requires all capability modules to be compiled even when not needed for a specific deployment scenario, leading to unnecessary binary bloat and increased attack surface.

---

## Decision

Adopt a modular build system with feature flags that allows selective compilation of Anigma's capability modules while maintaining Harmonia governance over build configuration changes.

### Key Components

1. **Feature Flag Configuration**: Extend Swift Package Manager with custom build configurations for each capability module
2. **Governance Integration**: All feature flag changes must pass through HarmoniaCLI governance gates
3. **Build Mode Classification**: Formalize dev/testing/release build modes with appropriate feature sets
4. **Cross-Platform Support**: Unified build scripts that work across Windows, macOS, and Linux

### Implementation Strategy

1. **Phase 1**: Implement basic feature flag system in HarmoniaCLI
2. **Phase 2**: Extend Scripts/harmonia.sh with modular build support
3. **Phase 3**: Integrate with Swift Package Manager build configurations
4. **Phase 4**: Add governance validation for all build mode changes

---

## Rationale

This approach provides several benefits while maintaining Anigma's governance principles:

### Benefits

- **Reduced Binary Size**: Only compile needed capability modules for specific deployments
- **Improved Security**: Smaller attack surface by excluding unused modules
- **Faster Builds**: Compile only what's needed for development and testing
- **Flexible Deployment**: Support different deployment scenarios (minimal, full, custom)
- **Better Testing**: Isolated testing of individual capability modules

### Alignment with Anigma Architecture

- **Governance Compliance**: All build configuration changes go through HarmoniaCLI
- **Type Authority**: No conflicts with existing type authority boundaries
- **Module Boundaries**: Respects existing capability module structure
- **Security Model**: Enhances rather than bypasses existing security boundaries

### Alternatives Considered

1. **Status Quo**: Continue with monolithic builds
   - **Pros**: Simplicity, no changes needed
   - **Cons**: Binary bloat, security surface, inflexible deployment
   - **Rejected**: Does not address scalability and deployment needs

2. **Separate Build Systems**: Create parallel build system for capability modules
   - **Pros**: Complete isolation
   - **Cons**: Violates governance principles, creates parallel authority
   - **Rejected**: Conflicts with HarmoniaCLI governance authority

3. **Runtime Module Loading**: Load modules dynamically at runtime
   - **Pros**: Maximum flexibility
   - **Cons**: Security risks, complexity, violates local-first principles
   - **Rejected**: Introduces runtime security risks and complexity

---

## Consequences

### Positive

- Deployments can be customized for specific use cases
- Development builds become faster and more focused
- Security surface reduced for minimal deployments
- Better integration testing of individual modules
- Clear separation between core and optional functionality

### Negative

- Increased build system complexity
- Need for comprehensive testing of all build configurations
- Additional governance overhead for feature flag management
- Learning curve for developers understanding modular builds

### Neutral

- Changes to development workflow for module-specific development
- Additional documentation requirements for build configurations
- New build artifacts for different module combinations

---

## Migration

### Phase 1: Foundation (Weeks 1-2)
- Extend HarmoniaCLI with feature flag validation
- Update Scripts/harmonia.sh to support module selection
- Create initial feature flag configuration files

### Phase 2: Implementation (Weeks 3-4)
- Implement Swift Package Manager build configurations
- Add cross-platform build script support
- Create governance gates for feature flag changes

### Phase 3: Integration (Weeks 5-6)
- Update CI/CD pipelines for modular builds
- Add testing for all build configurations
- Document new build processes

### Deprecation Timeline
- **Week 1-2**: Feature flags available alongside existing builds
- **Week 3-4**: Modular builds become default for new development
- **Week 6**: Legacy monolithic builds deprecated (with compatibility adapter)

### Compatibility Adapters
- Provide legacy build mode for existing workflows
- Create migration scripts for existing projects
- Maintain backward compatibility during transition

---

## References

- Related ADRs: ADR-0004 (Module Boundaries), ADR-0001 (Single ECS in AnigmaCore)
- Related code: `Scripts/harmonia.sh`, `Package.swift`, `Sources/`
- External inspiration: MuseScore Studio CMake configuration
- Governance: `Docs/governance/type-authority-map.json`
- Pattern registry: `Docs/patterns/pattern-registry.json`

---

## Acceptance Criteria

- [ ] Feature flags can enable/disable each capability module independently
- [ ] HarmoniaCLI validates all feature flag changes
- [ ] Cross-platform builds work consistently
- [ ] Build times reduced for module-specific configurations
- [ ] Binary size reduction measurable for minimal builds
- [ ] All build configurations pass existing test suites
- [ ] Documentation updated with new build processes
- [ ] Migration guide provided for existing projects

