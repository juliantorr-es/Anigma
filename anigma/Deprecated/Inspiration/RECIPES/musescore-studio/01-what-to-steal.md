# What to Steal from MuseScore Studio

This file identifies concrete patterns, APIs, data models, or system boundaries from MuseScore Studio that are worth adapting or re-implementing in Anigma. Remember: "Interpret and re-design," not "copy and adapt."

## Key Patterns / Concepts

### Build System Architecture
*   **Feature Flag Configuration**: Comprehensive CMake option system enabling selective module compilation (e.g., `MUE_BUILD_NOTATION_MODULE`, `MUE_BUILD_IMPEXP_MUSICXML_MODULE`)
*   **Cross-Platform Build Scripting**: Unified build script (`build.cmake`) that works across Windows, macOS, and Linux with platform-specific optimizations
*   **Build Mode Classification**: Clear separation between dev, testing, and release build modes with appropriate feature sets (`MUSE_APP_BUILD_MODE`)
*   **Test-Driven Build Validation**: Dedicated build configurations for testing (vtest, utest) with visual regression and unit test integration

### Module Organization
*   **Explicit Module Boundaries**: Well-defined module options for different functional areas (notation, playback, import/export, inspector, etc.)
*   **Optional Compilation**: Modules can be enabled/disabled at build time for customized deployments
*   **Hierarchical Module Structure**: Clear dependency relationships between core functionality and optional features

### Import/Export Plugin System
*   **Modular Format Support**: Separate modules for each import/export format (MusicXML, MIDI, MEI, GuitarPro, etc.)
*   **Plugin Interface Pattern**: Consistent interface structure for all format handlers
*   **Format-Specific Optimization**: Each module can optimize for its specific format requirements

### Testing and Quality Assurance
*   **Integrated Testing**: Build configurations specifically for testing with visual regression capabilities
*   **Separate Test Types**: Visual tests (vtest) and unit tests (utest) with different build configurations
*   **Quality Gates**: Testing integrated into the build process rather than separate validation

## Potential Adaptations for Anigma

### Build System Modernization
**Adaptation**: Replace CMake patterns with Swift Package Manager equivalents while maintaining the feature flag concept
- Map CMake `option()` commands to Swift build configurations
- Adapt `build.cmake` cross-platform patterns to Swift-based scripts in `Scripts/`
- Implement build mode classification in `Scripts/harmonia.sh` with governance validation

**Implementation Notes**:
- Use Swift Package Manager's build configurations and conditional compilation
- Extend HarmoniaCLI to validate feature flag changes
- Create cross-platform build scripts using Swift's system integration

### Module-Based Architecture Enhancement
**Adaptation**: Formalize Anigma's module boundaries using MuseScore's explicit module pattern
- Map MuseScore modules to Anigma's capability modules
- Implement optional compilation for non-essential capability modules
- Create feature flags for module selection in build configurations

**Implementation Notes**:
- Leverage existing module structure in `Sources/`
- Use type authority map to validate module boundaries
- Extend Harmonia governance for module activation

### Document Format Plugin System
**Adaptation**: Implement import/export plugin system in CodexModule and OutlineumModule
- Create plugin interface protocol for document formats
- Implement format-specific plugins for MusicXML, MIDI, MEI
- Use ContractsCore for plugin contracts and validation

**Implementation Notes**:
- Design plugin protocol that respects existing module boundaries
- Implement format registry in CodexModule
- Place format-specific logic in OutlineumModule

### Testing Integration Enhancement
**Adaptation**: Integrate testing more deeply into the build process
- Add test-specific build configurations to `Scripts/ci_all`
- Implement visual regression testing for document transformations
- Create governance gates for test execution

**Implementation Notes**:
- Extend existing test infrastructure
- Add testing configurations to build system
- Use HarmoniaCLI for test orchestration

## Implementation Priority

### High Priority (Immediate Adoption)
1. **Build Mode Classification**: Formalize dev/testing/release builds
2. **Cross-Platform Build Scripting**: Enhance `Scripts/harmonia.sh` for cross-platform support
3. **Feature Flag Foundation**: Implement basic feature flag system in HarmoniaCLI

### Medium Priority (Next Phase)
1. **Modular Build System**: Extend feature flags to capability modules
2. **Test-Driven Build Validation**: Enhance testing integration
3. **Import/Export Plugin System**: Implement plugin architecture

### Low Priority (Future Enhancement)
1. **Module Organization Refinement**: Formalize optional compilation patterns
2. **Advanced Testing**: Visual regression testing implementation
3. **Performance Optimization**: Build system performance enhancements

## Governance Considerations

All adaptations must:
- Respect existing type authority boundaries
- Extend rather than bypass HarmoniaCLI governance
- Maintain module boundary integrity
- Follow "interpret and re-design" principles due to GPLv3 license
- Integrate with existing contracts and validation systems
