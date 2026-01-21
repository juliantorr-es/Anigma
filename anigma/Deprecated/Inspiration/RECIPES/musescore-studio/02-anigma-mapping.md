# Anigma Mapping for MuseScore Studio

This file provides a direct mapping from concepts found in MuseScore Studio to Anigma's modules and architectural layers. This ensures that new ideas are integrated without inventing parallel frameworks.

## Mapping Table

| Inspiration Repo Concept | Anigma Module / Layer | Notes / Rationale |
|--------------------------|-----------------------|-------------------|
| CMake Feature Flags | HarmoniaCLI | Build system governance and configuration validation belongs in HarmoniaCLI's authority surface |
| Cross-Platform Build Scripts | HarmoniaCLI + Scripts/ | Build orchestration must stay within HarmoniaCLI governance, with implementation in existing Scripts/ structure |
| Build Mode Classification (dev/testing/release) | HarmoniaCLI | Build configuration governance is a core HarmoniaCLI responsibility |
| Optional Module Compilation | AnigmaCore + Capability Modules | Module organization extends AnigmaCore's ECS model while respecting capability module boundaries |
| Import/Export Plugin Interface | CodexModule | Document transformation and plugin interfaces belong in CodexModule's abstraction layer |
| Format-Specific Implementations | OutlineumModule | Concrete format implementations (MusicXML, MIDI, MEI) fit OutlineumModule's document processing scope |
| Plugin Registration System | ContractsCore | Plugin contracts and validation rules belong in ContractsCore's contract authority |
| Visual Regression Testing | HarmoniaCLI | Test orchestration and governance belongs in HarmoniaCLI |
| Unit Test Integration | AnigmaCore | Test primitives and ECS testing capabilities belong in AnigmaCore |
| Module Dependency Management | AnigmaCore | Module relationship management extends AnigmaCore's World/Entity model |
| Build Configuration Validation | HarmoniaCLI | All build governance must go through HarmoniaCLI's security events surface |
| Format Validation Logic | ContractsCore | Format-specific validation rules and contracts belong in ContractsCore |

## Detailed Module Analysis

### Core Governance Layer Mapping

#### HarmoniaCLI Extensions
- **MuseScore Concept**: CMake feature flag system
- **Anigma Implementation**: Extend HarmoniaCLI with build configuration governance
- **Integration Points**: `Scripts/harmonia.sh`, existing CLI commands
- **Governance Model**: All feature flag changes must pass through HarmoniaCLI validation
- **Security Considerations**: Build configuration changes logged as security events

#### AnigmaCore Enhancements
- **MuseScore Concept**: Module dependency management
- **Anigma Implementation**: Extend ECS World to manage module activation/deactivation
- **Integration Points**: Existing World/Entity/Component system
- **Type Authority**: Must respect existing ECS primitive authority
- **Concurrency Model**: Use existing Actor-based patterns for module state

### Capability Module Mapping

#### CodexModule Responsibilities
- **MuseScore Concept**: Plugin interface pattern
- **Anigma Implementation**: Document transformation plugin protocol
- **Integration Points**: Existing CodeX abstraction patterns
- **Contracts**: Define plugin interface contracts in ContractsCore
- **Governance**: Plugin registration through HarmoniaCLI

#### OutlineumModule Implementation
- **MuseScore Concept**: Format-specific import/export modules
- **Anigma Implementation**: MusicXML, MIDI, MEI format plugins
- **Integration Points**: Document processing workflows
- **Validation**: Format validation rules in ContractsCore
- **Testing**: Format-specific test suites

#### DatabaseCore Considerations
- **MuseScore Concept**: Configuration persistence
- **Anigma Implementation**: Feature flag and build configuration storage
- **Integration Points**: Existing SQLite-backed stores
- **Governance**: Build state managed through DatabaseCore interfaces
- **Security**: Build configuration access controlled through DatabaseCore

### Cross-Cutting Concerns

#### Type Authority Compliance
All mappings must respect the existing type authority boundaries:
- **ECS Primitives**: Remain under AnigmaCore authority
- **Contracts**: New plugin contracts under ContractsCore authority
- **State Management**: DatabaseCore maintains exclusive state authority
- **Governance**: HarmoniaCLI remains sole governance surface
- **Provenance**: AccessumModule handles build artifact provenance

#### Module Boundary Enforcement
The mappings maintain strict separation between Core and Capability layers:
- **Core Extensions**: Limited to governance and ECS enhancements
- **Capability Additions**: New plugin systems within existing module boundaries
- **Contract Integration**: All new contracts must be registered in ContractsCore
- **Security Integration**: All new capabilities must integrate with Harmonia governance

## Implementation Strategy

### Phase 1: Core Governance Enhancement
1. **HarmoniaCLI Extensions**: Implement build configuration governance
2. **AnigmaCore Enhancements**: Add module management to ECS World
3. **ContractsCore Updates**: Define plugin interface contracts

### Phase 2: Capability Module Implementation
1. **CodexModule**: Implement plugin interface and registry
2. **OutlineumModule**: Create format-specific plugins
3. **DatabaseCore Integration**: Add build configuration persistence

### Phase 3: Integration and Testing
1. **Cross-Module Integration**: Connect plugin system to build configuration
2. **Governance Integration**: Ensure all changes go through HarmoniaCLI
3. **Testing Implementation**: Add comprehensive testing for new capabilities

## Validation Criteria

### Type Authority Compliance
- [ ] No new ECS primitives defined outside AnigmaCore
- [ ] All plugin contracts registered in ContractsCore
- [ ] Build state managed exclusively through DatabaseCore
- [ ] Governance exclusively through HarmoniaCLI
- [ ] Provenance handled through AccessumModule

### Module Boundary Integrity
- [ ] Core extensions limited to governance and ECS
- [ ] Capability implementations within existing boundaries
- [ ] No parallel framework creation
- [ ] Clear separation between layers maintained
- [ ] Existing contracts respected and extended

### Governance Integration
- [ ] All build configuration changes logged
- [ ] Plugin registration governed by HarmoniaCLI
- [ ] Security events generated for all changes
- [ ] Type authority validation for all new types
- [ ] Contract compliance enforced for all implementations

## Risk Mitigation

### Architecture Drift Prevention
- All mappings must extend, not replace, existing authority
- Regular type authority compliance checks
- Module boundary validation in CI/CD
- Governance review for all architectural changes

### License Compliance
- "Interpret and re-design" approach mandatory
- No direct code porting from GPLv3 source
- Legal review for all pattern implementations
- Documentation of design decisions and adaptations

### Integration Complexity
- Incremental implementation approach
- Extensive testing at each phase
- Backward compatibility maintenance
- Clear migration paths for existing code
