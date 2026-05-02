# Package Graph Enforcement Rules

**Status:** Active Design  
**Issue:** `td-b10ee6`  
**Date:** 2026-04-20  
**Source of truth for live enforcement:** `anigma/Scripts/validate_tiers.py`  

## Goal

Keep package graph aligned with ADR-0006 three-tier runtime architecture. Enforcement must catch:

1. forbidden cross-tier imports
2. capability-to-capability coupling
3. drift between documented tiers and checker tiers
4. violations early enough to stop build-surface expansion

This doc is design/spec for rule syntax, checker behavior, validation logic, test cases. It is not a claim that broader CI wiring already exists.

## Repo-Backed Architecture

Current checker uses three runtime tiers, plus app shells outside enforcement set.

### Tier 1: Governance / Identity / Primitive Contracts

- `GovernanceCore`
- `DoctrineCore`
- `AnigmaPrimitives`
- `ContractsCore`
- `SecurityEventsManager`
- `TelemetryCore`

### Tier 2: Platform Runtime / Shared Execution Infrastructure

- `AnigmaCore`
- `PlatformCore`
- `DatabaseCore`
- `StorageCore`
- `ExecutionCore`
- `InferenceCore`
- `CathedralModule`
- `CapabilityCore`
- `AnigmaSystemSpine`
- `GovernedMigrationCore`

### Tier 3: Capability Modules

- `HarmoniaModule`
- `DiaplasionModule`
- `AccessumModule`
- `OutlineumModule`
- `PragmaModule`
- `ConexusModule`
- `CodexModule`
- `TranscriptumModule`
- `ObservatoriumModule`
- `PolytroposModule`
- `VectorumModule`
- `PraxisModule`

### Tier 0 / App Shells

Not validated by current script. Composition roots may depend on lower tiers as needed.

Examples:
- CLI executables
- app shells
- daemon surfaces

## Enforcement Rules

### Rule R1: Tier 1 Portable Purity
Tier 1 modules (Governance, Identity, Primitive Contracts) must remain agnostic to runtime and capability implementations. 

- **Constraint**: Tier 1 modules must not depend on Tier 2 or Tier 3.
- **Approved Shape**: Use Tier 1 contracts and primitives to define policy and identity. Higher layers resolve these to concrete behaviors.
- **Correct Layer**: Policy-neutral semantics belong in Tier 1.
- **Reason**: To keep the governance layer reusable, low-fan-out, and free of runtime/storage/capability cycles.
- **Proof**: `validate_tiers.py` check confirms zero Tier 2/3 dependencies.

Violation form:
...
```text
Tier1Module -> Tier2Module
Tier1Module -> Tier3Module
```

### Rule R2: Tier 2 Platform Runtime Independence
Tier 2 modules provide shared execution infrastructure and host capabilities through stable contracts.

- **Constraint**: Tier 2 modules must not depend on Tier 3.
- **Approved Shape**: Tier 2 modules (e.g., `AnigmaCore`, `ExecutionCore`) provide the platform that hosts Tier 3 capabilities without knowing about concrete feature modules.
- **Correct Layer**: Execution, storage, and inference infrastructure belong in Tier 2.
- **Reason**: To ensure the platform is reusable across different capability sets and prevent feature bleed into the core.
- **Proof**: `validate_tiers.py` check confirms zero Tier 3 dependencies.

Violation form:
...
```text
Tier2Module -> Tier3Module
```

### Rule R3: Tier 3 Horizontal Isolation
Tier 3 capability modules represent independent feature domains.

- **Constraint**: Tier 3 capability modules must not depend on other Tier 3 capability modules.
- **Approved Shape**: Capability composition occurs through Tier 1 contracts and Tier 2 authorities. Cross-feature communication is routed via the shared platform runtime.
- **Correct Layer**: Feature-specific logic belongs in Tier 3.
- **Reason**: To prevent mesh coupling, control compile fan-out, and maintain modularity.
- **Proof**: `validate_tiers.py` check confirms no horizontal dependencies between Tier 3 modules.

Violation form:
...
```text
Tier3ModuleA -> Tier3ModuleB
```

### Rule R4: Target Classification and Scope
Any production package must be classified within the three-tier architecture or explicitly marked as an exempt composition root.

- **Constraint**: Unclassified production targets must not exist in the active package graph.
- **Approved Shape**: New packages must be added to the appropriate tier set in `validate_tiers.py`.
- **Correct Layer**: Tier 0 (App Shells) for composition roots; Tiers 1-3 for production logic.
- **Reason**: To prevent architectural drift and ensure that all new code is governed by tier rules.
- **Proof**: Checker warns on unclassified production targets.

Design requirement:
- any new production package should be added to one tier set or explicitly marked as exempt composition root

## Current Enforcement Mechanism

Current repo implementation is Python checker:

- file: `anigma/Scripts/validate_tiers.py`
- input: root `Package.swift`
- parsing model: regex over `.target(...)` and `.executableTarget(...)`
- dependency extraction: string literals inside `dependencies: [ ... ]`

### Current Checker Logic

1. load `Package.swift`
2. map target name -> declared dependency string set
3. for each Tier 1 module, intersect deps with Tier 2 ∪ Tier 3
4. for each Tier 2 module, intersect deps with Tier 3
5. for each Tier 3 module, intersect deps with Tier 3 excluding self
6. print violations with constructive remediation text (Approved Shape/Correct Layer/Refactor Path)
7. exit nonzero on any violation

### Strengths

- simple
- cheap
- repo-local
- easy to run in preflight and CI
- rules reflect ADR-0006 directly

### Limits

- regex parser fragile if `Package.swift` structure changes materially
- ignores products vs targets nuance
- ignores conditional dependencies
- ignores transitive dependency analysis
- ignores unknown/unclassified targets
- no machine-readable output format yet

## Rule Syntax Design

Current script hardcodes tier sets. Next durable step should preserve simplicity while making rule set explicit.

### Proposed Syntax

Use data-first config embedded in checker or adjacent JSON/TOML file:

```python
TIERS = {
    "tier1": {...},
    "tier2": {...},
    "tier3": {...},
    "tier0_exempt": {...},
}

RULES = [
    {
        "id": "R1",
        "forbid_from": "tier1",
        "forbid_to": ["tier2", "tier3"],
        "message": "Tier 1 must not depend on Tier 2 or Tier 3",
    },
    {
        "id": "R2",
        "forbid_from": "tier2",
        "forbid_to": ["tier3"],
        "message": "Tier 2 must not depend on Tier 3",
    },
    {
        "id": "R3",
        "forbid_from": "tier3",
        "forbid_to": ["tier3"],
        "allow_self": True,
        "message": "Tier 3 modules must not depend on other Tier 3 modules",
    },
]
```

### Why This Syntax

- close to current script
- no fake external tool dependency
- easier diff review than custom DSL
- straightforward machine-readable reporting

## Checker Design

### Inputs

- `Package.swift`
- tier/rule config

### Outputs

Human output:
- violating module
- illegal deps
- violated rule id
- remediation

Machine output, next step:

```json
{
  "status": "fail",
  "violations": [
    {
      "rule": "R2",
      "source": "AnigmaCore",
      "target": "HarmoniaModule",
      "message": "Tier 2 must not depend on Tier 3"
    }
  ]
}
```

### Required Validation Behavior

Checker must:

1. fail closed on detected forbidden deps
2. fail clear when `Package.swift` missing
3. report all violations in one run
4. keep remediation text specific to violated tier rule

Checker should next:

1. detect unclassified production targets
2. support explicit exempt composition-root list
3. emit JSON for CI annotation
4. optionally check target fan-out budgets after structural rule pass

## Validation Logic

Minimal algorithm:

```text
for each classified module:
  deps = direct target dependencies from Package.swift
  illegal = deps ∩ forbidden_targets_for(module_tier)
  if tier3:
    illegal = illegal - {self}
  if illegal non-empty:
    report violation
```

Important detail:
- this is direct-dependency validation, not full transitive graph proof

Design implication:
- direct-dependency rule is first enforcement layer
- deeper graph analysis can be added later, but must not replace this cheap gate

## Concrete Test Cases

### T1: Tier 1 purity violation

Setup:
- add `ExecutionCore` dependency to `GovernanceCore`

Expected:
- checker fails
- report cites Tier 1 boundary breach

### T2: Tier 2 runtime violation

Setup:
- add `HarmoniaModule` dependency to `AnigmaCore`

Expected:
- checker fails
- report cites Tier 2 must not depend on Tier 3

### T3: Tier 3 horizontal coupling violation

Setup:
- add `ObservatoriumModule` dependency to `HarmoniaModule`

Expected:
- checker fails
- report cites Tier 3 horizontal isolation breach

### T4: Clean graph pass

Setup:
- current compliant `Package.swift`

Expected:
- zero violations
- success summary

### T5: Unclassified target drift

Setup:
- add new production target not present in tier config

Expected next-step behavior:
- checker warns or fails with “unclassified target”

Current behavior:
- silent omission

This gap should be closed.

### T6: Parsing resilience

Setup:
- reformat target dependency arrays across multiple lines

Expected:
- checker still resolves dependencies correctly

If not:
- replace regex parsing with SwiftPM manifest introspection or more robust parser

## Integration Design

### Dev Workflow

Run locally from repo root:

```bash
cd anigma
python3 Scripts/validate_tiers.py
```

Expected success text:

```text
=== ANIGMA TIER VALIDATION (ADR-0006) ===
=== SUMMARY ===
✅ Architecture is clean. All tier boundaries respected.
```

### CI Gate

Recommended:
- run checker on every PR touching `Package.swift` or `Packages/**`
- fail job on any violation
- archive JSON report once machine-readable output exists

Not yet claimed here:
- existing CI job already wired

## Governance Fit

Package graph enforcement is first architectural gate for:

- static plugin boundary work
- Signal 4 / compilation-surface control
- fan-out budget enforcement
- foundation API governance

It should remain cheaper and earlier than build/test gates:

```text
package graph check -> build -> focused tests -> broader validation
```

## Known Gaps

1. current checker ignores unclassified targets
2. regex parsing may drift from manifest reality
3. no JSON output
4. no explicit exempt-composition-root syntax
5. no fan-out budget integration

These are next-step enhancements, not reasons to discard current checker.

## Acceptance Mapping For `td-b10ee6`

This design now covers:

- rule spec: yes
- checker design: yes
- validation logic: yes
- test cases: yes

Implementation of stronger parser, CI wiring, fan-out budgets, or package-graph codegen belongs to later tasks.
