# Native Library Intake Contract: FreeType

## Purpose
This library exists in Anigma to provide: Font rasterization and glyph rendering support.  
It is used by: ImagingAdapters.  
It must never be imported outside: ImagingAdapters.

## Authority Boundary
Native surface owner: Sources/ExternalC/Text/FreeType  
Swift wrapper owner: Sources/TextAdapters  
Allowed call sites: TextAdapters only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: prebuilt-artifact  
Acquisition: pkg-config

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: FreeType  
Version/Tag: 2.14.2  
Commit hash (if applicable): 9a5b3c2d1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b  
Local patch policy: none

## License and Compliance
License: FreeType License (BSD-like)  
Attribution file: Docs/licenses/FreeType.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (font files)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, limits buffer sizes, timeouts

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via actor/queue).  
Ownership model explicit (wrapper owns FT objects, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): FreeType  
Expected build flags: -DFT2_BUILD_LIBRARY, -DHAVE_FREETYPE  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via FT_Library_Version().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: Font rendering tests  
Fuzz/safety tests (if parsing): Font corruption test suite  
Performance sanity: Rasterization throughput, memory usage limits
