# AGENTS_QUICKREF.md - Quick Reference Commands

## Mandatory: TD + Sidecar Workflow

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td

1. Start of every conversation/context window (or after `/clear`):
   ```bash
   td usage --new-session
   ```
2. Use a quiet status check after setup:
   ```bash
   td usage -q
   ```
3. Start implementation on a tracked issue:
   ```bash
   td start <issue-id>
   # Multi-issue work:
   td ws start "<work-session-name>"
   td ws tag <issue-id> [issue-id...]
   ```
4. Log progress as you go:
   ```bash
   td log "<progress note>"
   # or: td ws log "<progress note>"
   ```
5. Before ending context, record handoff (required):
   ```bash
   td handoff <issue-id> \
     --done "<completed and tested work>" \
     --remaining "<specific pending tasks>" \
     --decision "<why this approach was chosen>" \
     --uncertain "<open questions>"
   # or: td ws handoff
   ```
6. Completion flow: material implementer runs `td review <issue-id>`; an independent reviewer runs `td approve <issue-id>`. Review/admin coordination, dependency moves, blocker notes, milestone updates, and documentation/research/note-only participation do not by themselves prevent approval.
7. Never use `td close` for completed implementation work. Use `td close` only for admin closures (duplicate/won't-fix/cleanup).
8. Do not start a new session mid-work unless you are intentionally beginning a new context.

This document provides quick reference commands for common agent tasks.

## Essential Commands

### **Shared memory Queries**
```bash
# Check for project configuration
memory_store(mode: "search", query: "build commands", scope: "project")

# Look for architecture patterns
memory_store(mode: "search", query: "capsule architecture", scope: "project")

# Find error solutions
memory_store(mode: "search", query: "compilation errors", scope: "project")

# Check for stale memories (>90 days)
memory_store(mode: "search", query: "updated:<$(date -v-90d +%Y-%m-%d)", scope: "project")
```

### **OpenCode Plugins**
```bash
# Create worktree
worktree_create(branch: "feat/[description]-$(date +%Y%m%d)", baseBranch: "main")

# Delete worktree
worktree_delete(reason: "Plan complete")

# Run all CI gates
anigma_ci_all()

# Check Swift 6 compliance
anigma_swift6_check(target: "[module-name]")
```

### **Git Commands**
```bash
# Complete workflow
git add .
git commit -m "feat: [description]
- [change 1]
- [change 2]
- [change 3]"
git push origin feat/[branch-name]

# Check worktrees
git worktree list

# Clean up merged branches
git branch --merged main | grep -v "main" | xargs git branch -d
```

### **Build and Test**
```bash
# Build project
swift build
./build.sh warmup  # Pre-compile dependencies
./build.sh engine  # Build engine components
./build.sh app     # Build application

# Run tests
swift test

# Validate gates
./scripts/validate_gates.sh --verbose
```

## Common Workflows

### **New Feature Development**
```bash
# 1. Create worktree
worktree_create(branch: "feat/[feature]-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory
memory_store(mode: "search", query: "capsule implementation", scope: "project")

# 3. Implement feature

# 4. Run CI gates
anigma_ci_all()

# 5. Commit and push
git add .
git commit -m "feat: [feature description]"
git push origin feat/[feature]-$(date +%Y%m%d)

# 6. Clean up
worktree_delete(reason: "Feature complete")
```

### **Bug Fix**
```bash
# 1. Create worktree
worktree_create(branch: "fix/[bug]-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory
memory_store(mode: "search", query: "error handling", scope: "project")

# 3. Fix bug

# 4. Run specific gates
anigma_swift6_check(target: "[affected-module]")

# 5. Commit and push
git add .
git commit -m "fix: [bug description]"
git push origin fix/[bug]-$(date +%Y%m%d)

# 6. Clean up
worktree_delete(reason: "Bug fix complete")
```

### **Code Review**
```bash
# Check project standards
memory_store(mode: "search", query: "SwiftLint rules", scope: "project")

# Validate:
# - Bauhaus design tokens (no hardcoded colors/fonts)
# - Accessibility labels present
# - Sendable concurrency safety
# - Test coverage requirements
```

## Memory Management

### **Adding New Memories**
```bash
# With timestamp
memory_store(mode: "add", content: "[insight] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "[type]", scope: "project")

# Types to use:
# - architecture (core design patterns)
# - project-config (build commands, tooling)
# - learned-pattern (code conventions)
# - error-solution (bug fixes)
# - workflow-pattern (development processes)
```

### **Housekeeping**
```bash
# Per plan completion:
# 1. Add timestamps to new memories
# 2. Review stale memories (>90 days)
# 3. Prune or update stale memories
# 4. Promote validated short-term to medium-term
# 5. Archive completed workarounds
```

## Digestion Pipeline

### **Analyzing Inspiration Repos**
```bash
# List repos
find "/Users/user/Developer/Repos for Inspiration/" -maxdepth 1 -type d | grep -v "^\.$"

# Extract patterns and save
memory_store(mode: "add", content: "[pattern] - Source: [repo] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")

# Clean up digested repo
rm -rf "/Users/user/Developer/Repos for Inspiration/[repo]"
```

## Quality Gates

### **Five Mandatory Gates**
1. **ERROR_MODEL** - No public API throws non-CapsuleError
2. **DIAGNOSTICS_CONFORMANCE** - No print/NSLog/os_log
3. **BUILD_HYGIENE** - No hardcoded paths, documented flags
4. **TEST_COVERAGE** - Tier-based (Tier 5: 80%, 15+ tests; Tier 3: 60%, 10+ tests)
5. **TIER_VALIDATION** - Valid MANIFEST.toml

### **Local Validation**
```bash
./scripts/validate_gates.sh [--verbose] [--capsule CAPSULE_NAME]
```

## Emergency Procedures

### **Build Failures**
```bash
# Check Shared memory
memory_store(mode: "search", query: "build errors", scope: "project")

# Common issues:
# - VizAggregationCapsule compilation errors
# - Swift 6 concurrency warnings
# - Hardcoded /opt/homebrew paths
```

### **Security Issues**
```bash
# Immediate actions:
# 1. Remove hardcoded secrets
# 2. Check Shared memory for similar patterns
# 3. Update memory with prevention strategies
```

## Related Documentation
- **** - Overview and structure
- **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Plugin details
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory system
- **[AGENTS_GIT.md](AGENTS_GIT.md)** - Git workflow
- **[AGENTS_DIGESTION.md](AGENTS_DIGESTION.md)** - Inspiration analysis
