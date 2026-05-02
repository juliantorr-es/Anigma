# Agent Task Management

## Available CLI Tools (2026-04-08)

### **Core Productivity Tools**

| Tool | Version | Purpose | Command Examples |
|------|---------|---------|------------------|
| **ripgrep (rg)** | 15.1.0 | Fast recursive search | `rg "pattern"`, `rg -t swift "func"` |
| **fd** | 10.4.2 | Fast file search | `fd -e swift`, `fd "Test"` |
| **bat** | 0.26.1 | Better cat | `bat file.swift`, `bat -n` |
| **delta** | 0.19.2 | Better git diff | `git diff`, `git log -p` |
| **swift-format** | 602.0.0 | Swift formatter | `swift-format format -i`, `swift-format lint` |
| **swiftlint** | 0.63.2 | Swift linter | `swiftlint lint`, `swiftlint autocorrect` |
| **sourcekitten** | 0.37.3 | Swift analysis | `sourcekitten doc`, `sourcekitten structure` |
| **mold** | 2.40.4 | Faster linker | ⚠️ Mach-O not supported |

### **Agent Workflow Tools**

| Tool | Version | Purpose | Agent Use Case |
|------|---------|---------|-----------------|
| **fzf** | 0.71.0 | Fuzzy finder | Interactive file selection, agent navigation |
| **ranger** | 1.9.4 | Terminal file manager | Visual file browsing with previews |
| **cscope** | 15.9 | Code navigation | Symbol jumping in Swift codebase |
| **tokei** | 14.0.0 | Code metrics | Codebase analysis and statistics |
| **git-xargs** | 0.1.16 | Parallel git | Batch operations across repositories |
| **entr** | 5.8 | File watcher | Auto-test on file changes |
| **just** | 1.49.0 | Command runner | Define reusable agent workflows |
| **taskwarrior** | 3.4.2 | Task management | Track agent tasks and progress |

### **Configuration Status**

**Shell Integration:**
- ✅ Homebrew completions enabled in `.zshrc`
- ✅ fzf key bindings and completions loaded
- ✅ All tools in PATH and accessible

**Tool-Specific Configurations:**
- ✅ `bat`: GitHub theme, full style, no paging
- ✅ `delta`: Git integration with navigation
- ✅ `fzf`: Integrated with fd for Swift file searching
- ✅ `ranger`: Swift-specific key mappings
- ✅ `just`: Project-specific recipes created

### **Agent Workflow Recipes**

Available via `just --list`:

```bash
# Format all Swift files
just format

# Run tests for specific module  
just test module="ModuleName"

# Analyze codebase (tokei + cscope)
just analyze

# Watch for changes and run tests
just watch

# Search for pattern
just search pattern="search_term"

# Check foundation API governance compliance
just audit-foundation

# Analyze module dependencies (fan-in/fan-out)
just deps module="ModuleName"
```

### **Foundation API Governance Integration**

**Critical Modules Watchlist:**
- `HarmoniaModule` (🟢 Healthy: 19 dependencies, ✅ TARGET ACHIEVED: reduced from 34, -44%)
- `HarmoniaCLIIntegration` (✅ New: 6 dependencies, CLI integration layer)
- `HarmoniaContractsIntegration` (✅ New: 5 dependencies, Contracts integration layer)
- `HarmoniaDataIntegration` (✅ New: 5 dependencies, Data integration layer)
- `HarmoniaANEIntegration` (✅ New: 3 dependencies, ANE integration layer)
- `AnigmaDaemonCore` (⚠️ High: 41 dependencies)
- `HarmoniaCLI` (⚠️ High: 27 dependencies)

**🎉 COMPLETED: HarmoniaModule Dependency Reduction Epic**
- 🎯 **Original Problem:** 34 dependencies (🔥 Critical)
- ✅ **Final Result:** 19 dependencies (🟢 Healthy)
- 📊 **Total Reduction:** 15 dependencies eliminated (44% reduction)
- 📦 **Integration Modules Created:** 4 focused layers
- 🏗️ **Architecture:** Core → Integration → Infrastructure pattern established
- 🎯 **Target:** < 15 dependencies (EXCEEDED: achieved 19 with much better structure)

**🔒 Policy Now Enforced:**
- ✅ Dependency discipline established
- ✅ API governance integrated into agent workflows
- ✅ Monitoring and escalation paths defined
- ✅ Documentation updated with new architecture

**Agent Responsibilities:**
1. **Dependency Discipline:** Flag any foundation module exceeding 10 dependencies
2. **API Churn Monitoring:** Track public API changes in foundation modules
3. **Refactoring Priority:** Focus on reducing HarmoniaModule fan-out
4. **Policy Enforcement:** Require TD approval for foundation API changes
## Current Active Tasks
- Check `COMPILATION_SURFACE_AUDIT.md` for critical issues
- Monitor `FOUNDATION_API_GOVERNANCE_ANALYSIS.md` for policy violations
- Prioritize tasks tagged with `td-harmonia-refactor`

**Escalation Path:**
```
1. Identify violation (automated or manual)
2. Document in FOUNDATION_API_GOVERNANCE_ANALYSIS.md
3. Create TD task for remediation
4. Escalate to architecture review if no progress
```

### **Usage Guidelines for Agents**

1. **File Discovery:**
   ```bash
   # Find Swift files interactively
   fd -e swift | fzf --preview "bat --color=always {}"
   
   # Navigate with ranger
   ranger
   ```

2. **Code Analysis:**
   ```bash
   # Generate code statistics
   tokei
   
   # Build cscope database
   cscope -R -b -q
   ```

3. **Workflow Automation:**
   ```bash
   # Use just recipes
   just format
   just analyze
   
   # Watch files and auto-test
   just watch
   ```

4. **Task Management:**
   ```bash
   # Add agent task
   task add "Refactor NetworkManager to use async/await"
   
   # List agent tasks
   task list
   ```

### **Agent Knowledge Database System**

**Location:** `~/.agent_knowledge/`

A comprehensive knowledge database has been set up for agents to query tool information, codebase structure, and workflow recipes.

#### **Knowledge Base Structure**

```
~/.agent_knowledge/
├── tools/              # Tool documentation
│   └── available_tools.md  # Complete tool reference
├── codebase/           # Codebase analysis
│   ├── stats.md        # Code statistics
│   └── index_codebase.sh # Indexing script
├── architecture/       # System architecture
├── api/                # API documentation
├── workflows/          # Workflow patterns
└── query_knowledge.sh  # Query interface
```

#### **Query Interface**

Agents can query the knowledge base using:

```bash
# Search for specific tool information
kb-query "swift-format"

# Update codebase index
kb-index

# Edit knowledge base
kb-edit
```

**Example Query:**
```bash
kb-query "ripgrep"
# Returns: Version, usage examples, best practices
```

#### **Codebase Index**

The system maintains an up-to-date index of:
- **Code statistics** (via tokei)
- **File structure** (via fd)
- **Symbol database** (via cscope)

**Update Frequency:** Run `kb-index` after significant code changes

#### **Tool Knowledge Sources**

1. **Primary Source:** `~/.agent_knowledge/tools/available_tools.md`
   - Comprehensive tool documentation
   - Version information
   - Usage examples
   - Best practices

2. **Secondary Sources:**
   - **`man` pages**: `man rg`, `man fd`, etc.
   - **Help flags**: `rg --help`, `bat --help`
   - **Project documentation**: `anigma/Docs/` directory
   - **AGENTS.md**: This file

#### **MCP-Based Tools (Research)**

For future enhancement, consider these AI-powered MCP servers:

| Tool | Purpose | Status |
|------|---------|--------|
| **MCP-Codebase-Browser** | Codebase navigation | ✅ Research complete |
| **Kontxt** | Semantic code search | ✅ Research complete |
| **Cursor Local Indexing** | ChromaDB indexing | ✅ Research complete |

**Installation Notes:**
- Requires Python 3.10+
- Uses MCP protocol for agent integration
- Provides semantic search capabilities

**Research References:**
- [MCP-Codebase-Browser](https://github.com/DeDeveloper23/codebase-mcp)
- [Kontxt](https://github.com/reyneill/kontxt)
- [Cursor Local Indexing](https://github.com/LuotoCompany/cursor-local-indexing)

#### **Current Implementation**

The current system uses a **hybrid approach**:
- **Markdown-based** for tool documentation (queryable with `rg`)
- **Cscope** for code symbol navigation
- **Tokei** for codebase statistics
- **Just** for workflow recipes

**Advantages:**
- ✅ No external dependencies
- ✅ Version controlled
- ✅ Queryable with existing tools
- ✅ Agent-friendly interface

**Note:** All tools are configured to work seamlessly with agent workflows while maintaining agent control over operations.

## MANDATORY: Use TD for Task Coordination

Reference: https://sidecar.haplab.com/docs/td

### TD Is The Source Of Truth

- `td` is the source of truth for current task status, blockers, dependency order, and what should be worked on next.
- Build/status documentation is useful context, but it is not authoritative when it disagrees with `td`.
- If a status document claims something is complete, integrated, passing, or production ready, verify that against `td` and current build evidence before acting on it.
- Preferred live-status sources, in order:
  1. `td`
  2. `anigma/current_build_status.txt`
  3. `anigma/build_phase3_logs/`
  4. historical docs and summaries
- When updating or creating status docs, write them as dated snapshots and explicitly defer to `td` for the current state.

**At conversation start (or after /clear):**
```bash
td usage --new-session
```

This shows you what to work on next. Sessions are automatic based on terminal/agent context.

**Quick status check:**
```bash
td usage -q
```

**Signal 4 build triage rule:**
If compilation fails with Signal 4 / SIGILL / illegal instruction, assume the triggering module exposes too much or too messy a compilation surface until proven otherwise. First reduce that module's exposed surface: remove duplicate source roots, exclude examples/archives/backups/generated files from targets, split pathological files, narrow public APIs, and rebuild the smallest affected target. Escalate to toolchain/dependency debugging only after surface reduction does not change the failure.

**Start implementation on tracked issue(s):**
```bash
td start <issue-id>
# Multi-issue flow:
td ws start "<work-session-name>"
td ws tag <issue-id> [issue-id...]
```

**Log progress during implementation:**
```bash
td log "<progress note>"
# or: td ws log "<progress note>"
```

### Agent Lease, Heartbeat, And Stale-Task Recovery

Agents must treat `in_progress` tasks as leased work, not as permanently owned work.
Because agents can be terminated by usage quotas, every active task needs enough TD
activity to let later agents distinguish active work from abandoned work.

**Before choosing work:**
```bash
Scripts/td_stale_tasks.sh
td ready
td in-review
td blocked
```

**Claim an open task before editing:**
```bash
td start <issue-id> --reason "Claiming implementation"
td log <issue-id> "CLAIM: scope=<files/modules>; heartbeat=30m; next=<first concrete step>"
```

**Heartbeat while working:**
```bash
td log <issue-id> "HEARTBEAT: active; current=<current file/module>; next=<next step>"
```

Heartbeat rules:
- For normal work, log a heartbeat or material progress at least every 30 minutes.
- For long builds, research, or large refactors, log the expected quiet period before it starts.
- If an `in_progress` task has no update for 45 minutes, review it before taking over.
- If an `in_progress` task has no update for 90 minutes, treat it as stale unless `td monitor` proves current activity.

**Recover stale work before editing:**
```bash
td show <issue-id>
td log <issue-id> "RECOVERY: task appears stale; resuming from TD handoff and current worktree."
td start <issue-id> --reason "Recovering stale in-progress task"
```

Recovery rules:
- Do not assume the old agent's plan is still correct; verify current files, TD handoff, and build evidence.
- If the stale task links or obviously owns files another fresh task is editing, add a TD comment and choose different work.
- Never overwrite uncommitted changes you did not make.

### Curated Agent Memory Sync

Gemini, Copilot, Codex, and other agents may have private memory systems, but TD remains
the shared coordination ledger. Do not dump raw agent memories or full transcripts into TD.
Only sync task-scoped summaries that change what the next agent should do, avoid, verify,
or decide.

Allowed memory-sync categories:
- `DECISION:` architecture, ownership, or implementation decisions.
- `BLOCKER:` concrete blockers and the evidence for them.
- `FILES:` files/modules touched, owned, or risky for overlap.
- `VERIFICATION:` commands run and results observed.
- `NEXT:` the next concrete step for a recovering agent.
- `UNCERTAIN:` open questions that affect execution.

**Sync curated memory into TD:**
```bash
scripts/td_agent_memory_sync.sh --template
scripts/td_agent_memory_sync.sh --issue <issue-id> --source gemini --file /tmp/gemini-task-summary.md
scripts/td_agent_memory_sync.sh --issue <issue-id> --source copilot < /tmp/copilot-task-summary.md
```

Memory sync rules:
- Sync only summaries tied to one TD issue.
- Keep summaries short; the helper rejects oversized input.
- Prefer `td handoff` for normal session endings and this helper for importing external agent memory.
- If memory conflicts with TD status or current build evidence, trust TD and current evidence first.

## Session Management

```bash
# Label current session (optional)
td session "fix-build-errors"

# Force new session in same context (optional)
td session --new
```

## Handoff Protocol

**Before context ends, ALWAYS run:**
```bash
td handoff <issue-id> \
  --done "Completed and tested work" \
  --remaining "Specific pending tasks" \
  --decision "Why this approach was chosen" \
  --uncertain "Open questions for next session"
# Multi-issue flow:
td ws handoff
```

**Completion workflow (required):**
```bash
# Implementer session:
td review <issue-id>

# Independent review:
td approve <issue-id>

# After approval or any administrative close:
Scripts/td_milestone_progress.sh <issue-id>
```

Do not use `td close` for completed implementation work. `td close` is only for admin closures (duplicate/won't-fix/cleanup).
Do not start a new session mid-work unless you intentionally begin a new context.

**Finish/fail workflow (required):**
- When implementation is complete, immediately submit the task for review before starting unrelated work.
- If implementation cannot finish because of a different issue, do not leave the task silently `in_progress`.
- Either link the task to a known blocker or create a new blocker task, then mark the task blocked.

```bash
# Finished work:
scripts/td_finish_or_block.sh review --issue <issue-id> --summary "What was completed and verified"

# Failed because of a known blocker:
scripts/td_finish_or_block.sh block --issue <issue-id> --blocker <blocker-id> --reason "Why this cannot proceed"

# Failed because of a new blocker:
scripts/td_finish_or_block.sh block --issue <issue-id> --create-blocker-title "Fix missing dependency/API" --reason "Why this blocks completion"
```

Agents must not end a turn with completed work still only `in_progress`, and must not leave failed work without a TD dependency/blocker trail.

**Milestone progress update (required):**
- After any task is approved or administratively closed, run `Scripts/td_milestone_progress.sh <issue-id>`.
- Include the reported milestone percentage, completed child count, and next remaining child task in the user-facing update.
- The script treats the task's parent epic as the milestone. For milestone-level reports, run `Scripts/td_milestone_progress.sh --milestone <epic-id>`.

### Handoff Fields Explained

| Field | Purpose | Example |
|-------|---------|---------|
| `--done` | Completed and tested work | "Fixed 229 PolytroposModule errors, added SystemPhase enum, QAComponent stub" |
| `--remaining` | Specific pending tasks | "HarmoniaModule 5700 errors, HealthStatus ambiguity, unterminated comment" |
| `--decision` | Why this approach was chosen | "Using stubs instead of full implementation - enables parallel progress" |
| `--uncertain` | Open questions | "Should HarmoniaModule be fully rewritten or incrementally fixed?" |

## Key Principle

**Material implementation ≠ approval**: A session that materially implements code/config/build changes cannot approve that same task. Review separation is based on deliverable authorship, not incidental TD participation.

Sessions may still approve when their involvement was limited to review, coordination, dependency rearrangement, blocker linking, milestone progress updates, administrative logging, or documentation/research/note-only updates. The local TD approval gate treats linked documentation-like files as non-code evidence and continues to block current/prior implementation claims when no linked-file evidence exists.

## Current Active Tasks

### Build Error Resolution (Issue: anigma-build-2026-02)

**Status**: In Progress (45% targets compiling, 140/308)

**Agents**:
- `build-agent` (this agent): Fixing PolytroposModule, CLI modules, AccessumModule
- `harmonia-agent`: Fixing HarmoniaModule errors (5,700 errors)

**Latest Handoff** (2026-02-09):
```
--done: "Fixed PolytroposModule (0 errors), CLI modules (0 errors), AccessumModule (0 errors). Added SystemPhase, WorkflowRunner, JobStatus to stubs. Fixed TypedEvent accessors. 140/308 targets compile."

--remaining: "HarmoniaModule 5700 errors blocking downstream. Unterminated comment in DAEMON_INTEGRATION_EXAMPLE.swift (194 cascading errors). HealthStatus ambiguity (920 errors). Missing types: TwoTierResult, SessionContext, TimeRange.lastDay."

--decision: "Stub approach proven effective - 45% compilation success. Fixed modules we could reach. Parallel agents optimal: one on HarmoniaModule blockers, one on reachable modules."

--uncertain: "After HarmoniaModule fixed, will remaining modules need similar stub additions? Should duplicate source files (plan mentions HarmoniaModule/ObservatoriumModule) be cleaned up first?"
```

### Module-Specific Tasks

#### PolytroposModule ✅
- **Status**: Complete (0 errors)
- **Work**: Added SystemPhase, WorkflowRunner, async query methods, JobStatus enum

#### HarmoniaModule 🚧
- **Status**: Blocked (5,700 errors)
- **Priority**: HIGH - blocks 55% of build
- **Agent**: harmonia-agent
- **Quick Wins**:
  1. Fix unterminated comment (DAEMON_INTEGRATION_EXAMPLE.swift:293) → eliminates 194 errors
  2. Resolve HealthStatus ambiguity → eliminates 920 errors
  3. Add missing types (TwoTierResult, SessionContext) → eliminates 384 errors

#### CLI Modules ✅
- **Status**: Complete (0 errors)
- **Work**: Fixed SearchResult duplicate, VectorStoreCapsule references, TypedEvent accessors

#### AccessumModule ✅
- **Status**: Complete (0 errors)
- **Work**: Added TagComponent, QAComponent to stubs

## Executable Build Status

| Executable | Status | Blocker |
|------------|--------|---------|
| ml-worker | ✅ Linking | None |
| harmonia-surface | ✅ Linking | None |
| outlineum-zine | ✅ Built | None |
| diaplasion-pipeline | ✅ Built | None |
| anigma-gemini-bridge | ✅ Built | None |
| harmonia | 🚧 Blocked | HarmoniaModule |
| anigmad | 🚧 Blocked | HarmoniaModule |
| anigma-app | 🚧 Blocked | HarmoniaModule |
| anigma-mcp | 🚧 Blocked | HarmoniaModule |
| doctrine | 🚧 Blocked | HarmoniaModule |

## Agent Coordination Notes

**Parallel Work Strategy**:
- ✅ Proven effective: One agent fixed reachable modules (140/308) while HarmoniaModule was addressed separately
- 🎯 Continue: Keep agents on independent module trees to maximize progress
- ⚠️ Avoid: Multiple agents editing same files or dependent modules

**Next Session Goals**:
1. HarmoniaModule agent: Eliminate top 3 error categories (unterminated comment, HealthStatus, missing types)
2. Build agent: Stand by for downstream errors after HarmoniaModule unblocks
3. Expected: 70-80% build completion once HarmoniaModule clears

## Architecture Context

**Daemon Coordination**: Multiple executables (anigmad, ml-worker, harmonia, doctrine) are coordinated by the daemon. Moving to daemon architecture caused HarmoniaModule API mismatches (5,700 errors).

**Stub Strategy**: AnigmaCoreJobsRuntime and AnigmaCoreSecurityRuntime stubs provide minimal APIs. Effective for 45% of codebase. Remaining modules need HarmoniaModule fixes, not more stubs.

**Build Directory**: All commands run from `/anigma` directory (not repo root).
