# Repository Hygiene Doctrine

**Document ID**: REPO-HYGIENE-001  
**Version**: 1.0.0  
**Last Updated**: 2026-05-03  
**Owner**: Architecture Team  

---

## Purpose

This document establishes the rules for where files may be created in the Anigma repository. The repository root is reserved for **source/build entrypoints only**. All operational artifacts, documentation, and generated outputs must be placed in their designated directories.

---

## Core Rule

**REPO ROOT IS FOR SOURCE/BUILD ENTRYPOINTS ONLY.**

Do not create any of the following at the repository root level:
- TD review, completion, or handoff artifacts
- Scratch notes, temporary files, or work-in-progress
- Generated reports, logs, or build outputs
- Documentation artifacts
- Proof documents

---

## Canonical Locations

### TD Artifacts

| Artifact Type | Location | Example |
|-------------|----------|---------|
| TD review results (PASSED/REJECTED) | `Docs/td/reviews/<td-id>/` | `Docs/td/reviews/td-d65648/td-d65648-review-PASSED.md` |
| TD completion/handoff summaries | `Docs/td/handoffs/<td-id>/` | `Docs/td/handoffs/td-d65648/td-d65648-completion-summary.md` |
| TD task packages | `Docs/td/{ready,active,blocked,done,archived}/<task-slug>/` | `Docs/td/ready/td-123456/` |

### Documentation

| Document Type | Location | Example |
|--------------|----------|---------|
| Proof artifacts | `Docs/proofs/` | `Docs/proofs/td-d65648-receiptsigner-extraction-proof.md` |
| Architecture decisions | `Docs/ADR/` | `Docs/ADR/0006-three-tier-runtime-architecture.md` |
| Schemas | `Docs/schemas/` | `Docs/schemas/documentation-artifacts.schema.json` |
| Governance documents | `Docs/governance/` | `Docs/governance/TESTING_DOCTRINE.md` |
| Roadmap indexes | `Docs/roadmap/` | `Docs/roadmap/ROADMAP_INDEX.md` |
| Architecture indexes | `Docs/architecture/` | `Docs/architecture/DOCTRINE_INDEX.md` |

### Build Artifacts

| Artifact Type | Location | |
|-------------|----------|-|
| Swift build outputs | `.build/` | |
| Derived files | `.build/arm64-apple-macosx/debug/` | |
| Index databases | `.build/build.db` | |

### Temporary/Scratch Files

| Artifact Type | Location | |
|-------------|----------|-|
| Agent scratch | `.build/anigma-agent-artifacts/` | |
| IDE temporary | `.idea/`, `.vscode/` | |
| System temporary | `/tmp/`, system temp dirs | |

---

## Allowed at Repository Root

The following file/directory types **ARE PERMITTED** at repository root:

### Source/Build Entrypoints
- `Package.swift` - Swift Package Manager manifest
- `anigma/` - Primary project directory
- `Sources/` - Legacy source directory (if applicable)
- `Tests/` - Test directory
- `Packages/` - External package dependencies
- `Vendor/` - Vendored dependencies
- `.swiftpm/` - Swift Package Manager configuration
- `*.sh` - Build/CI scripts (top-level only)
- `*.py` - Build/validation scripts (top-level only)
- `*.json` - Configuration files (DEPS.toml, dependencies.json, etc.)
- `Makefile` - Build orchestration

### Project Metadata
- `.git/` - Git repository metadata
- `.github/` - GitHub configuration
- `.gitignore` - Git ignore rules
- `LICENSE` - Project license
- `README.md` - Project readme
- `CONTRIBUTING.md` - Contribution guidelines
- `COMMERCIAL-LICENSE.md` - Commercial license terms
- `*.md` - Top-level project documentation (not TD artifacts)

### IDE/Tool Configuration
- `.vscode/` - VS Code configuration
- `.idea/` - IntelliJ configuration
- `.DS_Store` - macOS metadata (ignored)
- `.mcp.json` - Model Context Protocol configuration
- `CLAUDE.md` - Claude codebase instructions
- `AGENTS.md` - Agent instructions

### Build/Validation Outputs (Ignored)
- `*.xcresult` - Xcode build results
- `*.txt` - Build logs/outputs (if at root)
- `.build/` - Swift build directory

---

## Forbidden at Repository Root

The following **MUST NOT** be created at repository root:

### TD Operational Artifacts
- ❌ `td-*.md` - Any TD-related markdown files
- ❌ `*review*.md` - Review acceptance/rejection documents
- ❌ `*completion*.md` - Completion summaries
- ❌ `*handoff*.md` - Handoff notes
- ❌ `*proof-*.md` - Proof documents (go to `Docs/proofs/`)

### Documentation
- ❌ Any documentation that belongs in `Docs/`
- ❌ Architecture documents
- ❌ Governance documents
- ❌ Research notes
- ❌ Meeting minutes

### Generated Files
- ❌ Build outputs that belong in `.build/`
- ❌ Log files
- ❌ Temporary cache files
- ❌ Compiled outputs

### Scratch/Work Files
- ❌ Temporary notes
- ❌ Work-in-progress documents
- ❌ Debug outputs

---

## Agent-Specific Rules

### For TD-Related Files

**NEVER** place TD review, completion, or handoff artifacts in repository root.

**USE** these locations instead:
- TD review results → `Docs/td/reviews/<td-id>/`
- TD handoff/completion → `Docs/td/handoffs/<td-id>/`
- Formal proofs → `Docs/proofs/`
- TD task packages → `Docs/td/{ready,active,blocked,done}/<task-slug>/`

### For Documentation

**NEVER** place documentation at repository root.

**USE** `Docs/` with appropriate subdirectories:
- Architecture → `Docs/architecture/`
- Governance → `Docs/governance/`
- Proofs → `Docs/proofs/`
- ADRs → `Docs/ADR/`
- TD artifacts → `Docs/td/`

### For Generated Outputs

**NEVER** place generated files at repository root.

**USE** appropriate locations:
- Swift build outputs → `.build/`
- Agent artifacts → `.build/anigma-agent-artifacts/`
- Temporary files → System temp directories

---

## Build Status Language

Agents **MUST** use precise language when describing build results. A build that returns exit code 0 is not necessarily "clean" - it may have warnings.

### Terminology

| Status | Definition | Usage |
|--------|------------|-------|
| **FAILED** | Build command returned nonzero exit code | Build did not complete |
| **PASSED** | Build command returned exit code 0, but warnings were not checked or may be present | Build completed, warning status unknown |
| **CLEAN** | Build command returned exit code 0 AND emitted zero warnings | Build completed without warnings |
| **CONTAMINATED** | Build command returned exit code 0 but emitted one or more warnings | Build completed but has warnings |

### Rules

1. Agents **MUST NOT** claim "clean build" unless warning output was captured and checked
2. Agents **MUST NOT** use "build successful" as final proof language (ambiguous)
3. If warnings are present, the build **MUST** be called CONTAMINATED, even if it passed
4. If warnings were not checked, say "PASSED; warning status unknown"
5. Proof artifacts **MUST** record: command, exit code, whether warnings were scanned, warning count if available, and final status

### Accepted Proof Wording

| Scenario | Accepted Language | Forbidden Language |
|----------|------------------|-------------------|
| Warnings not checked | "Build PASSED; warning status unknown." | "Build successful." |
| Warnings present | "Build CONTAMINATED: exit code 0, N warnings detected." | "Build successful.", "No errors." |
| Zero warnings | "Build CLEAN: exit code 0, zero warnings detected." | "Build clean" without scan |
| Nonzero exit code | "Build FAILED." | "Build successful." |

### Build Status Classification Script

```bash
#!/bin/bash
set -o pipefail

TARGET="AnigmaFoundation"
LOG_FILE=".build/anigma-build-${TARGET}.log"

swift build --target ${TARGET} 2>&1 | tee "${LOG_FILE}"
EXIT_CODE=$?
WARNING_COUNT=$(grep -ic "warning:" "${LOG_FILE}" || true)

echo "exit_code=${EXIT_CODE}"
echo "warning_count=${WARNING_COUNT}"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "BUILD_STATUS=FAILED"
elif [ "$WARNING_COUNT" -gt 0 ]; then
  echo "BUILD_STATUS=CONTAMINATED"
else
  echo "BUILD_STATUS=CLEAN"
fi
```

---

## Validation Commands

### Check for root-level TD clutter
```bash
find . -maxdepth 1 -type f \( -name 'td-*.md' -o -name '*review*.md' -o -name '*completion*.md' -o -name '*handoff*.md' \) -print
# Expected: (empty)
```

### Check for root-level proof clutter
```bash
find . -maxdepth 1 -type f -name '*proof*.md' -print
# Expected: (empty)
```

### Verify all TD artifacts are under Docs/td/
```bash
find Docs/td -name 'td-*.md' -print
# Expected: List of all TD artifacts
```

---

## Enforcement

### Pre-commit Hook

A pre-commit hook **SHOULD** reject commits that add TD operational artifacts to repository root:

```bash
#!/bin/sh
# Check for TD artifacts at root
if git diff --cached --name-only | grep -E '^td-.*\.md$|^.*review.*\.md$|^.*completion.*\.md$|^.*handoff.*\.md$'; then
  echo "ERROR: TD operational artifacts cannot be committed to repository root."
  echo "Use Docs/td/reviews/, Docs/td/handoffs/, or Docs/proofs/ instead."
  exit 1
fi
```

### CI Validation

CI **SHOULD** fail builds where TD artifacts exist at root level:

```yaml
- name: Check repo hygiene
  run: |
    ROOT_TD_FILES=$(find . -maxdepth 1 -type f \( -name 'td-*.md' -o -name '*review*.md' -o -name '*completion*.md' -o -name '*handoff*.md' \) -print)
    if [ -n "$ROOT_TD_FILES" ]; then
      echo "ERROR: TD artifacts found at root level: $ROOT_TD_FILES"
      exit 1
    fi
```

---

## Related Proofs

- [Repo Root TD Artifact Cleanup](Docs/proofs/repo-root-td-artifact-cleanup.md) - Initial cleanup of root-level TD artifacts

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-05-03 | Mistral Vibe | Initial version - formalizes repo hygiene rules |
