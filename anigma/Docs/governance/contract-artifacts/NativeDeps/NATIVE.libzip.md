# Native Library Intake Contract: libzip

## Purpose
This library exists in Anigma to provide: ZIP archive creation, extraction, and manipulation support.  
It is used by: ContainerAdapters.  
It must never be imported outside: ContainerAdapters.

## Authority Boundary
Native surface owner: Sources/ExternalC/Containers/libzip  
Swift wrapper owner: Sources/ContainerAdapters  
Allowed call sites: ContainerAdapters only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: prebuilt-artifact  
Acquisition: pkg-config

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: libzip  
Version/Tag: 1.10.1  
Commit hash (if applicable): 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b  
Local patch policy: none

## License and Compliance
License: BSD-3-Clause License  
Attribution file: Docs/licenses/libzip.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (ZIP files)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, limits archive size, path traversal protection

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via actor/queue).  
Ownership model explicit (wrapper owns zip objects, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): libzip  
Expected build flags: -DHAVE_LIBZ, -DHAVE_LIBBZ2  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via zip_get_version().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: ZIP creation and extraction tests  
Fuzz/safety tests (if parsing): Path traversal attack test suite  
Performance sanity: Archive throughput, memory usage limits
