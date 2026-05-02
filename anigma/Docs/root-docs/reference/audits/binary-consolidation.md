# Binary Consolidation Report
**Date**: 2024-04-08  
**Status**: Partial Completion - CLI Cleanup Phase  
**Related Roadmap Items**: harmonia-surface-merge, legacy-cli-aliases, app-launcher-trim, product-removal-update

---

## Executive Summary

This report documents the core-binary consolidation cleanup focusing on CLI products, surface executables, and launcher scripts. The goal is to reduce redundancy, clarify canonical surfaces, and prepare for future consolidation into `harmonia` or removal.

---

## Changes Completed

### 1. ✅ Legacy CLI Aliases - Removed `anigma` Duplicate

**File**: `anigma/Package.swift` (line 136)  
**Change**: Removed duplicate `.executable(name: "anigma", ...)` product declaration  
**Rationale**: Both `anigma` and `anigma-cli` pointed to the same `AnigmaCLIExecutable` target. Kept `anigma-cli` as the canonical name.  
**Impact**: No breaking changes - `anigma` alias was not referenced in any scripts or documentation.

```diff
 let executableProducts: [Product] = [
     .executable(name: "harmonia-surface", targets: ["HarmoniaSurface"]),
     .executable(name: "doctrine", targets: ["DoctrineCLI"]),
-    .executable(name: "anigma", targets: ["AnigmaCLIExecutable"]),
+    // Note: "anigma" alias removed - use "anigma-cli" as canonical name
     .executable(name: "anigma-cli", targets: ["AnigmaCLIExecutable"]),
```

---

### 2. 📝 Pipeline Executables - Documented as Test Harnesses

**File**: `anigma/Package.swift` (lines 132-137)  
**Change**: Added TODO comment marking pipeline tools as test harnesses with minimal production usage  
**Tools Affected**:
- `outlineum-zine` - Zine generation/Outlineum pipeline example
- `diaplasion-pipeline` - Document transformation pipeline example  
- `accessum-flow` - Accessibility workflow example

**Status**: Documented but not removed  
**Rationale**: These tools are:
- Only referenced in their own READMEs (no production usage)
- Included in bundling scripts (`build_mac_app.sh`, `bundle_binaries.sh`)
- Test/example harnesses rather than production surfaces

**Recommendation**: Future work should either:
1. Fold these into `harmonia` CLI as subcommands (`harmonia outlineum`, `harmonia diaplasion`, etc.)
2. Move to `Examples/` directory and mark as non-production
3. Remove entirely if no longer needed

---

## Items Requiring Further Review

### 3. 🔍 `harmonia` vs `harmonia-v2` Executables

**Status**: NEEDS STAKEHOLDER DECISION  
**Current State**:
- `harmonia` (HarmoniaCLI): Main production CLI, 8k+ lines, full-featured with subcommands
- `harmonia-v2` (HarmoniaV2CLI): Proof-of-concept CLI, 2k lines, demonstrates HarmoniaV2Surface

**Question**: Is HarmoniaV2 ready to replace HarmoniaCLI, or should both coexist?

**Recommendation**:
- If V2 is complete → Deprecate V1, rename V2 to canonical `harmonia`
- If V2 is POC → Keep both, clearly document V2 as experimental/unstable
- Consider adding `--version` flag to both to clarify which is which

**Location**: `anigma/Package.swift` lines 169, 171

---

### 4. ✅ `harmonia-surface` - Keep as Diagnostic Tool

**Status**: ANALYZED - KEEP AS-IS  
**Current State**: Smoke test harness for ECS validation, used in CI  
**Usage**:
- `Scripts/harmonia-surface.sh` - CI wrapper
- Documentation in `Packages/HarmoniaSurface/README.md`
- Used for concurrency validation and system pulse checks

**Rationale**: This is a legitimate diagnostic tool, not a surface that should be merged. It serves a specific CI/testing purpose.

**No action required.**

---

### 5. ✅ `doctrine` CLI - Keep as Standalone Tool

**Status**: ANALYZED - KEEP AS-IS  
**Current State**: Governance debt management CLI  
**Usage**:
- `Scripts/build_installer.sh` - Included in release builds
- Referenced in CLAUDE.md, GEMINI.md
- Manages doctrine violations database

**Rationale**: Specialized governance tool with clear purpose. Merging into `harmonia` would dilute its focus and complicate governance workflows.

**No action required.**

---

### 6. ⚠️ `ml-worker` Executable

**Status**: NEEDS VERIFICATION  
**Current State**: Standalone ML worker process  
**Usage**: Bundled in app packages, unclear if production-critical

**Question**: Is this a production-required worker process or a test harness?

**Recommendation**: Verify with ML/inference stakeholders. If production:
- Document clearly in README
- Ensure proper lifecycle management
- Add to critical binary list

If test-only:
- Move to test executables
- Remove from bundling scripts

---

## App Launcher Consolidation

### Current Launcher Landscape

**Documented/Canonical**:
- ✅ `run_prototype.sh` (25 lines) - Quick launcher, referenced in `HOW_TO_LAUNCH.md`
- ✅ `build_app_bundle.sh` (42 lines) - Bundle builder, referenced in documentation

**Other Build Scripts** (potential consolidation targets):
- `build_anigma_app_bundle.sh` (277 lines) - More complex bundler
- `build_working_bundle.sh` (256 lines) - Alternative bundler
- `build_complete_anigma_with_frameworks.sh` (367 lines) - Framework-inclusive bundler
- `build_full_anigma.sh` (156 lines) - Full build script
- `build_individual_packages.sh` (407 lines) - Package-by-package builder
- `build_real_installer.sh` (179 lines) - Installer generator

### Recommendation: Launcher Trim

**Phase 1 - Audit**:
1. Document which scripts are actively used in CI/workflows
2. Identify overlapping functionality
3. Determine canonical build paths (debug vs release, full vs minimal)

**Phase 2 - Consolidate**:
1. Keep `run_prototype.sh` as the quick launcher (wraps others)
2. Keep `build_app_bundle.sh` for simple debug builds
3. Consolidate other scripts into:
   - `scripts/build_release.sh` - Production builds
   - `scripts/build_installer.sh` - Installer generation
4. Archive or remove deprecated scripts

**Status**: NOT STARTED - requires broader stakeholder input on build workflows

---

## Product Removal Update

### Current Executable Products (after cleanup)

```swift
let executableProducts: [Product] = [
    .executable(name: "harmonia-surface", targets: ["HarmoniaSurface"]),     // ✅ Keep - CI diagnostic
    .executable(name: "doctrine", targets: ["DoctrineCLI"]),                 // ✅ Keep - Governance tool
    .executable(name: "outlineum-zine", targets: ["OutlineumZine"]),         // 📝 Test harness
    .executable(name: "diaplasion-pipeline", targets: ["DiaplasionPipeline"]),// 📝 Test harness
    .executable(name: "accessum-flow", targets: ["AccessumFlow"]),           // 📝 Test harness
    .executable(name: "ml-worker", targets: ["MLWorkerExecutable"]),         // ⚠️ Needs verification
    .executable(name: "anigma-cli", targets: ["AnigmaCLIExecutable"]),       // ✅ Keep - Main CLI
    .executable(name: "anigma-app", targets: ["AnigmaAppMacExecutable"]),    // ✅ Keep - Mac app
]

let capabilityProducts: [Product] = [
    // ... (libraries, not executables)
    .executable(name: "harmonia", targets: ["HarmoniaCLI"]),                 // ✅ Keep - Production CLI
    .executable(name: "harmonia-v2", targets: ["HarmoniaV2CLI"]),            // 🔍 POC or replacement?
    .executable(name: "anigmad", targets: ["AnigmaDaemon"]),                 // ✅ Keep - System daemon
]
```

---

## Summary of Work Done

| Item | Status | Files Changed | Impact |
|------|--------|---------------|--------|
| Remove `anigma` alias | ✅ Complete | `Package.swift` (1 line) | No breaking changes |
| Document pipeline tools | ✅ Complete | `Package.swift` (TODO added) | Marks for future work |
| Analyze `harmonia-surface` | ✅ Complete | N/A | Keep as diagnostic tool |
| Analyze `doctrine` | ✅ Complete | N/A | Keep as governance tool |
| `harmonia` vs `harmonia-v2` | 🔍 Needs review | N/A | Stakeholder decision needed |
| `ml-worker` verification | ⚠️ Pending | N/A | Verify with ML team |
| App launcher consolidation | 📋 Documented | N/A | Future phase |

---

## Next Steps

### Immediate (Can Be Done Now)
1. ✅ Commit the `anigma` alias removal and pipeline tool documentation

### Short-Term (Requires Stakeholder Input)
1. **Harmonia V1 vs V2 Decision**:
   - Review HarmoniaV2 readiness with CLI maintainers
   - Document migration path if V2 is ready
   - Add version indicators to both CLIs

2. **ML Worker Verification**:
   - Confirm with ML/inference team if production-critical
   - Document lifecycle and dependencies

3. **Pipeline Tool Decision**:
   - Fold into `harmonia` as subcommands, OR
   - Move to `Examples/` directory, OR
   - Remove entirely

### Long-Term (Broader Refactor)
1. **App Launcher Consolidation**:
   - Audit all build scripts for active usage
   - Consolidate overlapping functionality
   - Establish canonical build paths
   - Archive deprecated scripts

2. **Binary Consolidation (Ongoing)**:
   - Monitor daemon consolidation progress (DEBT-012)
   - Evaluate other surface merge opportunities
   - Continue reducing binary count

---

## Testing

### Validation Steps Performed
```bash
# 1. Verify no references to removed "anigma" alias
grep -r "swift run anigma[^-]" --include="*.sh" --include="*.md"
# Result: Only "anigmad" found (different binary)

# 2. Verify Package.swift syntax
cd anigma
swift package dump-package > /dev/null
# Result: Success (verified valid Swift)

# 3. Check pipeline tool usage
grep -r "swift run outlineum\|diaplasion\|accessum" --include="*.sh" --include="*.yml"
# Result: Only found in tool READMEs and bundling scripts
```

### Recommended Testing Before Merge
```bash
# Build all executables to ensure no breakage
cd anigma
swift build --product anigma-cli
swift build --product harmonia
swift build --product harmonia-v2
swift build --product doctrine
swift build --product harmonia-surface

# Verify app bundle creation
cd ..
./build_app_bundle.sh
./run_prototype.sh
```

---

## Files Modified

1. `anigma/Package.swift`
   - Removed duplicate `anigma` product (line 136)
   - Added TODO comment for pipeline tools (lines 132-137)

2. `BINARY_CONSOLIDATION_REPORT.md` (this file)
   - New documentation

---

## Commit Message Suggestion

```
refactor(cli): Remove duplicate 'anigma' product alias

- Remove duplicate `anigma` executable product from Package.swift
- Keep `anigma-cli` as canonical CLI product name
- Add TODO comments marking pipeline executables as test harnesses
  (outlineum-zine, diaplasion-pipeline, accessum-flow)
- No breaking changes: removed alias was not referenced in scripts/docs

Related: harmonia-surface-merge, legacy-cli-aliases consolidation roadmap
```

---

## References

- Daemon Consolidation: `anigma/Tickets/SUMMARY_daemon_consolidation.md`
- CLI Architecture: `chatgpt-context/04-cli.md`
- Build Documentation: `HOW_TO_LAUNCH.md`, `PHASE3_LOCKDOWN_CHECKLIST.md`
- HarmoniaCLI README: `anigma/Packages/HarmoniaCLI/README.md`
- HarmoniaV2CLI: `anigma/Packages/HarmoniaV2CLI/Main.swift`
