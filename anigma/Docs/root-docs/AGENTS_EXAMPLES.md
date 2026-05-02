# AGENTS_EXAMPLES.md - Complete Workflow Examples

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

This document provides complete, end-to-end workflow examples for common agent tasks.

## Example 1: New Capsule Implementation

### **Scenario**: Implement a new PDF processing capsule

### **Step-by-Step Workflow:**

```bash
# 1. Create isolated worktree for the plan
worktree_create(branch: "feat/pdf-capsule-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory for context
memory_store(mode: "search", query: "capsule implementation", scope: "project")
memory_store(mode: "search", query: "PDF processing", scope: "project")
memory_store(mode: "search", query: "native integration", scope: "project")

# 3. Check inspiration repos for patterns
find "/Users/user/Developer/Repos for Inspiration/" -name "*pdf*" -o -name "*document*"
# If found, extract patterns before implementation

# 4. Implement capsule following patterns:
# - Create CapsuleCore integration
# - Add native shims for PDFium
# - Implement OperationResult for async operations
# - Use AnigmaError schema
# - Add accessibility labels for UI elements
# - Use Bauhaus design tokens (no hardcoded colors/fonts)

# 5. Add comprehensive tests
# - Unit tests for core logic
# - Integration tests for native shims
# - Performance tests for large PDFs
# - Accessibility tests for UI components

# 6. Create MANIFEST.toml
# - Name: PDFProcessingCapsule
# - Tier: 3 (initial implementation)
# - Owner: [team-name]
# - Status: active

# 7. Run CI gates locally
./scripts/validate_gates.sh --verbose --capsule PDFProcessingCapsule

# 8. Commit with conventional format
git add .
git commit -m "feat: Add PDF processing capsule
- Implement PDFium native integration
- Add async OperationResult pattern
- Include comprehensive test suite
- Add MANIFEST.toml with Tier 3 declaration
- Ensure Bauhaus design token compliance
- Add accessibility labels for all UI elements"

# 9. Push to remote
git push origin feat/pdf-capsule-$(date +%Y%m%d)

# 10. Create PR (if applicable)
gh pr create --title "feat: Add PDF processing capsule" --body "Implements PDF processing capabilities with native PDFium integration, async operation pattern, and comprehensive testing."

# 11. Clean up worktree
worktree_delete(reason: "PDF capsule implementation complete")

# 12. Update Shared memory
memory_store(mode: "add", content: "PDF capsule pattern: Native PDFium integration with async OperationResult - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")
memory_store(mode: "add", content: "Capsule implementation workflow: Check Shared memory → Create worktree → Implement → Test → Validate gates → Commit → Clean up - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "workflow-pattern", scope: "project")

# 13. Perform memory housekeeping
# Review stale memories, update timestamps, promote/archive as needed
```

## Example 2: Bug Fix for Concurrency Issue

### **Scenario**: Fix Swift 6 concurrency warnings in VizAggregationCapsule

### **Step-by-Step Workflow:**

```bash
# 1. Create isolated worktree
worktree_create(branch: "fix/concurrency-vizaggregation-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory for known issues
memory_store(mode: "search", query: "VizAggregationCapsule", scope: "project")
memory_store(mode: "search", query: "Swift 6 concurrency", scope: "project")
memory_store(mode: "search", query: "Sendable warnings", scope: "project")

# 3. Analyze the issue
# - Check compilation errors
# - Identify non-Sendable types
# - Review actor isolation boundaries

# 4. Implement fix:
# - Add Sendable conformance where needed
# - Use @unchecked Sendable for type-erased values
# - Ensure proper actor isolation
# - Maintain backward compatibility

# 5. Add tests for concurrency safety
# - Test Sendable type transfers
# - Verify actor isolation
# - Test concurrent access patterns

# 6. Run specific CI gates
anigma_swift6_check(target: "VizAggregationCapsule")
anigma_type_authority_check()

# 7. Commit with conventional format
git add .
git commit -m "fix: Resolve Swift 6 concurrency warnings in VizAggregationCapsule
- Add Sendable conformance to required types
- Use @unchecked Sendable for AnyCodable
- Fix actor isolation boundaries
- Add concurrency safety tests
- Ensure backward compatibility"

# 8. Push to remote
git push origin fix/concurrency-vizaggregation-$(date +%Y%m%d)

# 9. Clean up worktree
worktree_delete(reason: "Concurrency fix complete")

# 10. Update Shared memory
memory_store(mode: "add", content: "Swift 6 concurrency fix pattern: Add Sendable conformance, use @unchecked for type-erased values - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "error-solution", scope: "project")
```

## Example 3: Performance Optimization

### **Scenario**: Optimize ANE (Apple Neural Engine) usage for ML capsule

### **Step-by-Step Workflow:**

```bash
# 1. Create isolated worktree
worktree_create(branch: "perf/ane-optimization-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory for performance patterns
memory_store(mode: "search", query: "ANE optimization", scope: "project")
memory_store(mode: "search", query: "ML performance", scope: "project")
memory_store(mode: "search", query: "hardware acceleration", scope: "project")

# 3. Check inspiration repos
find "/Users/user/Developer/Repos for Inspiration/" -name "*ml*" -o -name "*ane*" -o -name "*performance*"

# 4. Implement optimizations:
# - Batch operations for ANE efficiency
# - Memory reuse patterns
# - Async pipeline optimization
# - Hardware-aware scheduling

# 5. Add performance benchmarks
# - Baseline measurements
# - Optimized measurements
# - Memory usage tracking
# - Energy efficiency metrics

# 6. Run performance gates
anigma_mainactor_drift_report()
# Run custom performance validation

# 7. Commit with conventional format
git add .
git commit -m "perf: Optimize ANE usage for ML capsule
- Implement batch processing for ANE efficiency
- Add memory reuse patterns
- Optimize async pipeline
- Add hardware-aware scheduling
- Include comprehensive benchmarks
- Maintain backward compatibility"

# 8. Push to remote
git push origin perf/ane-optimization-$(date +%Y%m%d)

# 9. Clean up worktree
worktree_delete(reason: "Performance optimization complete")

# 10. Update Shared memory
memory_store(mode: "add", content: "ANE optimization pattern: Batch processing, memory reuse, hardware-aware scheduling - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")
```

## Example 4: Digestion of Inspiration Repo

### **Scenario**: Analyze opencode-worktree for workflow patterns

### **Step-by-Step Workflow:**

```bash
# 1. Discover repo
find "/Users/user/Developer/Repos for Inspiration/" -name "opencode-worktree"

# 2. Extract patterns:
# - Read README: Git worktree automation with terminal spawning
# - Analyze package.json: Dependencies and tooling
# - Examine source structure: Plugin architecture
# - Review key files: Worktree creation, terminal integration

# 3. Save patterns to Shared memory
memory_store(mode: "add", content: "Git worktree automation: Isolated development environments with automatic terminal spawning - Source: opencode-worktree - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "workflow-pattern", scope: "project")

memory_store(mode: "add", content: "Plugin architecture: Clean separation of concerns, configuration management - Source: opencode-worktree - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "architecture-pattern", scope: "project")

# 4. Clean up digested repo
rm -rf "/Users/user/Developer/Repos for Inspiration/opencode-worktree"
echo "Digested and removed: opencode-worktree"

# 5. Verify cleanup
ls "/Users/user/Developer/Repos for Inspiration/" | grep -q "opencode-worktree" || echo "Cleanup verified"

# 6. Update roadmap based on patterns
# - Consider worktree automation improvements
# - Evaluate terminal integration patterns
# - Assess plugin architecture applicability
```

## Example 5: Security Vulnerability Fix

### **Scenario**: Remove hardcoded GitHub token

### **Step-by-Step Workflow:**

```bash
# 1. Create isolated worktree
worktree_create(branch: "security/remove-token-$(date +%Y%m%d)", baseBranch: "main")

# 2. Check Shared memory for security patterns
memory_store(mode: "search", query: "security", scope: "project")
memory_store(mode: "search", query: "hardcoded secrets", scope: "project")

# 3. Identify and fix vulnerability:
# - Find hardcoded token in .auto-claude/.env
# - Remove token from version control
# - Add to .gitignore if appropriate
# - Implement secure configuration pattern

# 4. Add security tests:
# - Secret detection in CI
# - Configuration validation
# - Environment variable checks

# 5. Run security-focused validation
# Check for other hardcoded secrets
# Validate configuration patterns

# 6. Commit with conventional format
git add .
git commit -m "security: Remove hardcoded GitHub token
- Remove token from .auto-claude/.env
- Add secure configuration pattern
- Implement environment variable validation
- Add secret detection to CI
- Update documentation for secure setup"

# 7. Push to remote
git push origin security/remove-token-$(date +%Y%m%d)

# 8. Clean up worktree
worktree_delete(reason: "Security fix complete")

# 9. Update Shared memory
memory_store(mode: "add", content: "Security pattern: Never hardcode secrets, use environment variables - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "security-pattern", scope: "project")
```

## Common Patterns Across Examples

### **1. Always Start with Shared memory**
- Check for existing patterns before implementation
- Learn from previous solutions
- Avoid repeating mistakes

### **2. Use Isolated Worktrees**
- One worktree per plan
- Multiple tasks per worktree
- Clean up after completion

### **3. Follow Complete Workflow**
- Implement → Test → Validate → Commit → Push → Clean up
- Never skip steps
- Maintain consistency

### **4. Update Shared memory**
- Add new insights with timestamps
- Include source attribution
- Categorize appropriately

### **5. Maintain Quality**
- Run CI gates before committing
- Follow project conventions
- Document changes clearly

## Related Documentation
- **** - Overview and structure
- **[AGENTS_QUICKREF.md](AGENTS_QUICKREF.md)** - Quick reference commands
- **[AGENTS_GIT.md](AGENTS_GIT.md)** - Git workflow details
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory system
- **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Plugin usage
## Example X: Enhanced Error Handler Integration

### **Scenario**: Integrate EnhancedErrorHandler into CLI commands for Phase 3 thin client migration

### **Step-by-Step Workflow:**

```swift
// 1. Import the enhanced error handler in your CLI command file
// Note: EnhancedErrorHandler is in the same module (AnigmaCLI)

// 2. Update command execution to use enhanced error handling
func executeCommand() async throws -> String {
    do {
        // Try to execute via daemon
        return try await executeViaDaemon()
    } catch {
        // Use enhanced error handling
        handleCLIError(
            error,
            operation: "chat command",
            verbose: CommandLine.arguments.contains("--verbose")
        )
    }
}

// 3. Alternative: Use the convenience wrapper for async operations
func executeWithErrorHandling() async {
    await withEnhancedErrorHandling(
        operation: "file upload",
        verbose: false
    ) {
        try await uploadFileToDaemon()
    }
}

// 4. For custom error handling with context
func executeWithCustomContext() async {
    let handler = EnhancedErrorHandler.shared
    
    do {
        let result = try await performOperation()
        print(result)
    } catch {
        let enhancedError = await handler.handleError(
            error,
            operation: "custom operation",
            additionalContext: [
                "custom_key": "custom_value",
                "attempt": "2"
            ]
        )
        
        print(enhancedError.formatForCLI(includeTechnical: true))
        exit(1)
    }
}
```

### **Key Integration Points:**

1. **CLI Commands**: Replace generic error handling with `handleCLIError()`
2. **Daemon Communication**: Use `DaemonCommunicationErrorFactory` for common daemon errors
3. **Async Operations**: Use `withEnhancedErrorHandling()` wrapper
4. **Verbose Mode**: Support `--verbose` flag for technical details
5. **Error Context**: Add operation-specific context for better debugging

### **Benefits:**

- **User-Friendly**: Clear, actionable error messages instead of stack traces
- **Recovery Guidance**: Specific suggestions for resolving issues
- **Debugging Support**: Technical details available when needed
- **Analytics Ready**: Error reporting for system improvement
- **Consistent UX**: Uniform error handling across all CLI commands
