# Native Library Intake Contract: ICU

## Purpose
This library exists in Anigma to provide: Unicode text processing, normalization, collation, and internationalization support.  
It is used by: TextAdapters.  
It must never be imported outside: TextAdapters.

## Authority Boundary
Native surface owner: Sources/ExternalC/Text/ICU  
Swift wrapper owner: Sources/TextAdapters  
Allowed call sites: TextAdapters only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: macOS system

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: ICU  
Version/Tag: 74.2+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: none

## License and Compliance
License: ICU License (Unicode License)  
Attribution file: Docs/licenses/ICU.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (text processing)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, limits processing time, memory quotas

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via actor/queue).  
Ownership model explicit (wrapper owns ICU objects, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): ICU, ICUData  
Expected build flags: -DU_CHARSET=char, -DU_HAVE_STRTOD_L=1  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via u_getVersion().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: Unicode normalization tests  
Fuzz/safety tests (if parsing): Text corruption test suite  
Performance sanity: Text processing throughput, memory usage limits
