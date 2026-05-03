# Anigma Build Tooling Doctrine

**Document ID:** BUILD-TOOLING-DOCTRINE-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-03

---

## Purpose

This file is the canonical landing zone for build-tooling doctrine updates. It establishes guidelines based on direct research into SwiftPM, llbuild, Swift driver, and SwiftSyntax.

## Core Mandate

**No Vendoring Policy:** Production Anigma code must not depend on upstream internals unless explicitly justified by documented evidence. Do not fork SwiftPM, llbuild, swift-driver, or SwiftSyntax. Consume their outputs as evidence surfaces instead.

## 1. Package Graph Hygiene

- **Rule:** Do not conflate targets and products. 
- **Rationale:** SwiftPM resolves dependencies into `ResolvedPackage` and `ResolvedModule` instances. `Product` instances (defined in `Sources/PackageModel/Product.swift`) group modules and specify output shapes (`.library`, `.executable`, `.plugin`, `.test`).
- **Validation:** Tier boundary validators must consume resolved package graphs (via SwiftPM manifest/package description outputs, package graph source research, or a dedicated Anigma graph extractor. Do not rely solely on regex over Package.swift).

## 2. Plugin Usage and Sandboxing

- **Rule:** Plugins must strictly declare sandbox boundaries and network intents.
- **Rationale:** `PluginInvocation.swift` enforces specific `workingDirectory`, `writableDirectories`, and `allowNetworkConnections` constraints. Build tool plugins must not perform network operations.
- **Outputs:** Plugins generating source code must output to the designated `pluginGeneratedSources` directory as defined by `PluginAction.createBuildToolCommands`.

## 3. Build Evidence and Compiler-Driver Handling

- **Rule:** Handle compile diagnostics via proper evidence surfaces.
- **Rationale:** The Swift Driver (`Sources/SwiftDriver/Jobs/Job.swift`) tracks input and output states via a structured `BuildPlan`. LLBuild (`lib/Core/BuildEngine.cpp`) determines rebuild necessity using file signatures in `.build/build.db`.
- **Validation:** Anigma should prefer machine-readable or structured diagnostic outputs where available, and otherwise preserve raw logs as evidence with explicit parser limitations.

## 4. SwiftPM Evidence Inputs

### Canonical Commands

Anigma recognizes the following SwiftPM commands as **canonical evidence inputs** for package graph auditing:

#### `swift package describe --type json`

- **Status:** PRIMARY SOURCE FOR INTERNAL GRAPH AUDITING
- **Purpose:** Captures local package structure including products, targets, target dependencies, target types, paths, and settings.
- **Doctrine Requirement:** MUST be used as the primary source for Anigma internal target/module graph auditing. Constraints expressed in `package-graph-rules.yaml` are applied to this output. Normalization to Anigma's graph schema is mandatory before doctrine enforcement.

#### `swift package show-dependencies --format json`

- **Status:** PRIMARY SOURCE FOR EXTERNAL GRAPH AUDITING
- **Purpose:** Captures resolved external package dependency graph including package identity, name, path/URL, version, state, and dependencies.
- **Doctrine Requirement:** MUST be used as the primary source for Anigma external package dependency graph auditing. Normalization to Anigma's external graph schema is mandatory.

#### `swift package dump-package`

- **Status:** SECONDARY / DIAGNOSTIC ONLY
- **Doctrine Constraint:** MUST NOT be treated as equivalent to resolved package graph. MAY be used for debugging Package.swift syntax. MUST NOT be used as final graph truth for doctrine enforcement.

### Prohibited Patterns

**MUST NOT:**
- Use `swift package dump-package` as the sole source for dependency graph analysis
- Use regex parsing of `Package.swift` as final graph truth
- Assume `dump-package` output equals resolved dependency graph

**MUST:**
- Use `describe --type json` for internal target/module graph auditing
- Use `show-dependencies --format json` for external package dependency graph auditing
- Normalize SwiftPM output into Anigma's own graph schema before doctrine enforcement
- Use regex over Package.swift only as a prefilter, never as final truth

## 5. Audit Script Severity Behavior

### `--fail-on-violation` Flag

The `anigma_package_graph_audit.py` script supports a `--fail-on-violation` flag that controls exit behavior:

- **Exits nonzero (failure) ONLY on error-severity violations**
- **Warning-severity findings are REPORTED BUT NON-BLOCKING**

This design enables **incremental adoption** of classification coverage and doctrine enforcement.

### Severity Classification

| Severity | Exit Code with `--fail-on-violation` | Example Rule | Rationale |
|----------|-------------------------------------|--------------|-----------|
| error | 1 (nonzero exit) | `no_upward_tier_dependency`, `no_contract_to_runtime_dependency`, `no_same_tier_cycle` | Architecture violations that must be fixed immediately |
| warning | 0 (success exit) | `no_unclassified_target` | Classification gaps during baseline adoption - non-blocking to allow gradual improvement |

### Use Cases

1. **CI Pipeline (strict mode):**
   ```bash
   python3 Scripts/anigma_package_graph_audit.py --fail-on-violation
   ```
   Exits nonzero if any error-severity violation exists (blocks build).

2. **CI Pipeline (baseline mode):**
   ```bash
   python3 Scripts/anigma_package_graph_audit.py
   ```
   Always exits zero, reports all violations in output files.

3. **Local Development:**
   ```bash
   python3 Scripts/anigma_package_graph_audit.py violations
   ```
   Check violations without generating full audit output.

4. **Classification Adoption:**
   ```bash
   python3 Scripts/anigma_package_graph_audit.py suggest-classifications
   ```
   Generate suggested tier/role classifications for unclassified targets.

### Coverage Thresholds

The `no_unclassified_target` rule is currently WARNING-severity to support baseline adoption.
Once classification coverage reaches the threshold defined in `package-graph-rules.yaml` 
(95% by default), this rule MAY be promoted to ERROR-severity.

Current baseline:
- Total targets: ~223
- Classified: ~64
- Coverage: ~28.7%
- Unclassified: ~159 targets

The graph audit now detects 24 error-severity architecture violations. These are baseline findings and must be triaged separately.

Target: 95%+ coverage before upgrading `no_unclassified_target` to error-severity.
