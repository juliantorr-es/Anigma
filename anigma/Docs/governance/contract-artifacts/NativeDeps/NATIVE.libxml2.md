# Native Library Intake Contract: libxml2

## Purpose
This library exists in Anigma to provide: XML parsing, validation, and XPath query support.  
It is used by: ContainerAdapters.  
It must never be imported outside: ContainerAdapters.

## Authority Boundary
Native surface owner: Sources/ExternalC/Containers/libxml2  
Swift wrapper owner: Sources/ContainerAdapters  
Allowed call sites: ContainerAdapters only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: macOS system

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: libxml2  
Version/Tag: 2.12.5+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: none

## License and Compliance
License: MIT License  
Attribution file: Docs/licenses/libxml2.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (XML documents)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, limits document size, timeouts, XXE protection

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via actor/queue).  
Ownership model explicit (wrapper owns libxml2 objects, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): libxml2  
Expected build flags: -DLIBXML2_ENABLED, -DXML_DTD  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via xmlCheckVersion().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: XML parsing and XPath tests  
Fuzz/safety tests (if parsing): XXE attack test suite, billion laughs attack  
Performance sanity: Parsing throughput, memory usage limits
