# Governance Logbook

*Three-headed compliance god watching every move the AI makes, writing it to a SQLite bible.*

## Purpose
This logbook captures real governance events as they happen during Anigma development. Each entry represents a session where the governance stack (Security + Doctrine + Research) was actively governing AI-assisted development.

## Log Format
```
### [YYYY-MM-DD] Session: [Brief description]
**Branch:** [branch-name]
**Scope:** [what we worked on]
**Duration:** [approx time]

#### 📊 Governance Snapshot
- **Security Events:** [harmonia security status summary]
- **Doctrine Status:** [harmonia doctrine status summary]  
- **Research Status:** [harmonia research status summary]

#### 🎯 What Happened
- [2-3 bullet points of interesting governance interactions]
- [What got blocked, why, and whether it was correct]
- [Research gate forcing literature review]
- [Doctrine catching dumb patterns]

#### 🔧 Tuning Notes
- [Any policy/threshold adjustments made]
- [What we learned about human/AI behavior]
```

---

## Session Logs

### [2025-12-11] Session: Security CCTV Wiring Complete
**Branch:** main
**Scope:** Wiring all three governance committees (Security, Doctrine, Research) to SecurityEventsManager CCTV
**Duration:** 2 hours

#### 📊 Governance Snapshot
*System just wired - no events yet*

#### 🎯 What Happened
- ✅ Wired `CapabilityValidator` to emit `capability_blocked`/`capability_granted` events
- ✅ Wired `CSDoctrineGuard` to emit `doctrine_violation` events for critical/error violations  
- ✅ Wired `ResearchGate` to emit `research_inadequate` events for missing/inadequate research
- ✅ All events flow to same `security_events` SQLite table
- ✅ `harmonia security status` now shows "full governance weather report"

#### 🔧 Tuning Notes
- Default thresholds left as-is for initial real-world testing
- Need to run real experiment to see blocking rates
- Research adequacy scoring needs calibration with real module proposals

---

### [PLANNED] Session: Swift 6 Sendable + TaskScheduler Experiment
**Branch:** experiment/swift6-taskscheduler
**Scope:** Real governance experiment with bounded scope
**Duration:** Planned 3-4 hours

#### 📊 Governance Snapshot
*To be filled after experiment*

#### 🎯 Expected Interactions
1. **Research Gate:** Should block TaskScheduler module without adequate Swift 6 concurrency research
2. **Doctrine Guards:** Should catch non-Sendable types, unsafe concurrency patterns  
3. **Security Spine:** Should block migration work without sufficient trust tier
4. **All layers:** Should create appropriate debt tasks for violations

#### 🔧 Success Criteria
- Events exist in DB for all three governance layers
- Can answer from logs (not vibes):
  - How many tasks blocked, by which layer
  - What types of violations most common
  - Whether trust model actually prevents bad changes
  - If research adequacy scores predict success

---

## Key Metrics Tracked

### Blocking Rates
| Layer | Target Rate | Current Rate | Notes |
|-------|-------------|--------------|-------|
| Research Gate | 10-20% | TBD | Should block when no/inadequate research |
| Doctrine Guards | 15-25% | TBD | Should catch architectural/quality violations |
| Security Spine | 5-15% | TBD | Should prevent capability escalation |

### Debt Creation/Resolution
- **Doctrine Debt:** Violations → Debt Tasks → Resolution
- **Research Debt:** Inadequate research → Research Tasks → Adequate bundles  
- **Capability Debt:** Blocked operations → Trust escalation paths

### Human/AI Behavior Patterns
- Common violation types attempted
- Research topics actually needed vs guessed
- Trust tier effectiveness at preventing bad changes

---

## Policy Evolution

### Initial Settings (v1.0)
- **Research Adequacy:** 0.7 threshold for migration work
- **Doctrine Severity:** Critical/Error = blocking, Warning = advisory
- **Trust Tiers:** Bronze (read), Silver (basic write), Gold (migration), Platinum (system)
- **Security Zones:** Untrusted → Sandboxed → Trusted Mutation → Trusted Network → System

### Adjustments Made
*None yet - waiting for real experiment data*

---

## Interesting Findings

*To be populated with real governance interactions*

---

## Paper Scaffolding Notes

### Problem Statement
Agentic dev tools are rewriting code with vibes and no governance, leading to:
- Architectural drift
- Security violations  
- Research-free "innovation"
- No audit trail of AI decisions

### Approach
Three-layer governance model:
1. **Capability-based security spine** (what can the AI do?)
2. **Doctrine-constrained quality gates** (how should it do it?)
3. **Research-gated innovation** (why should it do it?)

### Implementation
Anigma + Harmonia stack with:
- SQLite CCTV for all governance decisions
- CLI for governance inspection (`harmonia security/doctrine/research status`)
- Debt task system for blocked work
- Trust/zone model for capability escalation

### Evaluation
Real experiments on Anigma itself:
- Swift 6 Sendable migration
- New module creation (TaskScheduler)
- Governance effectiveness metrics from logs

### Discussion Points
- Where doctrine blocked dumb things (success cases)
- Where it over-blocked (false positives)
- How it changes human workflow (from "AI does thing" to "AI proposes, human+governance reviews")
- Trust model effectiveness

---

*Last updated: 2025-12-11 - CCTV wired, ready for first real experiment*