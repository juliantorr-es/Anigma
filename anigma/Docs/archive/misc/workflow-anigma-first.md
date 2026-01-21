# Workflow: Anigma First, Opencode Second

*Demoting Opencode from "primary agent" to "expensive consultant"*

## The Shift

**Before (Old Workflow):**
```
1. Opencode does thing
2. Human reviews after
3. No governance, no audit trail
```

**After (New Workflow):**
```
1. Anigma proposes thing
2. Governance reviews (Security + Doctrine + Research)
3. Creates debt tasks if blocked
4. Human approves escalations
5. CCTV logs everything
6. Opencode only for explanation/design review
```

## When to Use Anigma vs Opencode

### ✅ Use Anigma (Governed Automation)
- **Creating tasks:** `harmonia scout ... --create-tasks`
- **Running migrations:** `harmonia swift6 step --count N`
- **Proposing modules:** `harmonia module propose --name X --type Y`
- **Checking governance:** `harmonia security/doctrine/research status`
- **Managing debt:** `harmonia doctrine debt list/resolve`
- **Any code change to Anigma's codebase**

### ❓ Use Opencode (Consultant)
- **"Explain this file/symbol to me"**
- **"Show me a diff in a nice way"**
- **"Sanity-check this design before I let Anigma loose on it"**
- **"What does this code even do?"**
- **General programming questions unrelated to Anigma**

## Daily Workflow Template

### Morning Check
```bash
# Check governance state
harmonia security status
harmonia doctrine status

# Check for pending debt
harmonia doctrine debt list --unresolved
harmonia research status --pending

# Review overnight AI attempts
harmonia security status --recent 20
```

## Automated Workflows: Custom Slash Commands

To streamline structured tasks and enforce output contracts, several custom commands are available via the Gemini CLI. These commands provide a consistent interface for agent interactions with Anigma processes.

*   **`/deconstruct_inspo <repo_name>`**: Deconstructs one inspiration repository into an Anigma recipe bundle. (Enforces strict scope and output contract.)
*   **`/triage_inspo`**: Triage all repos in `Anigma/Inspiration/INBOX/`, updating the manifest with relevance tags and summaries.
*   **`/recipe_validator <repo_name>`**: Validates a recipe bundle against its output contract, reporting quality issues.
*   **`/mapping_enforcer <repo_name>`**: Enforces a strict table format for `02-anigma-mapping.md` within a recipe bundle.
*   **`/proposal_generator <task_brief_name> <output_path>`**: Generates an `ActionProposal` JSON from a TASK-BRIEF.
*   **`/cctv_summarizer <cctv_logs_path>`**: Summarizes `CCTVEvent` JSON logs into a human-readable governance narrative.
*   **`/doc_link_hygiene`**: Scans key documentation files for consistency, missing links, and policy drift.

### Morning Check

### Development Session
```bash
# 1. Scout for work
harmonia scout run swift6 --create-tasks

# 2. Run governed steps
harmonia swift6 step --count 5

# 3. Check what got blocked
harmonia security status --since "2 hours ago"

# 4. Resolve debt if needed
harmonia doctrine debt resolve <task-id>

# 5. Log to governance logbook
# Update docs/governance-logbook.md
```

### Module Development
```bash
# 1. Propose module (goes through research gate)
harmonia module propose --name TaskScheduler --type orchestrator

# 2. Check research status
harmonia research status TaskScheduler

# 3. If blocked, do research or approve escalation
# 4. Once approved, develop through governed pipeline
```

### Using Opencode as Consultant
```bash
# NOT: "Write me a TaskScheduler module"
# INSTEAD: "Explain the concurrency patterns in HarmoniaModule/Security"

# NOT: "Fix all Swift 6 Sendable issues"
# INSTEAD: "Review this Sendable migration plan before I run it through Anigma"

# NOT: "Refactor this whole module"
# INSTEAD: "What are the code smells in this file? I'll create scout tasks"
```

## Governance Logging Discipline

**After each session (~30+ minutes of agent work):**
1. Update `docs/governance-logbook.md`
2. Include:
   - Date/branch/scope
   - `harmonia security status` snapshot
   - `harmonia doctrine status` snapshot  
   - `harmonia research status` for any new modules
   - 2-3 bullet notes on interesting governance interactions

**Example log entry:**
```
### [2025-12-11] Session: Swift 6 Sendable Experiment
**Branch:** experiment/swift6-taskscheduler
**Scope:** 3-5 files with Sendable issues + TaskScheduler module proposal
**Duration:** 3 hours

#### 📊 Governance Snapshot
- **Security Events:** 8 capability_blocked, 3 doctrine_violation, 1 research_inadequate
- **Doctrine Status:** 11 CS violations, 8 resolved, 72.7% resolution rate
- **Research Status:** TaskScheduler adequacy: 0.4, missing Swift 6 concurrency papers

#### 🎯 What Happened
- Doctrine blocked 7 non-Sendable types in actor boundaries (correct)
- Research gate forced literature review before module creation (good)
- Security spine blocked bronze trust from gold-tier migration (appropriate)

#### 🔧 Tuning Notes
- Research adequacy threshold might be too high (0.7 → 0.6)
- CS doctrine catching all Sendable issues as expected
```

## Handling Governance Blockages

### When Anigma Gets Blocked
1. **Don't bypass** - that defeats the purpose
2. **Check CCTV:** `harmonia security status --recent 10`
3. **Understand why:** Which layer blocked? What rule?
4. **Address properly:**
   - **Research block:** Do literature review, update research bundle
   - **Doctrine block:** Fix violation, request approval if error severity
   - **Security block:** Request trust escalation with justification

### Trust Escalation Process
```bash
# 1. Check current trust
harmonia security status --trust

# 2. Request escalation with justification
harmonia security trust request --tier gold --reason "Swift 6 migration work"

# 3. Human reviews request (you, wearing different hat)
harmonia security trust approve <request-id>

# 4. Retry with new trust level
harmonia swift6 step --count 5
```

## Success Metrics

### Target Blocking Rates
- **Research Gate:** 10-20% (should block when no/inadequate research)
- **Doctrine Guards:** 15-25% (should catch architectural/quality violations)
- **Security Spine:** 5-15% (should prevent capability escalation)

### If Blocking Too Much (>30% overall)
1. Check which layer is over-blocking
2. Review false positives in CCTV
3. Adjust thresholds:
   - `harmonia doctrine config --severity-warning-only`
   - `harmonia research config --adequacy-threshold 0.6`
   - `harmonia security config --trust-escalation-easier`

### If Blocking Too Little (<10% overall)
1. Check if governance is actually working
2. Review CCTV for missed violations
3. Tighten thresholds:
   - `harmonia doctrine config --add-rule ...`
   - `harmonia research config --adequacy-threshold 0.8`
   - `harmonia security config --strict-mode`

## Transition Period Expectations

**Week 1-2: Noisy and Annoying**
- Anigma will block things you're used to doing
- You'll need to do research, fix doctrine violations
- Workflow will feel slower
- **This is normal** - you're establishing governance

**Week 3-4: Finding Rhythm**
- You'll learn what gets blocked and why
- You'll pre-emptively address common violations
- Debt resolution becomes routine
- CCTV starts showing interesting patterns

**Week 5+: Governed Automation**
- Anigma is primary automation loop
- Opencode is consultant for tricky problems
- You have forensic logs of all AI decisions
- You can point to data (not vibes) about what works

## Harmonia's Role in Agent Modus Operandi Enforcement (Future)

To ensure agents consistently operate within Anigma's governance framework, Harmonia will be enhanced to mechanically enforce the Agent Contract. (feedback from review)

*   **Rule Prepending**: Harmonia will prepend the `AGENT-CONTRACT.digest.md` (`Docs/LLM/AGENT-CONTRACT.digest.md`), current governance snapshot, and trust tier, along with a "you are in strict-silo by default" banner, to every LLM prompt it sends.
*   **Forced Action Proposal Interface**: The only allowed interface for LLMs to propose code changes will be a structured "Action Proposal" wrapper, adhering to a defined schema (`Docs/LLM/ActionProposal.schema.json`). Every governance decision and event will be logged according to the `CCTVEvent` schema (`Docs/LLM/CCTVEvent.schema.json`).
    *   **Required Response**: LLMs must respond with:
        1.  An `ActionProposal` (adhering to a defined schema in `Docs/LLM/ActionProposal.schema.json`)
        2.  A `Justification` (with citations to repo docs/ADRs)
        3.  A `TestPlan`
        4.  A `RollbackPlan`
    *   **Mechanical Blocking**: The Write Gate will reject any attempt to output raw code without a valid `ActionProposal`, unless the trust tier explicitly allows it. Non-compliant LLM responses must be "BLOCKED" with an explanation.

## Inspiration Deconstruction Workflow (Future)

To systematically process external inspiration repositories, a structured deconstruction workflow will be enforced, utilizing a new directory structure for managing repos in different states (INBOX, WORKING, LEGACY) and storing analysis outputs (RECIPES). (feedback from review)

*   **Orchestration**: `Scripts/inspiration_deconstruct.sh` will orchestrate the process, acting as a state machine for repositories (`INBOX` -> `WORKING` -> `RECIPES/<repo-slug>` -> `LEGACY`).
*   **Manifest**: `Inspiration/_index/manifest.toml` will track each repo's status and link to its recipe bundle.
*   **Agent Role**: The AI agent's role is strictly to perform the analysis and generate the recipe bundle files (e.g., `00-summary.md`, `01-what-to-steal.md`, `02-anigma-mapping.md`, etc.) under `Inspiration/RECIPES/<repo-slug>/`.
*   **Output Contract**: The agent must adhere to a fixed output contract for these recipe files and signal completion with `DECONSTRUCTION_COMPLETE` in the last file generated.

## The Point

You're not just using a different tool. You're establishing:
1. **Governance:** AI doesn't just do things, it proposes within constraints
2. **Auditability:** You can reconstruct every decision from logs
3. **Evidence-based:** Changes require research justification
4. **Quality gates:** Architectural standards are enforced
5. **Security model:** Capabilities are controlled by trust

This turns "AI does thing" into "AI proposes, human+governance reviews" - which is how responsible automation should work.

---

*Last updated: 2025-12-11 - Governance stack operational, ready for transition*