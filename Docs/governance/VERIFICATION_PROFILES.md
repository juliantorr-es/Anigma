# Verification Profiles

**Doc ID:** VERIFICATION_PROFILES  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-02  
**Related:** Docs/governance/TD_SOURCE_OF_TRUTH_DOCTRINE.md, Docs/governance/TD_CONTEXT_GARBAGE_COLLECTION.md

---

## Purpose

Verification profiles define **standardized command sets** for validating work across different domains (governance, runtime, documentation, publication). They ensure that:

1. **Agents use consistent validation** - No ad-hoc command invention
2. **Tool availability is explicit** - Required vs optional tools are documented
3. **Proof recording is structured** - Command results link to proof artifacts
4. **Context is preserved** - Future agents/humans can reproduce validation

## Why Verification Profiles Exist

Without verification profiles:
- Agents invent different validation commands for similar tasks
- Tool dependencies are implicit and undiscoverable
- Proof artifacts lack reproducible validation steps
- Task completion criteria are ambiguous
- Cross-task validation is inconsistent

With verification profiles:
- Every task references its validation profile
- Tool requirements are explicit and checkable
- Proof artifacts include structured command/result pairs
- Agents can auto-select appropriate profiles
- Humans can understand what validation was performed

---

## Profile Selection

### How Agents Select Profiles

1. **By task type**: Tasks with `type: task` or `type: epic` inherit from parent or use default
2. **By lane**: Tasks in specific lanes use lane-appropriate profiles
3. **By explicit reference**: Tasks with `verification_profiles: [profile-id]` use those profiles
4. **By overrides**: Tasks can override with `verification_overrides` for task-specific commands

### Profile Inheritance

```
Epic Level -> Lane Default -> Type Default -> Global Default
```

Example: A task in `daemon-runtime-isolation` lane with no explicit profiles:
- Inherits: `p0-daemon-runtime` (lane-specific)
- Falls back to: `swift-runtime` (runtime domain)
- Falls back to: `governance` (always required)

### Profile Combination

When multiple profiles are referenced:
1. All required tools from all profiles must be available
2. All commands from all profiles are collected
3. Commands are deduplicated by command signature (not arguments)
4. Order: Explicit references first, then inherited

---

## Tool Classification

### Required Tools

Tools that **MUST** be present for profile validation to succeed. Missing required tools = **ERROR**.

| Tool | Purpose | Default Required For |
|------|---------|---------------------|
| `python3` | Script execution, validation | All profiles |
| `git` | Version control, history checks | All profiles |
| `td` | Local task queue management | docs-td, docs-artifacts |
| `swift` | Swift compilation | swift-runtime, swift-lint-format |

### Optional Tools

Tools that **MAY** be used if available. Missing optional tools = **WARNING** (validation continues with tool-specific commands skipped).

| Tool | Purpose | Used By |
|------|---------|---------|
| `swiftlint` | Swift style linting | swift-lint-format |
| `swift-format` | Swift code formatting | swift-lint-format |
| `rg` | Ripgrep (fast searching) | governance, repo-hygiene |
| `fd` | Fast file finder | governance, repo-hygiene |
| `jq` | JSON processor | docs-artifacts, publication |
| `yq` | YAML processor | docs-artifacts, docs-td |
| `dot` | Graphviz rendering | docs-artifacts (diagrams) |
| `mermaid-cli` | Mermaid diagram rendering | docs-artifacts (diagrams) |
| `likec4` | C4 architecture rendering (PRIMARY) | docs-artifacts, architecture-diagrams |
| `structurizr` | C4 architecture rendering (LEGACY) | docs-artifacts (diagrams) |
| `git-filter-repo` | Git history filtering | history-excision |

### Tool Availability Checking

The validator (`Scripts/validate_verification_profiles.py`) checks:
```bash
# Required tools must exist
which python3 git td swift  # Example for swift-runtime profile

# Optional tools - warn if missing
which swiftlint swift-format  # Example for swift-lint-format profile
```

---

## Profile Definitions

### 1. Governance Profile (`governance`)

**Purpose:** Architecture and code governance validation

**Required Tools:** python3, git, rg, fd

**Optional Tools:** jq, yq

**Baseline Commands:**
```bash
# Tier validation
python3 Scripts/validate_tiers.py anigma/

# Cycle detection
python3 Scripts/validate_no_cycles.py .build/anigma-package.json

# Exported import validation
python3 Scripts/validate_exported_imports.py
```

**When to Use:** All tasks that affect architecture or cross-module dependencies

**Proof Required:** Validation output logs, exit codes

**Expected Outputs:** All validators exit 0, no violations detected

**Failure Policy:** Block merge/PR if any governance validator fails

---

### 2. Swift Runtime Profile (`swift-runtime`)

**Purpose:** Swift compilation and runtime validation

**Required Tools:** python3, git, swift

**Optional Tools:** swiftlint, swift-format

**Baseline Commands:**
```bash
# Clean build
swift build

# Run tests
swift test

# Build specific target
swift build -c release
```

**When to Use:** Tasks affecting Swift source code, Package.swift, or build configuration

**Proof Required:** Build logs, test results

**Expected Outputs:** Build succeeds, tests pass

**Failure Policy:** Block if build fails; warn if tests fail (some tasks may not have full test coverage)

---

### 3. Swift Lint & Format Profile (`swift-lint-format`)

**Purpose:** Code style and formatting compliance

**Required Tools:** python3, git, swift

**Optional Tools:** swiftlint, swift-format

**Baseline Commands:**
```bash
# Lint check (do not weaken rules)
swiftlint lint --strict anigma/ 2>/dev/null || true

# Format check
swift-format lint -r anigma/ 2>/dev/null || true

# Format apply (in fix mode only)
# swift-format format -r anigma/
```

**When to Use:** Tasks involving source code changes

**Proof Required:** Lint/format output, diff if formatting applied

**Expected Outputs:** No lint warnings, code is formatted

**Failure Policy:** 
- **Report** lint/format issues (do not auto-fix without explicit task)
- **Do not hide failures** by weakening rules
- **Do not fabricate** lint passes if tools not installed

---

### 4. Docs & TD Profile (`docs-td`)

**Purpose:** Documentation and TD system validation

**Required Tools:** python3, git, td, yq

**Optional Tools:** jq

**Baseline Commands:**
```bash
# TD folder system validation
python3 Scripts/validate_td_folder_system.py

# TD docs sync validation
python3 Scripts/validate_td_docs_sync.py

# TD bootstrap (dry run)
python3 Scripts/td_bootstrap_from_docs.py --emit-commands

# Descriptor generation (dry run)
python3 Scripts/generate_td_descriptors.py --dry-run
```

**When to Use:** Tasks in `documentation-infrastructure` lane or affecting Docs/td/

**Proof Required:** Validation reports, descriptor counts

**Expected Outputs:** All validations pass, descriptors generated correctly

**Failure Policy:** Block if structure validation fails

---

### 5. Docs Artifacts Profile (`docs-artifacts`)

**Purpose:** Documentation-as-code artifact validation

**Required Tools:** python3, git

**Optional Tools:** jq, yq, dot, mermaid-cli, likec4, structurizr (legacy)

**Baseline Commands:**
```bash
# No 0-byte files in critical directories
find Docs/{schemas,manifests,diagrams} -type f -size 0 | wc -l | grep -q "^0$"

# All JSON schemas parse as valid JSON
for f in Docs/schemas/*.json; do python3 -m json.tool "$f" > /dev/null; done

# All YAML manifests parse as valid YAML
for f in Docs/manifests/*.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done

# LikeC4 model validation (if likec4 installed)
likec4 build Docs/diagrams/likec4 -o /tmp/anigma-likec4 2>/dev/null || true

# Mermaid syntax check (if mermaid-cli installed)
mmdc -i Docs/diagrams/mermaid/*.mmd --check 2>/dev/null || true

# Graphviz syntax check (if dot installed)
for f in Docs/diagrams/graphviz/*.dot; do dot -Tpng "$f" -o /tmp/test.png 2>&1 | head -1; done
```

**When to Use:** Tasks in `documentation-infrastructure` lane or affecting documentation artifacts

**Proof Required:** Artifact inventory, validation results

**Expected Outputs:** All artifacts valid, no parse errors

**Failure Policy:** Block on parse errors; warn on missing optional tools

---

### 6. Repo Hygiene Profile (`repo-hygiene`)

**Purpose:** Repository cleanliness and file health

**Required Tools:** python3, git, rg, fd

**Optional Tools:** git-filter-repo

**Baseline Commands:**
```bash
# No untracked files in critical paths
git status --porcelain | grep -q "^??" && echo "Untracked files found" || true

# No .DS_Store or __MACOSX in git
git ls-files | grep -q -E "\.DS_Store|__MACOSX" && echo "Forbidden files tracked" || true

# No large files (>100MB) in history
git log --find-object --all -e '(.*\.(bin|dll|so|dylib|exe|app|pkg|dmg|iso)$)' | wc -l | grep -q "^0$"

# Check for common unwanted patterns
rg --files | rg -E '\.(pyc|swp|log|tmp|bak)$' | wc -l | grep -q "^0$"
```

**When to Use:** Tasks affecting repository structure or cleanup

**Proof Required:** Hygiene scan results

**Expected Outputs:** No forbidden files, no large binaries in history

**Failure Policy:** Block on forbidden files; warn on hygiene issues

---

### 7. Publication Profile (`publication`)

**Purpose:** Public GitHub publication readiness

**Required Tools:** python3, git

**Optional Tools:** jq, yq

**Baseline Commands:**
```bash
# Publication checklist validation
python3 -c "import yaml; yaml.safe_load(open('Docs/manifests/publication-checklist.yaml'))" && echo "Checklist valid"

# Check required publication files
test -f LICENSE || echo "Missing LICENSE"
test -f README.md || echo "Missing README"
test -f .gitignore || echo "Missing .gitignore"

# Build verification
swift build 2>&1 | tail -5
```

**When to Use:** Tasks in `publication-cleanup` lane

**Proof Required:** Publication checklist status, build verification

**Expected Outputs:** All required files present, build succeeds

**Failure Policy:** Block on missing required files; warn on build issues

---

### 8. History Excision Profile (`history-excision`)

**Purpose:** Git history cleanup before publication

**Required Tools:** python3, git

**Optional Tools:** git-filter-repo, BFG

**Baseline Commands:**
```bash
# List large objects (>100MB)
git log --find-object --all | head -20

# Check pack integrity
git verify-pack -v .git/objects/pack/*.idx 2>&1 | tail -3

# Large file audit
git log --pretty=format:"%h %s" --find-object --all | head -10

# Optional: Actual history rewrite (requires git-filter-repo)
# git-filter-repo --invert-paths --path-glob '*.dll' --force
```

**When to Use:** Tasks in `publication-cleanup` lane, specifically history cleanup

**Proof Required:** Before/after history audit, excision log

**Expected Outputs:** No large forbidden objects, pack integrity maintained

**Failure Policy:** Warn if large objects found; block on pack corruption

---

### 9. P0 Media Substrate Profile (`p0-media-substrate`)

**Purpose:** MediaCore and materialization gate validation

**Required Tools:** python3, swift

**Optional Tools:** swiftlint, rg

**Baseline Commands:**
```bash
# MediaCore tests
swift test --filter MediaCore 2>&1 | tail -10

# Materialization gate tests
swift test --filter MaterializationGate 2>&1 | tail -10

# Zero-copy path validation
rg "MaterializationGate" anigma/Sources/ | wc -l

# Media primitive type checks
rg "struct.*Media" anigma/Packages/MediaCore/Sources/ | head -10
```

**When to Use:** Tasks in `p0-critical-path` lane affecting MediaCore

**Proof Required:** Test results, materialization gate status

**Expected Outputs:** MediaCore tests pass, materialization gate enforced

**Failure Policy:** Block on MediaCore test failures

---

### 10. P0 Daemon Runtime Profile (`p0-daemon-runtime`)

**Purpose:** Subprocess pooling and daemon runtime validation

**Required Tools:** python3, swift

**Optional Tools:** swiftlint, rg

**Baseline Commands:**
```bash
# SubprocessPooling tests
swift test --filter SubprocessPooling 2>&1 | tail -10

# Worker pool lifecycle checks
swift test --filter "MLWorkerPool|MCPWorkerPool" 2>&1 | tail -10

# Process spawning validation
rg "ProcessPool|SubprocessWorker" anigma/Packages/SubprocessPooling/Sources/ | wc -l

# IPC validation
rg "UnixDomainSocketIPC" anigma/Packages/SubprocessPooling/Sources/ | wc -l
```

**When to Use:** Tasks in `daemon-runtime-isolation` lane, specifically p0-004 subtasks

**Proof Required:** Test results, pool lifecycle verification

**Expected Outputs:** SubprocessPooling tests pass, worker pools functional

**Failure Policy:** Block if critical pool tests fail

---

## Recording Command Results in Proofs

### Proof Artifact Structure

Every task proof artifact (`Docs/proofs/{task-id}-*.md`) should include:

```markdown
## Verification

### Profile: <profile-id>

**Commands Executed:**
```bash
command 1
command 2
```

**Results:**
- Command 1: EXIT CODE 0, Output: [relevant excerpt]
- Command 2: EXIT CODE 0, Output: [relevant excerpt]

**Tool Availability:**
- python3: ✅ Available (v3.x.x)
- git: ✅ Available (v2.x.x)
- swiftlint: ⚠️  Not installed (optional)
- dot: ❌ Not installed (optional, diagram validation skipped)
```

### Missing Optional Tools

When optional tools are missing, document in proof:

```markdown
**Missing Optional Tools:**
- dot: Not installed, Graphviz diagram validation skipped
- mermaid-cli: Not installed, Mermaid rendering skipped
```

Do NOT claim validation passed if required tools are missing.

---

## Handling Missing Optional Tools

1. **Check for tool**: Use `which <tool>` or `command -v <tool>`
2. **Report absence**: Add warning to proof artifact
3. **Skip tool-specific commands**: Do not execute commands requiring missing optional tools
4. **Do not fail validation**: Missing optional tools do not block task completion
5. **Document in manifest**: Update `verification-profiles.yaml` with tool availability

---

## SwiftLint and swift-format Integration

### Do NOT:
- Weaken lint rules to make validation pass
- Auto-format code without explicit task approval
- Suppress lint warnings in validation output
- Claim lint passes if swiftlint not installed

### DO:
- Report lint warnings explicitly
- Include `|| true` to prevent command failure from blocking entire validation
- Document lint configuration in proofs
- Use `--strict` flag when available

Example:
```bash
# Lint check - reports warnings but doesn't fail
swiftlint lint --strict anigma/ 2>/dev/null || true

# Format check - same
swift-format lint -r anigma/ 2>/dev/null || true
```

---

## Focused Tests vs Full Suite

### Use Focused Tests When:
- Working on a specific module (e.g., `SubprocessPooling`)
- Validating a specific feature (e.g., `MaterializationGate`)
- Quick feedback loop during development

### Use Full Suite When:
- Pre-merge/PR validation
- Lane completion verification
- Publication readiness checks

### Recording:
```markdown
# Full suite: swift test (55/55 passed)
# Focused: swift test --filter SubprocessPooling (12/12 passed)
```

---

### 11. Architecture Diagrams Profile (`architecture-diagrams`)

**Purpose:** Architecture diagram validation using LikeC4 as primary C4 modeling tool

**Required Tools:** python3, git

**Optional Tools:** likec4, dot, mermaid-cli

**Baseline Commands:**
```bash
# Validate LikeC4 architecture model
likec4 build Docs/diagrams/likec4 -o /tmp/anigma-likec4-diagrams

# Check LikeC4 CLI is available
likec4 --version

# Verify at least one LikeC4 model exists
test -f Docs/diagrams/likec4/anigma.c4 && echo "OK" || echo "MISSING"

# Optional: Check Graphviz (used by LikeC4 for layout)
dot -V 2>/dev/null || true

# Optional: Check Mermaid
mmdc --version 2>/dev/null || true
```

**When to Use:** Tasks in `architecture-governance` lane or affecting architecture diagrams

**Proof Required:** LikeC4 build output, diagram validation report

**Expected Outputs:** All diagrams parse successfully, LikeC4 build succeeds

**Failure Policy:** Block on diagram parse errors; warn on missing optional tools

---

## Profile Assignment Guide

| Task Lane | Primary Profile | Secondary Profiles |
|-----------|----------------|-------------------|
| p0-critical-path | swift-runtime, governance | p0-media-substrate |
| daemon-runtime-isolation | swift-runtime, governance | p0-daemon-runtime |
| architecture-governance | governance, architecture-diagrams | swift-runtime |
| documentation-infrastructure | docs-td, docs-artifacts | governance |
| publication-cleanup | publication | history-excision, repo-hygiene |

---

## Version History

| Date | Change | Owner |
|------|--------|-------|
| 2025-01-15 | Added architecture-diagrams profile, replaced structurizr with likec4 as primary | Architecture Team |
| 2026-05-02 | Initial creation | Architecture Team |
