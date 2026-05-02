# Native Library Intake Contract: RE2

## Purpose
This library exists in Anigma to provide: safe regex engine with predictable candidate generation and bounded execution.
It is used by: MakerEngineEnhancements module for SafeRegexEngine.
It must never be imported outside: Sources/MakerEngineEnhancements/Adapters/.

## Authority Boundary
Native surface owner: Sources/ExternalC/TextProcessing/RE2  
Swift wrapper owner: Sources/MakerEngineEnhancements/Adapters/SafeRegexEngine  
Allowed call sites: MakerEngineEnhancements only (SafeRegexEngine, CandidateValidator)

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: system package manager or bundled RE2

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: google/re2  
Version/Tag: 2024-07-02+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: No patches (use upstream RE2 as-is)

## License and Compliance
License: BSD-3-Clause  
Attribution file: Docs/licenses/RE2.txt  
App Store suitability: allowed

## Security Posture
Threat model: catastrophic backtracking attacks, regex denial of service  
Memory safety risks: bounded memory usage, no stack overflow  
Mitigations: RE2's DFA-based engine prevents catastrophic backtracking, timeout enforcement

## API Contract
Wrapper API must be:
- Deterministic for same inputs (RE2 guarantees this)
- Threading model defined (SafeRegexEngine actor manages all operations)
- Ownership model explicit (SafeRegexEngine owns compiled patterns)
- Bounded execution guarantees

Error mapping:
Native errors map to typed RegexError enum; never leak raw error codes.

## Core Capabilities Required

### Safe Candidate Generation
- `RE2::PartialMatch()` with time limits
- `RE2::FindAndConsume()` for iterative matching
- Deterministic match ordering

### Bounded Execution
- Configurable time limits (default 100ms)
- Memory usage monitoring
- Early termination on long-running patterns

### Performance Guarantees
- Linear-time complexity guarantees
- No catastrophic backtracking
- Predictable memory usage patterns

## Build and Tooling
SwiftPM target name(s): RE2 (system library)  
Expected build flags: -DRE2_USE_CXX11  
Platform support: macOS, iOS (limited), Linux

CI requirements:
- Builds on CI with deterministic configuration  
- Version recorded in build logs via RE2::Version()
- Test with pathological regex patterns

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any regex operation emits a "RegexOperation" receipt including pattern, input size, execution time, and match count.

## Acceptance Tests
Golden tests for correctness: SafeRegexEngineTests  
Fuzz/safety tests: Catastrophic backtracking prevention test suite  
Performance sanity: Large text processing under 50ms  
Pathological patterns: Verify bounded execution on DoS patterns

## Integration Requirements
- Replace NSRegularExpression in candidate validation
- Provide deterministic match ordering
- Generate regex operation receipts for governance
- Integration with existing candidate generation pipeline
