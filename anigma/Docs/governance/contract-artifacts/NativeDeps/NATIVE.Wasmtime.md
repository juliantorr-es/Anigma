# Native Library Intake Contract: Wasmtime

## Purpose
This library exists in Anigma to provide: sandboxable WASM runtime for deterministic policy predicate execution.
It is used by: MakerEngineEnhancements module for PolicyExecutor.
It must never be imported outside: Sources/MakerEngineEnhancements/Adapters/.

## Authority Boundary
Native surface owner: Sources/ExternalC/WASM/Wasmtime  
Swift wrapper owner: Sources/MakerEngineEnhancements/Adapters/PolicyExecutor  
Allowed call sites: MakerEngineEnhancements only (PolicyExecutor, CustomPolicyLoader)

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: bundled Wasmtime runtime

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: bytecodealliance/wasmtime  
Version/Tag: 19.0.0+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: Security patches only

## License and Compliance
License: Apache-2.0  
Attribution file: Docs/licenses/Wasmtime.txt  
App Store suitability: review required (WASM execution)

## Security Posture
Threat model: malicious WASM modules, resource exhaustion attacks, arbitrary code execution  
Memory safety risks: WASM sandbox provides isolation, but host interface is critical  
Mitigations: Strict resource limits, whitelisted host functions, deterministic execution

## API Contract
Wrapper API must be:
- Deterministic for same inputs (WASM specification guarantees this)
- Threading model defined (PolicyExecutor actor manages all WASM operations)
- Ownership model explicit (PolicyExecutor owns engine instances)
- Strict resource limits enforced

Error mapping:
Native errors map to typed WasmError enum; never leak raw error codes.

## Core Capabilities Required

### Safe Policy Execution
- `wasmtime_engine_new()` with fuel-based limits
- `wasmtime_module_new()` from validated WASM binaries
- Deterministic execution with same inputs

### Resource Management
- Fuel-based execution limits (max instructions)
- Memory limits (max heap size)
- Host function whitelisting only

### Deterministic WASM Runtime
- Same output for same inputs across platforms
- No floating-point nondeterminism
- Bounded execution guarantees

## Host Function Interface
Allowed host functions:
- `log(message: string)` - for audit logging
- `get_context(key: string) -> string` - for accessing policy context
- `hash(input: string) -> string` - for deterministic hashing

Forbidden host functions:
- File I/O operations
- Network access
- System calls
- Time-based operations (except for deterministic logging)

## Build and Tooling
SwiftPM target name(s): Wasmtime (system library)  
Expected build flags: -DWASMTIME_ENABLE_PARALLEL_COMPILATION  
Platform support: macOS, Linux (iOS not supported)

CI requirements:
- Builds on CI with deterministic configuration  
- Version recorded in build logs via wasmtime_version()
- Test resource limit enforcement

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any WASM execution emits a "WasmExecution" receipt including module hash, fuel consumed, execution time, and result.

## Acceptance Tests
Golden tests for correctness: PolicyExecutorTests  
Fuzz/safety tests: Malicious WASM module test suite  
Performance sanity: Policy evaluation under 10ms  
Resource limits: Verify fuel and memory limits enforced

## Integration Requirements
- Provide sandbox for custom policy predicates
- Generate WASM execution receipts for governance
- Integration with existing PolicyEnforcementEngine
- Support deterministic policy evaluation across platforms
