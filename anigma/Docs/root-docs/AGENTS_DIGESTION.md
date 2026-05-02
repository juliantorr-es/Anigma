# AGENTS_DIGESTION.md - Inspiration Repo Analysis Pipeline

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

This document covers the Shared memory digestion pipeline for analyzing inspiration repositories to inform the development roadmap.

## Purpose

Analyze inspiration repositories in `/Users/user/Developer/Repos for Inspiration/` to:
1. Discover patterns and best practices
2. Identify architectural innovations
3. Extract reusable components
4. Inform development roadmap
5. Avoid reinventing solutions

## Pipeline Stages

### **Stage 1: Repository Discovery**
```bash
# List all inspiration repos
find "/Users/user/Developer/Repos for Inspiration/" -maxdepth 1 -type d | grep -v "^\.$"

# Categorize repos by type
# - OpenCode plugins
# - AI assistants
# - Development tools
# - Architecture examples
```

### **Stage 2: Pattern Extraction**
For each relevant repo:
1. **Read README.md** - Understand purpose and features
2. **Analyze package.json** - Identify dependencies and tooling
3. **Examine source structure** - Learn architectural patterns
4. **Review key files** - Extract implementation insights
5. **Document patterns** - Save to Shared memory with categorization

### **Stage 3: Memory Categorization & Cleanup**
```bash
# Save extracted patterns to Shared memory
memory_store(mode: "add", content: "[Pattern from repo] - Source: [repo-name] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")

# Categorize by:
# - architecture-pattern (system design)
# - tooling-pattern (build/dev tools)
# - ui-pattern (interface design)
# - workflow-pattern (development processes)
# - integration-pattern (system integration)

# Clean up digested repo (once fully processed)
rm -rf "/Users/user/Developer/Repos for Inspiration/[repo-name]"
echo "Digested and removed: [repo-name]"
```

### **Stage 4: Roadmap Integration & Verification**
1. **Compare with current Anigma architecture**
2. **Identify gaps and opportunities**
3. **Prioritize based on project goals**
4. **Create roadmap items** with inspiration references
5. **Update development priorities**
6. **Verify cleanup**: Ensure repo was properly removed

## Key Inspiration Repos to Analyze

### **1. OpenCode Plugins:**
- **opencode-memory_store** - Persistent memory patterns
- **opencode-worktree** - Git worktree automation
- **opencode-pty** - Terminal session management
- **opencode-dynamic-context-pruning** - Context optimization

### **2. AI Assistants:**
- **clawdbot** - Multi-channel AI assistant architecture
- Personal AI assistant patterns for institutional adaptation

### **3. Development Tools:**
- **eigent** - Advanced development tooling
- Other specialized development utilities

## Digestion Schedule

### **Weekly Digestion (Friday):**
- Analyze 1-2 new inspiration repos
- Extract key patterns
- Update Shared memory with findings
- Create roadmap suggestions

### **Monthly Synthesis (End of month):**
- Review all digested patterns
- Identify recurring themes
- Update architectural decisions
- Adjust development roadmap

### **Quarterly Integration (Quarter boundaries):**
- Major pattern integration into Anigma
- Architectural refinements based on learnings
- Tooling and workflow updates

## Memory Format for Inspiration Patterns

### **Example: Extracting worktree patterns**
```bash
memory_store(mode: "add", content: "Git worktree automation: Isolated development environments with automatic terminal spawning - Source: opencode-worktree - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "workflow-pattern", scope: "project")
```

### **Example: Extracting memory patterns**
```bash
memory_store(mode: "add", content: "Persistent memory across sessions: API-based memory system with project/user scoping - Source: opencode-memory_store - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "architecture-pattern", scope: "project")
```

## Integration with Development Workflow

### **Before starting new features:**
```bash
# Check for inspiration patterns
memory_store(mode: "search", query: "architecture-pattern", scope: "project")
memory_store(mode: "search", query: "workflow-pattern", scope: "project")
```

### **When solving problems:**
```bash
# Look for existing solutions in inspiration repos
memory_store(mode: "search", query: "error-solution source:", scope: "project")
```

### **During architecture decisions:**
```bash
# Reference proven patterns
memory_store(mode: "search", query: "architecture-pattern validated:true", scope: "project")
```

### **When optimizing workflows:**
```bash
# Apply learned best practices
memory_store(mode: "search", query: "workflow-pattern efficiency", scope: "project")
```

## Quality Standards for Digested Patterns

### **1. Must be relevant** to Anigma's institutional focus
- Educational/government use cases
- Local-first architecture
- Governance and compliance requirements
- Accessibility focus

### **2. Must be compatible** with Swift/Apple ecosystem
- Swift language patterns
- Apple platform integration
- ANE optimization compatibility
- macOS/iOS deployment

### **3. Must align with** governance and security requirements
- Audit trail compatibility
- Data sovereignty considerations
- Security best practices
- Compliance requirements

### **4. Must be tested/validated** in source repos
- Working implementations
- Production usage evidence
- Community validation
- Performance metrics

### **5. Must include attribution** to source repository
- Clear source identification
- License compatibility check
- Contribution acknowledgment
- Pattern origin tracking

## Digestion Workflow Example

### **Processing opencode-worktree:**
```bash
# 1. Discover repo
find "/Users/user/Developer/Repos for Inspiration/" -name "opencode-worktree"

# 2. Extract patterns
# - Read README: Git worktree automation with terminal spawning
# - Analyze structure: Plugin architecture, configuration patterns
# - Review key files: Worktree creation logic, terminal integration

# 3. Save to Shared memory
memory_store(mode: "add", content: "Git worktree automation: Isolated development environments with automatic terminal spawning - Source: opencode-worktree - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "workflow-pattern", scope: "project")

# 4. Clean up
rm -rf "/Users/user/Developer/Repos for Inspiration/opencode-worktree"
echo "Digested and removed: opencode-worktree"

# 5. Verify cleanup
ls "/Users/user/Developer/Repos for Inspiration/" | grep -q "opencode-worktree" || echo "Cleanup verified"
```

### **Processing clawdbot:**
```bash
# 1. Discover repo
find "/Users/user/Developer/Repos for Inspiration/" -name "clawdbot"

# 2. Extract patterns
# - Read README: Multi-channel AI assistant architecture
# - Analyze structure: Channel integration patterns, message routing
# - Review key files: Plugin system, configuration management

# 3. Save to Shared memory
memory_store(mode: "add", content: "Multi-channel AI assistant: WhatsApp/Telegram/Slack/Discord integration with plugin architecture - Source: clawdbot - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "architecture-pattern", scope: "project")

# 4. Clean up
rm -rf "/Users/user/Developer/Repos for Inspiration/clawdbot"
echo "Digested and removed: clawdbot"

# 5. Verify cleanup
ls "/Users/user/Developer/Repos for Inspiration/" | grep -q "clawdbot" || echo "Cleanup verified"
```

## Roadmap Integration Process

### **1. Pattern Analysis**
- Compare extracted patterns with current Anigma architecture
- Identify gaps where inspiration patterns could improve Anigma
- Assess compatibility with existing systems

### **2. Opportunity Identification**
- **Architecture gaps**: Missing patterns that could enhance design
- **Tooling opportunities**: Development tools that could improve workflow
- **Integration possibilities**: Systems that could be integrated
- **Performance improvements**: Optimizations that could be applied

### **3. Prioritization**
- **High priority**: Critical architecture improvements
- **Medium priority**: Workflow optimizations
- **Low priority**: Nice-to-have features
- **Future consideration**: Long-term architectural directions

### **4. Roadmap Creation**
- Create specific roadmap items with inspiration references
- Define implementation requirements and constraints
- Estimate effort and impact
- Schedule integration based on priority

### **5. Implementation Tracking**
- Track pattern integration progress
- Update Shared memory with implementation results
- Adjust roadmap based on learning
- Document successful integrations

## Best Practices

### **Digestion Process**
1. **Complete analysis before cleanup** - Don't delete repos prematurely
2. **Extract all valuable patterns** - Be thorough in analysis
3. **Save to Shared memory immediately** - Don't lose insights
4. **Verify cleanup** - Ensure repos are properly removed
5. **Update roadmap** - Integrate learnings into planning

### **Pattern Selection**
1. **Focus on relevance** - Prioritize patterns that align with Anigma's goals
2. **Consider compatibility** - Ensure patterns work with Swift/Apple ecosystem
3. **Validate effectiveness** - Look for proven implementations
4. **Assess maintainability** - Choose patterns that are sustainable

### **Memory Management**
1. **Use appropriate types** - Categorize patterns correctly
2. **Include source attribution** - Always credit source repos
3. **Add timestamps** - Required for housekeeping
4. **Regularly review** - Keep inspiration patterns current

## Related Documentation
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory system integration
- **** - Overview and quick start
- **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Plugin usage patterns
