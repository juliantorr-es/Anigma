# Native Library Intake Contract: HarfBuzz

## Purpose
This library exists in Anigma to provide: OpenType text shaping and complex script layout.  
It is used by: TextAdapters.  
It must never be imported outside: TextAdapters.

## Authority Boundary
Native surface owner: Sources/ExternalC/Text/HarfBuzz  
Swift wrapper owner: Sources/TextAdapters  
Allowed call sites: TextAdapters only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: prebuilt-artifact  
Acquisition: pkg-config

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: HarfBuzz  
Version/Tag: 8.3.0  
Commit hash (if applicable): 8c658d5a1e2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c  
Local patch policy: none

## License and Compliance
License: MIT License  
Attribution file: Docs/licenses/HarfBuzz.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (font shaping)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, limits buffer sizes, timeouts

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via actor/queue).  
Ownership model explicit (wrapper owns HB objects, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): HarfBuzz  
Expected build flags: -DHAVE_FREETYPE, -DHAVE_ICU  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via hb_version_string().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: Text shaping tests for complex scripts  
Fuzz/safety tests (if parsing): Font corruption test suite  
Performance sanity: Shaping throughput, memory usage limits
