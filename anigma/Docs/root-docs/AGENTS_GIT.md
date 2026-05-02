# AGENTS_GIT.md - Git Management and Workflow Discipline

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

This document covers git management protocols to prevent branch/worktree sprawl and ensure consistent commits.

## Git Management Protocol

### **Branch and Worktree Discipline**
To prevent branch/workspace sprawl (85 branches, 23 worktrees), follow strict protocols:

1. **One Worktree Per Plan**: Each development plan gets its own isolated worktree
2. **Multiple Tasks Per Worktree**: Agents can work on multiple related tasks within the same plan's worktree
3. **Feature Branch Naming**: `feat/[short-description]-[date]` (e.g., `feat/capsule-upgrade-20250127`)
4. **Automatic Cleanup**: Delete worktrees after plan completion
5. **Main Branch Hygiene**: Never commit directly to main - always use feature branches

### **Complete Execution Workflow**
Every plan must follow this end-to-end workflow with roadmap integration:

```bash
# === PLAN START ===
# 1. Create isolated worktree for the plan
worktree_create(branch: "feat/[plan-description]-[date]", baseBranch: "main")

# 2. Run roadmap scan: Plan Start
./scripts/roadmap_plan_start.sh "[plan-description]"

# 3. Check Shared memory for context
memory_store(mode: "search", query: "[relevant topic]", scope: "project")

# 4. Check inspiration repos for patterns
find "/Users/user/Developer/Repos for Inspiration/" -type d -name "*[related]*"

# === IMPLEMENTATION ===
# 5. Implement changes following patterns (multiple tasks can be done in this worktree)

# 6. Run CI gates locally
./scripts/validate_gates.sh --verbose

# === PLAN END ===
# 7. Commit with conventional format
git add .
git commit -m "feat: [clear description]
- [specific change 1]
- [specific change 2]
- [specific change 3]"

# 8. Push to remote
git push origin feat/[plan-description]-[date]

# 9. Create PR (if applicable)
gh pr create --title "feat: [clear description]" --body "[detailed description]"

# 10. Run roadmap scan: Plan End
./scripts/roadmap_plan_end.sh "[plan-description]" "[plan-start-date]"

# 11. Update Shared memory with timestamp
memory_store(mode: "add", content: "[key insights] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")

# 12. Perform memory housekeeping
# Review stale memories, update timestamps, promote/archive as needed

# 13. Clean up worktree after plan completion
worktree_delete(reason: "Plan implementation complete")
```

## Git Management Rules

### **Mandatory Cleanup Procedures**
1. **Daily Worktree Audit**: At session start, check for stale worktrees:
   ```bash
   git worktree list
   # Clean up any >7 days old
   ```

2. **Branch Cleanup Protocol**:
   - **Merged branches**: Delete immediately after merge
   - **Stale branches**: Delete if >30 days without activity
   - **Active branches**: Keep only current worktree branch

3. **Commit Quality Standards**:
   - **Atomic commits**: One logical change per commit
   - **Descriptive messages**: Clear what and why
   - **Conventional format**: `feat:`, `fix:`, `docs:`, `chore:`
   - **Bullet points**: List specific changes for clarity

### **Prevention of Git Sprawl**
1. **Worktree Limit**: Maximum 3 active worktrees at any time
2. **Branch Limit**: Maximum 10 active feature branches
3. **Automatic Cleanup**: Script to remove old branches/worktrees
4. **Session Discipline**: One plan → One worktree → Multiple tasks → One commit → Cleanup

### **Recovery from Git Sprawl**
If you encounter 85 branches/23 worktrees again:
```bash
# 1. List all worktrees
git worktree list

# 2. Delete stale worktrees (>7 days)
for wt in $(git worktree list | grep -E '\[.*days? ago\]' | awk '{print $1}'); do
  git worktree remove "$wt" --force
done

# 3. List all branches
git branch -a

# 4. Delete merged branches
git branch --merged main | grep -v "main" | xargs git branch -d

# 5. Delete stale remote branches
git remote prune origin
```

## Task Execution Guidelines

### **1. New Feature Development**
```bash
# First, create isolated worktree for the plan
worktree_create(branch: "feat/[plan-description]-$(date +%Y%m%d)", baseBranch: "main")

# Check for similar implementations
memory_store(mode: "search", query: "capsule implementation", scope: "project")

# Then follow capsule architecture patterns:
# - Create in appropriate tier (1-3)
# - Use protocol-oriented design
# - Implement OperationResult for async
# - Add comprehensive tests

# Multiple related features can be developed in the same worktree
# Always complete the full workflow (commit, push, cleanup)
```

### **2. Bug Fixes**
```bash
# Check for known issues
memory_store(mode: "search", query: "error handling", scope: "project")

# Follow error handling conventions:
# - Use AnigmaError schema
# - Add proper error propagation
# - Never use fatalError() in production
```

### **3. Code Review**
```bash
# Enforce project standards:
memory_store(mode: "search", query: "SwiftLint rules", scope: "project")

# Check for:
# - Bauhaus design token compliance
# - Accessibility labels
# - Concurrency safety (Sendable)
# - Test coverage requirements
```

### **4. Performance Optimization**
```bash
# Reference performance patterns:
memory_store(mode: "search", query: "ANE optimization", scope: "project")

# Consider:
# - ANE hardware acceleration
# - Actor-based concurrency
# - Batch processing for capsule boundaries
```

## Project-Specific Guidelines

### **Anigma Architecture Compliance**
1. **Always use three-tier boundaries** - Don't mix governance with capabilities
2. **Respect capsule isolation** - Keep native code in appropriate capsules
3. **Enforce Swift 6 concurrency** - Use actors and Sendable types
4. **Maintain audit trails** - All operations should produce evidence

### **Security Requirements**
1. **Never hardcode secrets** - Check for existing vulnerabilities
2. **Validate all inputs** - Especially at capsule boundaries
3. **Use capability checks** - Implement proper permission systems
4. **Maintain auditability** - All mutations should be traceable

### **Accessibility Compliance**
1. **Always add accessibility labels** - Required for DSPS integration
2. **Use Bauhaus design tokens** - No hardcoded UI values
3. **Test with screen readers** - Consider alternative media formats
4. **Support keyboard navigation** - Don't rely solely on mouse/touch

## Common Tasks with Shared memory Integration

### **Setting Up Development Environment**
```bash
# Check memory for setup instructions
memory_store(mode: "search", query: "development setup", scope: "project")

# If not found, follow standard pattern:
# 1. swift build
# 2. ./build.sh warmup
# 3. swift test
# 4. Add to memory once confirmed
```

### **Adding New Dependencies**
```bash
# Check for dependency patterns
memory_store(mode: "search", query: "dependency management", scope: "project")

# Follow conventions:
# - Use Swift Package Manager
# - Avoid hardcoded paths
# - Document unsafeFlags
# - Update Package.swift with proper versioning
```

### **Creating New Capsules**
```bash
# Reference existing capsule patterns
memory_store(mode: "search", query: "capsule template", scope: "project")

# Standard structure:
# - CapsuleCore integration
# - Native shims if needed
# - ANE optimization where applicable
# - Comprehensive test suite
# - MANIFEST.toml with tier declaration
```

## Quality Gates Reference

### **CI/CD Requirements**
```bash
# Always check these gates pass:
# 1. ERROR_MODEL - No public API throws non-CapsuleError
2. DIAGNOSTICS_CONFORMANCE - No print/NSLog/os_log
3. BUILD_HYGIENE - No hardcoded paths, documented flags
4. TEST_COVERAGE - Tier-based coverage requirements
5. TIER_VALIDATION - Valid MANIFEST.toml
```

### **Local Validation**
```bash
# Run before pushing:
./scripts/validate_gates.sh [--verbose] [--capsule CAPSULE_NAME]
```

## Emergency Procedures

### **Build Failures**
1. Check `memory_store(mode: "search", query: "build errors", scope: "project")`
2. Look for known issues (VizAggregationCapsule, concurrency warnings)
3. Follow remediation patterns from memory

### **Security Issues**
1. Immediately remove any hardcoded secrets
2. Check for similar patterns in memory
3. Update memory with prevention strategies

### **Performance Problems**
1. Reference ANE optimization patterns
2. Check actor-based concurrency usage
3. Review capsule boundary efficiency

## Related Documentation
- **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Worktree plugin usage
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory integration
- **[AGENTS_QUICKREF.md](AGENTS_QUICKREF.md)** - Quick reference commands
