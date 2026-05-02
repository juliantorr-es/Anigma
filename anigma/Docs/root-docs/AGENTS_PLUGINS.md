# AGENTS_PLUGINS.md - OpenCode Plugin Integration

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

This document covers OpenCode plugin usage for the Anigma codebase.

## Available Plugins

### **1. Worktree Plugin** (`worktree_create`, `worktree_delete`)
- **Purpose**: Create isolated git worktrees for parallel development
- **Features**:
  - Spawn new terminals in worktree directories
  - Automatic cleanup after completion
  - Isolated development environments

### **2. KDCO Primitives** (utility functions)
- `get-project-id.ts` - Project identification
- `mutex.ts` - Resource locking for concurrent operations
- `shell.ts` - Cross-platform shell command execution
- `temp.ts` - Temporary file management
- `terminal-detect.ts` - Terminal detection and spawning
- `with-timeout.ts` - Timeout management for async operations

### **3. Anigma CI Tools** (custom governance gates)
- `anigma_ci_all` - Run all governance gates
- `anigma_swift6_check` - Swift 6 compliance validation
- `anigma_type_authority_check` - Type authority boundary validation
- `anigma_deps_check` - Dependency boundary validation
- `anigma_escape_hatches_check` - Escape hatch validation
- `anigma_macro_expansion_check` - Macro expansion analysis
- `anigma_mainactor_drift_report` - MainActor drift analysis

## Plugin Usage Patterns

### **Worktree Management**
```bash
# Create isolated worktree for feature development
worktree_create(branch: "feat/new-capsule", baseBranch: "main")

# Delete worktree after completion
worktree_delete(reason: "Feature implementation complete")
```

### **CI Gate Validation**
```bash
# Run all governance gates
anigma_ci_all()

# Check Swift 6 compliance for specific target
anigma_swift6_check(target: "HarmoniaModule")

# Validate type authority boundaries
anigma_type_authority_check()
```

### **Utility Functions**
```bash
# Use mutex for concurrent operations
# Use shell.ts for cross-platform shell commands
# Use temp.ts for temporary file management
# Use with-timeout.ts for async operation timeouts
```

## Integration with Shared memory

### **Before Using Plugins**
```bash
# Check for existing patterns
memory_store(mode: "search", query: "worktree patterns", scope: "project")
memory_store(mode: "search", query: "CI gate results", scope: "project")
```

### **After Using Plugins**
```bash
# Save successful patterns
memory_store(mode: "add", content: "Worktree pattern: [description] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "workflow-pattern", scope: "project")

# Save CI gate results
memory_store(mode: "add", content: "CI gate results: [summary] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "project-config", scope: "project")
```

## Common Workflows

### **New Feature Development**
```bash
# 1. Create worktree
worktree_create(branch: "feat/[feature]-$(date +%Y%m%d)", baseBranch: "main")

# 2. Implement feature

# 3. Run CI gates
anigma_ci_all()

# 4. Clean up
worktree_delete(reason: "Feature complete")
```

### **Bug Fix Workflow**
```bash
# 1. Create worktree for fix
worktree_create(branch: "fix/[bug]-$(date +%Y%m%d)", baseBranch: "main")

# 2. Fix bug

# 3. Validate with specific gates
anigma_swift6_check(target: "[affected-module]")
anigma_type_authority_check()

# 4. Clean up
worktree_delete(reason: "Bug fix complete")
```

### **Performance Optimization**
```bash
# 1. Create worktree for optimization
worktree_create(branch: "perf/[optimization]-$(date +%Y%m%d)", baseBranch: "main")

# 2. Implement optimization

# 3. Run performance gates
anigma_mainactor_drift_report()

# 4. Clean up
worktree_delete(reason: "Optimization complete")
```

## Best Practices

### **Worktree Management**
1. **One worktree per plan** - Multiple tasks can share same worktree
2. **Descriptive branch names** - Include date and purpose
3. **Always clean up** - Delete worktrees after plan completion
4. **Check for stale worktrees** - Weekly audit recommended

### **CI Gate Usage**
1. **Run locally first** - Use `anigma_ci_all()` before pushing
2. **Target specific modules** - Use `target:` parameter for focused checks
3. **Save results** - Add gate results to Shared memory for reference
4. **Fix violations immediately** - Don't accumulate technical debt

### **Utility Functions**
1. **Use mutex for shared resources** - Prevent race conditions
2. **Shell commands via shell.ts** - Cross-platform compatibility
3. **Clean up temp files** - Use temp.ts for automatic cleanup
4. **Set timeouts for async ops** - Prevent hanging operations

## Troubleshooting

### **Worktree Creation Fails**
```bash
# Check for existing worktrees
git worktree list

# Clean up stale worktrees
# Then retry creation
```

### **CI Gate Failures**
```bash
# Check specific gate
anigma_swift6_check(target: "[module]")

# Look for patterns in Shared memory
memory_store(mode: "search", query: "CI gate failure", scope: "project")
```

### **Plugin Not Found**
```bash
# Check plugin installation
ls -la .opencode/plugin/

# Verify OpenCode configuration
cat .opencode/opencode.jsonc
```

## Related Documentation
- **[AGENTS_GIT.md](AGENTS_GIT.md)** - Git workflow integration
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory management
- **[AGENTS_QUICKREF.md](AGENTS_QUICKREF.md)** - Quick reference commands
