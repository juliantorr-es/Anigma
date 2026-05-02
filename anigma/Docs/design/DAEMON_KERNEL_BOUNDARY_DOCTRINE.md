# Daemon Kernel Boundary Doctrine

**Status:** Active Doctrine  
**Issue:** `td-11e206`  
**Date:** 2026-04-20  

## Core Rule

Anigma's Daemon Kernel is a slim, contract-first boundary for static-plugin architecture. Every red line names the approved shape.

## Kernel Classification

### Canonical Kernel Targets
- `DaemonFeatureContracts`
- `DaemonKernel`

### Kernel Role
The kernel owns:
- Lifecycle / phase transitions
- Feature registry
- Registration order / dependency checks
- Queue/dispatch coordination shell
- Inspection APIs
- Governance handoff boundary
- Config/health hooks once wired through contracts

**Approved Shape for Features**: Concrete feature workers and implementations belong in **Tier 3 Capability Modules** and are wired into the kernel through specific **Composition Targets**. The kernel remains agnostic to the implementation details of features like Harmonia or Diaplasion.

## Approved Pattern for Imports

### Allowed in `DaemonFeatureContracts` (Tier 1)
- `Foundation`
- Standard-library-only helper types
- Contract-only serialization/data types
- Primitive value types
- Stable registration descriptors
- Protocol surfaces with no feature/runtime implementation dependency

### Allowed in `DaemonKernel` (Tier 2)
- `DaemonFeatureContracts`
- `Foundation`
- Kernel-local queue/config/health primitives (if contract-safe)
- Minimal runtime-neutral utility/primitive layer
- Governance/health abstractions

## Boundary-Restricted Imports (Constructive Doctrine)

### Feature Implementations
- **Constraint**: Feature implementations (e.g., `HarmoniaModule`, `PolytroposModule`, `VectorumModule`) must not be imported into reusable kernel targets.
- **Approved Shape**: Features must use the `DaemonFeatureRegistrar` and `DaemonFeatureRegistry`.
- **Correct Layer**: Tier 3 capability modules and Tier 2 wiring targets.
- **Allowed Implementation**: Wiring targets (e.g., `ModelRegistryDaemonFeature`) may import feature modules to bootstrap registration.
- **Proof**: `validate_tiers.py` or `grep` checks against the kernel target allowlist.

### Feature-Rich Aggregators
- **Constraint**: Broad feature/runtime hybrids (e.g., `RLMModule`, `ContextumModule`) must not be imported directly into the kernel.
- **Approved Shape**: Use narrow, contract-first interfaces or isolated wiring adapters.
- **Correct Layer**: Composition root or specialized wiring targets.
- **Reason**: To maintain a narrow compile surface and enforce kernel/feature separation.

### Executable Composition Roots
- **Constraint**: Executable targets, app shells, and CLI composition targets must not be imported into the kernel.
- **Approved Shape**: The reusable kernel stays below the composition root. The executable target decidesthe set of included wiring targets.
- **Correct Layer**: Tier 0 shell and composition layer.

### Indirect Bridging
- **Constraint**: The kernel must not serve as an indirect bridge where one feature imports another via kernel-owned concrete types.
- **Approved Shape**: Use Tier 1 contracts and shared descriptors to define cross-feature communication.
- **Reason**: Prevents the recreation of monolithic "mega-targets" under a different name.

## Exception Management (Doctrine Override)

**Constraint**: Unattributed behavior drift or hidden dependencies must not exist.
**Approved Shape**: Any deviation from this boundary doctrine must be recorded as an explicit **Exception Record**.

**Required Exception Shape**:
1. Exact target
2. Exact restricted dependency/import
3. TD owner
4. Reason (why contract/wiring split is not yet possible)
5. Removal condition
6. Expiry/review point

## Kernel Fan-Out Budget
- `DaemonFeatureContracts`: fan-out `<= 2`
- `DaemonKernel`: fan-out `<= 4`

**Approved Shape for Growth**: Any increase in fan-out for `DaemonKernel` requires a TD exception and a review of whether the new dependency belongs in a contract-safe primitive layer.

## Validation Rules

- **Rule K1**: `DaemonFeatureContracts` uses only `Foundation` and contract-safe primitives. It remains agnostic to feature implementations and executables.
- **Rule K2**: `DaemonKernel` uses only `DaemonFeatureContracts` and explicitly approved kernel-safe utility targets.
- **Rule K3**: Concrete features register through registrars/wiring targets. The kernel provides the registration surface but does not bootstrap specific features.
- **Rule K4**: The executable composition root determines which wiring targets are resident in the runtime.

## Compliance and Enforcement
Enforcement scripts (e.g., `Scripts/validate_platform_portability.sh`) must provide constructive output:

*"Forbidden feature import found in DaemonKernel. Features must register via DaemonFeatureRegistrar in a wiring target. Implementation imports are allowed only in Tier 2 composition/wiring targets or Tier 3 capability modules."*
