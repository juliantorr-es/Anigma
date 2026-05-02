# Historical TD Recovery

> **Status**: Archived  
> **Purpose**: Context recovery from the TD database reset of 2026-05-02  
> **Do NOT Fabricate**: Only tasks grounded in documentation can be recovered

---

## What Happened

On **2026-05-02**, the local TD database was found to be empty (0 rows) during execution of this P1 lane. This was discovered while attempting to populate TD entries for the `p1-td-source-of-truth-recovery` epic.

**Discovery Steps:**
1. Ran `td list --all` → "No issues found"
2. Ran `td list --json` → `null`
3. Checked for database file → Not found in expected locations
4. Confirmed `td` CLI was functional and could create new tasks

## TD Source-of-Truth Doctrine Established

As a result of this incident, we established the following **canonical doctrine**:

| Principle | Detail |
|-----------|--------|
| **Docs/ is the source of truth** | All task definitions, acceptance criteria, and proofs must exist in version-controlled documentation |
| **TD is the executable queue** | The local `td` CLI database is derived from Docs/ and can be rebuilt at any time |
| **Registry is canonical** | `Docs/td/td-task-registry.yaml` defines all active tasks |
| **Bootstrapable** | `python3 Scripts/td_bootstrap_from_docs.py --apply` reconstructs TD from Docs/ |
| **Validatable** | `python3 Scripts/validate_td_docs_sync.py` verifies Docs/td ↔ TD synchronization |

## Grounded Sources for Recovery

If recovering historical tasks, **ONLY** use the following grounded sources:

### ✅ Approved Sources

| Source | Location | Trust Level |
|--------|----------|-------------|
| Roadmap documents | `Docs/roadmaps/` | HIGH |
| P0 Critical Path | `Docs/P0_CRITICAL_PATH.md` | HIGH |
| Roadmap Index | `Docs/ROADMAP_INDEX.md` | HIGH |
| Architecture Doctrine | `Docs/architecture/DOCTRINE_INDEX.md` | HIGH |
| Proof artifacts | `Docs/proofs/` | HIGH |
| Reports | `Docs/reports/` | HIGH |
| Existing TD registry | `Docs/td/td-task-registry.yaml` | HIGH |
| Current README | `README.md` | MEDIUM |
| Known proof artifacts | Various locations | HIGH |
| Current project context | Active code, PRs | HIGH |

### ❌ Prohibited Sources

| Source | Why Prohibited |
|--------|---------------|
| AI memory of old TD tasks | Cannot be verified, prone to hallucination |
| Old TD database backups | If they exist, they may contradict Docs/ |
| Undocumented verbal requests | No audit trail |
| Assumptions about "what must have been" | Speculation, not evidence |

## Known Historical Context

The following information was provided in the project context, but the tasks themselves **do not exist in the current registry** and **do not have corresponding proof artifacts**:

### Previously Tracked (Pre-Reset)

- **Total old TD tasks**: 150+ (estimated from context mentioning "the previous TD database had 150+ tasks")
- **Recovery status**: NOT attempted - insufficient grounded evidence

### Known Historical Epics (From Context)

The following were mentioned in existing documentation but may not have descriptor files:

| Epic/Task | Mentioned In |
|----------|--------------|
| postgres-integration-environment | Context: "blocked/" directory example |
| github-publication-readiness | Context: "done/" directory example |
| repo-root-hygiene-migration | Context: "done/" directory example |

**Action Required**: If these tasks have corresponding proof artifacts in `Docs/proofs/`, they should be added to the registry and given descriptor files under the appropriate status directory.

## Recovery Process

To recover a historical task:

### ✅ Required

1. **Locate grounded evidence**
   - Find a corresponding proof file in `Docs/proofs/`
   - OR find the task in `Docs/ROADMAP_INDEX.md`
   - OR find the task in existing documentation

2. **Verify completion status**
   - Check if proof artifacts exist
   - Check if acceptance criteria can be validated

3. **Create descriptor files**
   ```bash
   # For an epic
   mkdir -p Docs/td/{status}/{epic-id}
   touch Docs/td/{status}/{epic-id}/epic.md
   touch Docs/td/{status}/{epic-id}/epic.yaml
   
   # For a task
   mkdir -p Docs/td/{status}/{task-id}
   touch Docs/td/{status}/{task-id}/task.md
   touch Docs/td/{status}/{task-id}/task.yaml
   ```

4. **Add to registry**
   - Add the task to `Docs/td/td-task-registry.yaml`
   - Include all known metadata (priority, lane, acceptance, proof, etc.)

5. **Validate**
   ```bash
   python3 Scripts/validate_td_docs_sync.py
   ```

6. **Create proof of recovery**
   - Document what was recovered and from where
   - Add to this README or create a separate recovery proof

### ❌ Prohibited

- Creating tasks without grounded evidence
- Marking tasks as complete without proof artifacts
- Inventing acceptance criteria
- Fabricating source_docs paths

## Current Recovery Status

| Category | Count | Notes |
|----------|-------|-------|
| Registry tasks (post-recovery) | 12 | All grounded in existing docs |
| Descriptor files created | 22 | From generator script |
| Historical tasks pending recovery | Unknown | Need to audit Docs/proofs/ and roadmaps |
| Old TD count (pre-reset) | 150+ | Not recoverable without evidence |

## How to Audit for More Historical Tasks

### Step 1: Audit Proof Artifacts

```bash
# List all proof files
find Docs/proofs -name "*.md" -type f | sort

# Identify proofs not referenced in registry
# (Manual: grep each proof path in td-task-registry.yaml)
```

### Step 2: Audit Roadmap Files

```bash
# List roadmap files
grep -r "^## " Docs/roadmaps/*.md | head -20

# Find task-like patterns
grep -roE "p0-[0-9]{3}|p1-[0-9a-z-]+" Docs/roadmaps/ | sort -u
```

### Step 3: Audit Report Files

```bash
# List reports
ls -la Docs/reports/*.md

# Check for task references
grep -roE "p0-[0-9]{3}|p1-[0-9a-z-]+" Docs/reports/ | sort -u
```

### Step 4: Cross-Reference

For each candidate task ID found:
1. Does it exist in `td-task-registry.yaml`? → Skip
2. Does it have a proof artifact? → Add with status based on proof
3. Does it appear in roadmap/report? → Add with status="new" or "ready"
4. No evidence? → Do not add

## Risk Classification

For recovered tasks, use the following risk classifications in the `risk` field:

| Risk Value | When to Use |
|------------|-------------|
| `recovered_from_partial_context` | Task ID found but description/acceptance incomplete |
| `recovered_from_proof_only` | Only proof artifact exists, no description |
| `recovered_from_roadmap` | Mentioned in roadmap but no proof |
| `historical_no_proof` | Mentioned in docs but no proof artifact exists |

## Recommended Actions

1. **Audit Docs/proofs/** for unreferenced proof files
2. **Audit Docs/roadmaps/** for mentioned task IDs
3. **For each grounded task**: Add to registry and create descriptor files
4. **For archived tasks**: Place in `Docs/td/archived/` with appropriate risk classification
5. **Update this README** with recovery progress

## Integration with Current System

All recovered tasks:
- Must have descriptor files (epic.md/epic.yaml or task.md/task.yaml)
- Must be added to `Docs/td/td-task-registry.yaml`
- Must have unique task IDs
- Must be placed in the correct status directory
- Must pass validation: `python3 Scripts/validate_td_docs_sync.py`

## Questions?

If unsure whether a task should be recovered:
- **Default to NOT recovering** (no false positives)
- Document the candidate in a `Docs/td/archived/candidates/` folder
- Add a note explaining the evidence and why it was NOT recovered
- Revisit during next architecture review

---

*Status: Protected - Do not delete*  
*Last Review: 2026-05-02*  
*Owner: Architecture Team*
