# Native Library Intake Contract: SQLite

## Purpose
This library exists in Anigma to provide: embedded SQL database storage with ACID compliance and thread-safe concurrent access.  
It is used by: DatabaseCore.  
It must never be imported outside: DatabaseCore.

## Authority Boundary
Native surface owner: Sources/ExternalC/Storage/SQLite  
Swift wrapper owner: Sources/DatabaseCore  
Allowed call sites: DatabaseCore only

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: macOS system

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: SQLite  
Version/Tag: 3.45.0+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: none

## License and Compliance
License: Public Domain  
Attribution file: Docs/licenses/SQLite.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing untrusted inputs? yes (SQL queries)  
Memory safety risks: owned pointers, buffer sizes, thread safety  
Mitigations: wrapper validates inputs, parameterizes queries, timeouts, actor isolation

## API Contract
Wrapper API must be:
Deterministic for same inputs, or explicitly documented when nondeterministic.  
Threading model defined (thread-safe via DatabaseActor).  
Ownership model explicit (DatabaseActor owns connection, manages lifecycle).

Error mapping:
Native errors map to typed Swift errors; never leak raw numeric codes as public API.

## Build and Tooling
SwiftPM target name(s): SQLite3 (system library)  
Expected build flags: -DSQLITE_ENABLE_FTS5, -DSQLITE_ENABLE_JSON1  
Platform support: macOS, iOS, Linux

CI requirements:
Builds on CI with deterministic configuration.  
Version recorded in build logs via sqlite3_libversion().

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any update of this library emits a "NativeDepUpdate" receipt including version pin and license check result.

## Acceptance Tests
Golden tests for correctness: DatabaseCoreTests  
Fuzz/safety tests (if parsing): SQL injection test suite  
Performance sanity: WAL checkpoint performance, transaction throughput
