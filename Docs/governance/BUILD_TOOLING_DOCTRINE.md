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

## 6. Alignment Diagnostic Matrix

The alignment diagnostic matrix is generated from SwiftPM graph evidence plus Anigma doctrine. It is not a hand-authored spreadsheet. Reviewers should use it to identify where backend normalization assumptions conflict with heterogeneous saturated architecture doctrine, ECS-inspired data runtime doctrine, sidecar readiness doctrine, or receipt/evidence requirements. 

The alignment matrix is produced by:
```bash
python3 Scripts/anigma_package_graph_audit.py alignment-matrix
```
It turns SwiftPM graph facts plus architecture doctrine into reviewable diagnostics (JSON, CSV, Markdown).

The alignment matrix is **generated evidence**, not a hand-authored artifact. It turns SwiftPM graph facts plus architecture doctrine into reviewable diagnostics.

## 7. TD Workflow Gate: Package Graph Audit Requirement

**MANDATORY:** Any TD touching the following areas MUST include package graph audit as part of the workflow:

- Package.swift changes
- Import statement changes
- Target dependency changes
- Contract extraction
- Sidecar definitions/executables
- Test target dependencies
- Readiness lane definitions
- Executable product definitions

### Required Artifacts

| Phase | Command | Purpose | Output |
|-------|---------|---------|--------|
| Pre-change | `python3 Scripts/anigma_package_graph_audit.py snapshot --output-dir .build/anigma-graph/<td-id>-pre` | Capture baseline graph state | Internal and external graph snapshots |
| Hypothesis | `python3 Scripts/anigma_package_graph_audit.py [explain-target\|explain-edge\|why-builds]` | Document graph hypothesis | Human-readable analysis |
| Post-change | `python3 Scripts/anigma_package_graph_audit.py snapshot --output-dir .build/anigma-graph/<td-id>-post` | Capture modified graph state | Internal and external graph snapshots |
| Diff | `python3 Scripts/anigma_package_graph_audit.py --output-dir .build/anigma-graph/<td-id>-diff` (both) | Compare pre/post | Violation delta, coverage delta |
| Validation | `python3 Scripts/anigma_package_graph_audit.py --fail-on-violation` | Final gate | Exit 0 = pass, Exit 1 = fail |

### TD Template Integration

Add to every relevant TD document:

```markdown
## Package Graph Audit

### Pre-Change Snapshot
```bash
python3 Scripts/anigma_package_graph_audit.py \
  --output-dir .build/anigma-graph/<td-id>-pre snapshot
```
Output: `.build/anigma-graph/<td-id>-pre/`

### Graph Hypothesis
[Document the specific graph change hypothesis]

### Post-Change Snapshot
```bash
python3 Scripts/anigma_package_graph_audit.py \
  --output-dir .build/anigma-graph/<td-id>-post snapshot
```
Output: `.build/anigma-graph/<td-id>-post/`

### Graph Diff
```bash
# Compare violations
python3 -c "
import json
pre = json.load(open('.build/anigma-graph/<td-id>-pre/anigma-dependency-violations.json'))
post = json.load(open('.build/anigma-graph/<td-id>-post/anigma-dependency-violations.json'))
print(f'Pre errors: {pre[\"summary\"][\"errorCount\"]}')
print(f'Post errors: {post[\"summary\"][\"errorCount\"]}')
print(f'Delta: {post[\"summary\"][\"errorCount\"] - pre[\"summary\"][\"errorCount\"]}')
"
```

### Final Validation
```bash
python3 Scripts/anigma_package_graph_audit.py --fail-on-violation
# Exit code must be 0
```
```

### Example: td-7c0153

See `Docs/td/tasing/td-7c0153/td-7c0153-hypothesis.md` for a complete example of graph-driven TD research.

---

## 8. Future: Symbol Graph Integration

**PLANNED:** Integrate `swift package dump-symbol-graph` for API surface drift detection in Tier 1 contract modules.

- **Purpose:** Detect breaking changes in contract layer APIs
- **Integration:** Add as optional subcommand to audit script
- **Use Case:** Tier 1 contract modules where API stability is critical
- **Status:** Documented in `package-graph-rules.yaml` planned_rules
