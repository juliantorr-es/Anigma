# AGENTS_ROADMAP.md - Roadmap Relevance Pipeline

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

This document covers the pipeline to keep the roadmap relevant by scanning the codebase to track completion and update documentation/Shared memory accordingly.

## Purpose

Maintain roadmap relevance by:
1. **Automatically scanning** the codebase for completed roadmap items
2. **Updating documentation** to reflect current state
3. **Updating Shared memory** with completion insights
4. **Generating progress reports** for planning
5. **Identifying gaps** between roadmap and implementation

## Pipeline Architecture

### **Three-Phase Pipeline:**

#### **Phase 1: Codebase Scanning**
- Scan source code for implemented features
- Analyze commit history for completion markers
- Check test coverage for feature validation
- Review documentation for implementation status

#### **Phase 2: Roadmap Analysis**
- Parse roadmap files for planned items
- Extract completion criteria and requirements
- Map codebase features to roadmap items
- Calculate completion percentages

#### **Phase 3: Documentation & Memory Updates**
- Update roadmap documentation with completion status
- Add implementation insights to Shared memory
- Generate progress reports
- Identify next priorities

## Implementation Details

### **1. Codebase Scanning Engine**

#### **Feature Detection Patterns:**
```bash
# Scan for capsule implementations
find . -name "*.swift" -type f | xargs grep -l "class.*Capsule\|struct.*Capsule" | grep -v "Tests"

# Check for test coverage
find . -path "*/Tests/*" -name "*.swift" | wc -l

# Analyze commit history for feature completion
git log --oneline --grep="feat:" --since="90 days ago"

# Check documentation references
find . -name "*.md" -type f | xargs grep -l "IMPLEMENTATION_STATUS\|TODO\|FIXME"
```

#### **Completion Criteria:**
1. **Source Code Present** - Feature implemented in source files
2. **Tests Exist** - Comprehensive test coverage
3. **Documentation Updated** - Implementation documented
4. **CI Gates Passing** - All quality gates satisfied
5. **No TODO/FIXME markers** - Implementation complete

### **2. Roadmap Parser**

#### **Roadmap Sources:**
- `.auto-claude/roadmap/` - AI-generated roadmap
- `.auto-claude/specs/` - Feature specifications
- `Docs/architecture/` - Architectural plans
- `Tickets/` - Implementation tickets

#### **Parsing Strategy:**
```bash
# Parse roadmap.json for planned features
cat .auto-claude/roadmap/roadmap.json | jq '.features[] | {name, status, priority}'

# Extract spec requirements
find .auto-claude/specs -name "*.md" -exec grep -l "## Requirements" {} \;

# Check ticket completion
find Tickets -name "*.md" -exec grep -l "Status:.*complete\|Status:.*done" {} \;
```

### **3. Mapping Engine**

#### **Feature to Roadmap Mapping:**
1. **Keyword matching** - Match implementation names to roadmap items
2. **Commit analysis** - Link commits to roadmap features
3. **Test coverage mapping** - Map tests to feature requirements
4. **Documentation cross-reference** - Link docs to implementation

#### **Completion Calculation:**
```bash
# Calculate completion percentage
completed_items=$(find_implemented_features | wc -l)
total_items=$(parse_roadmap | wc -l)
completion_percentage=$((completed_items * 100 / total_items))
echo "Roadmap completion: $completion_percentage%"
```

## Pipeline Trigger Points

### **1. Plan Start (Before Implementation)**
**Purpose**: Establish baseline, gather context, set expectations

```bash
#!/bin/bash
# roadmap_plan_start.sh

echo "=== Roadmap Scan: Plan Start ==="

# 1. Check current roadmap completion
ROADMAP_ITEMS=$(cat .auto-claude/roadmap/roadmap.json | jq '.features | length')
COMPLETED_ITEMS=$(cat .auto-claude/roadmap/roadmap.json | jq '.features[] | select(.status == "completed") | length')
COMPLETION_PERCENTAGE=$((COMPLETED_ITEMS * 100 / ROADMAP_ITEMS))
echo "Current roadmap completion: $COMPLETION_PERCENTAGE%"

# 2. Review related features in Shared memory
memory_store(mode: "search", query: "[plan-topic]", scope: "project")
memory_store(mode: "search", query: "implementation patterns", scope: "project")

# 3. Check inspiration repos for relevant patterns
find "/Users/user/Developer/Repos for Inspiration/" -type d -name "*[plan-topic]*" -o -name "*related*"

# 4. Set baseline for this plan
memory_store(mode: "add", content: "Plan start: [plan-name] - Current completion: $COMPLETION_PERCENTAGE% - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "project-config", scope: "project")

# 5. Define success criteria
echo "Success criteria for [plan-name]:"
echo "- Implement [specific-feature]"
echo "- Achieve [test-coverage]% test coverage"
echo "- Update documentation"
echo "- Pass all CI gates"
```

### **2. Plan End (After Implementation)**
**Purpose**: Update completion, capture learnings, generate reports

```bash
#!/bin/bash
# roadmap_plan_end.sh

echo "=== Roadmap Scan: Plan End ==="

# 1. Scan for implemented features from this plan
IMPLEMENTED_FEATURES=$(git log --oneline --since="[plan-start-date]" --grep="feat:\|fix:\|perf:" | grep -i "[plan-keywords]")
echo "Features implemented in this plan:"
echo "$IMPLEMENTED_FEATURES"

# 2. Update roadmap completion
# Parse roadmap.json and update status for completed items
update_roadmap_completion() {
  # Update roadmap.json with completed status
  # This would be a more complex JSON manipulation
  echo "Updating roadmap completion status..."
}

# 3. Calculate new completion percentage
NEW_COMPLETED=$(cat .auto-claude/roadmap/roadmap.json | jq '.features[] | select(.status == "completed") | length')
NEW_PERCENTAGE=$((NEW_COMPLETED * 100 / ROADMAP_ITEMS))
DELTA=$((NEW_PERCENTAGE - COMPLETION_PERCENTAGE))
echo "New completion: $NEW_PERCENTAGE% (Δ $DELTA%)"

# 4. Add implementation insights to Shared memory
memory_store(mode: "add", content: "Plan completed: [plan-name] - Implemented: [features] - Completion delta: +$DELTA% - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")

# 5. Update documentation
generate_implementation_docs() {
  # Generate/update implementation documentation
  echo "Updating documentation for [plan-name]..."
}

# 6. Generate progress report
generate_progress_report() {
  echo "=== Progress Report: [plan-name] ==="
  echo "Date: $(date +%Y-%m-%d)"
  echo "Plan: [plan-name]"
  echo "Features implemented: [count]"
  echo "Roadmap completion: $NEW_PERCENTAGE% (+$DELTA%)"
  echo "Tests added: [count]"
  echo "Documentation updated: [yes/no]"
  echo "CI gates passed: [yes/no]"
  echo "Key learnings: [insights]"
}

update_roadmap_completion
generate_implementation_docs
generate_progress_report
```

### **3. Weekly Automated Scan (First Commit Trigger)**
**Purpose**: Overall system health, cross-plan tracking, team reporting

#### **Trigger Mechanism:**
**Git Pre-Commit Hook** - Automatically triggers on first commit of the week:

```bash
# Git pre-commit hook: .git/hooks/pre-commit
#!/bin/bash
# This hook runs before every commit

# Check if this is the first commit of the week
LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "1970-01-01")
CURRENT_DATE=$(date +%Y-%m-%d)
LAST_MONDAY=$(date -v-monday +%Y-%m-%d 2>/dev/null || date -d "last monday" +%Y-%m-%d)

# If last commit was before this Monday, trigger weekly scan
if [[ "$LAST_COMMIT_DATE" < "$LAST_MONDAY" ]]; then
  echo "=== First commit of the week detected ==="
  echo "Last commit: $LAST_COMMIT_DATE | Today: $CURRENT_DATE"
  echo "Running weekly roadmap scan..."
  
  # Run weekly scan
  ./scripts/roadmap_weekly_scan.sh
  
  # Ask for confirmation to continue with commit
  read -p "Weekly scan complete. Continue with commit? (y/n): " CONTINUE
  if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
    echo "Commit cancelled. Review scan results first."
    exit 1
  fi
fi

# Continue with normal commit
exit 0
```

#### **Alternative: Agent-Triggered Scan**
If you prefer not to use git hooks, I can detect first commit of the week:

```bash
# When you're about to make your first commit of the week, I'll detect:
LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "1970-01-01")
CURRENT_DATE=$(date +%Y-%m-%d)
LAST_MONDAY=$(date -v-monday +%Y-%m-%d 2>/dev/null || date -d "last monday" +%Y-%m-%d)

if [[ "$LAST_COMMIT_DATE" < "$LAST_MONDAY" ]]; then
  echo "This appears to be your first commit of the week."
  echo "Would you like to run the weekly roadmap scan before committing?"
  
  # Options:
  # 1. Run scan, then commit
  # 2. Skip scan, commit anyway
  # 3. View last week's report first
fi
```

#### **Weekly Scan Script (First Commit Version):**
```bash
#!/bin/bash
# scripts/roadmap_weekly_scan.sh

echo "=== Weekly Roadmap Scan - $(date +%Y-%m-%d) ==="
echo "Trigger: First commit of the week"

# 1. Check if this makes sense (optional, can remove)
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" != "1" ]; then
  echo "Note: Today is not Monday, but that's OK with first-commit trigger."
fi

# 2. Overall progress tracking
echo "--- Overall Progress ---"
ROADMAP_ITEMS=$(cat .auto-claude/roadmap/roadmap.json | jq '.features | length')
COMPLETED_ITEMS=$(cat .auto-claude/roadmap/roadmap.json | jq '.features[] | select(.status == "completed") | length')
COMPLETION_PERCENTAGE=$((COMPLETED_ITEMS * 100 / ROADMAP_ITEMS))
echo "Roadmap completion: $COMPLETION_PERCENTAGE% ($COMPLETED_ITEMS/$ROADMAP_ITEMS)"

# 3. Recent activity (last 7 days)
echo "--- Recent Activity (Last 7 Days) ---"
RECENT_COMMITS=$(git log --oneline --since="7 days ago" | wc -l)
RECENT_FEATURES=$(git log --oneline --since="7 days ago" --grep="feat:" | wc -l)
RECENT_FIXES=$(git log --oneline --since="7 days ago" --grep="fix:" | wc -l)
echo "Commits: $RECENT_COMMITS | Features: $RECENT_FEATURES | Fixes: $RECENT_FIXES"

# 4. Active plans/worktrees
echo "--- Active Development ---"
ACTIVE_WORKTREES=$(git worktree list | grep -v "(bare)" | wc -l)
ACTIVE_BRANCHES=$(git branch | grep -v "main" | wc -l)
echo "Active worktrees: $ACTIVE_WORKTREES | Active branches: $ACTIVE_BRANCHES"

# 5. Quality metrics
echo "--- Quality Metrics ---"
TODO_COUNT=$(find . -name "*.swift" -type f -exec grep -l "TODO\|FIXME" {} \; | wc -l)
TEST_COUNT=$(find . -path "*/Tests/*" -name "*.swift" | wc -l)
echo "TODO/FIXME markers: $TODO_COUNT | Test files: $TEST_COUNT"

# 6. Update Shared memory
memory_store(mode: "add", content: "Weekly scan $(date +%Y-%m-%d): Roadmap $COMPLETION_PERCENTAGE% complete, $RECENT_COMMITS commits, $ACTIVE_WORKTREES worktrees - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "project-config", scope: "project")

# 7. Generate weekly report
generate_weekly_report() {
  REPORT_FILE=".auto-claude/reports/weekly_$(date +%Y%m%d).md"
  cat > "$REPORT_FILE" << EOF
# Weekly Roadmap Report
## Date: $(date +%Y-%m-%d)

### Summary
- **Roadmap Completion**: $COMPLETION_PERCENTAGE% ($COMPLETED_ITEMS/$ROADMAP_ITEMS)
- **Active Worktrees**: $ACTIVE_WORKTREES
- **Recent Activity**: $RECENT_COMMITS commits ($RECENT_FEATURES features, $RECENT_FIXES fixes)

### Recommendations
1. **Clean up** if active worktrees > 3
2. **Address** if TODO/FIXME count > 50
3. **Review** if test coverage seems low
4. **Plan** based on completion percentage

### Next Actions
- Review completed features
- Update documentation as needed
- Plan next week's focus
EOF
  echo "Weekly report generated: $REPORT_FILE"
}

generate_weekly_report

# 8. Cleanup recommendations
echo "--- Cleanup Recommendations ---"
if [ "$ACTIVE_WORKTREES" -gt 3 ]; then
  echo "⚠️  Warning: $ACTIVE_WORKTREES active worktrees (max recommended: 3)"
  echo "   Consider: git worktree list"
fi

if [ "$TODO_COUNT" -gt 50 ]; then
  echo "⚠️  Warning: $TODO_COUNT TODO/FIXME markers"
  echo "   Consider addressing technical debt"
fi

echo "=== Weekly Scan Complete ==="
```

#### **Setup Instructions:**

##### **Option A: Git Pre-Commit Hook (Recommended)**
```bash
# 1. Make scan script executable
chmod +x scripts/roadmap_weekly_scan.sh

# 2. Create git pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Weekly roadmap scan trigger on first commit of the week

# Get last commit date
LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "1970-01-01")
CURRENT_DATE=$(date +%Y-%m-%d)

# Calculate last Monday
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  LAST_MONDAY=$(date -v-monday +%Y-%m-%d)
else
  # Linux
  LAST_MONDAY=$(date -d "last monday" +%Y-%m-%d)
fi

# Check if last commit was before this Monday
if [[ "$LAST_COMMIT_DATE" < "$LAST_MONDAY" ]]; then
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║          FIRST COMMIT OF THE WEEK DETECTED              ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║ Last commit: $LAST_COMMIT_DATE"
  echo "║ Today:       $CURRENT_DATE"
  echo "║"
  echo "║ Running weekly roadmap scan..."
  echo "╚══════════════════════════════════════════════════════════╝"
  
  # Run weekly scan
  if [ -f "./scripts/roadmap_weekly_scan.sh" ]; then
    ./scripts/roadmap_weekly_scan.sh
  else
    echo "Warning: Weekly scan script not found at ./scripts/roadmap_weekly_scan.sh"
  fi
  
  # Ask for confirmation
  echo ""
  read -p "Continue with commit? (y/n): " CONTINUE
  if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
    echo "Commit cancelled. Review scan results first."
    exit 1
  fi
fi

# Continue with commit
exit 0
EOF

# 3. Make hook executable
chmod +x .git/hooks/pre-commit

# 4. Test the hook
echo "Testing hook setup..."
git log -1 --format="%cd" --date=short
```

##### **Option B: Agent Detection (No Git Hook)**
If you prefer not to use git hooks, I'll detect first commit manually:
```bash
# I'll check on every commit attempt:
LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "1970-01-01")
# If last commit was before this Monday, I'll suggest running scan
```

#### **My First Commit Detection:**
When you're about to make your first commit of the week, I'll detect and suggest:
```
"First commit of the week detected!
Last commit: 2025-01-20 | Today: 2025-01-27

Would you like to:
1. Run weekly roadmap scan, then commit (recommended)
2. Commit without scan (skip this week)
3. View last week's report first
4. Run quick scan (summary only)

Choose (1-4):"
```

#### **What Happens After Scan:**
1. **Report generated**: `.auto-claude/reports/weekly_YYYYMMDD.md`
2. **Shared memory updated**: Weekly metrics saved
3. **Recommendations provided**: Cleanup and planning suggestions
4. **You review**: Quick overview of project health
5. **You plan**: Use insights to plan the week's work

## Integration with Existing Systems

### **Shared memory Integration:**
```bash
# Add roadmap completion insights
memory_store(mode: "add", content: "Roadmap completion: [percentage]% - [completed]/[total] features - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "project-config", scope: "project")

# Add feature implementation patterns
memory_store(mode: "add", content: "Feature [name] implemented: [details] - Source: roadmap scan - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "learned-pattern", scope: "project")

# Track roadmap evolution
memory_store(mode: "add", content: "Roadmap evolution: [changes] - Updated: $(date +%Y-%m-%d %H:%M:%S)", type: "project-config", scope: "project")
```

### **Documentation Updates:**
1. **Update roadmap.md** with completion status
2. **Generate IMPLEMENTATION_STATUS.md** with current state
3. **Update architecture docs** with implemented features
4. **Create progress reports** for review

### **CI/CD Integration:**
```bash
# Add roadmap scan to CI pipeline
# Weekly automated scan
# Fail if roadmap completion regresses
# Generate reports for team review
```

## Roadmap Relevance Metrics

### **Key Metrics to Track:**
1. **Completion Percentage** - % of roadmap items implemented
2. **Implementation Lag** - Time from planning to implementation
3. **Documentation Coverage** - % of features with updated docs
4. **Test Coverage** - % of features with comprehensive tests
5. **Quality Gate Compliance** - % of features passing all gates

### **Alert Thresholds:**
- **Warning**: <70% roadmap completion
- **Critical**: <50% roadmap completion
- **Documentation Gap**: >30% features without updated docs
- **Test Gap**: >20% features without comprehensive tests

## Automated Documentation Updates

### **Roadmap Status File:**
```markdown
# ROADMAP_STATUS.md
## Generated: $(date +%Y-%m-%d)

### Overall Completion: 75%

### Completed Features:
1. **Capsule System** - 100% complete
   - Implemented: All core capsules
   - Tests: Comprehensive coverage
   - Documentation: Complete
   - CI Gates: All passing

2. **ANE Optimization** - 80% complete
   - Implemented: Core optimizations
   - Tests: Performance benchmarks
   - Documentation: In progress
   - CI Gates: Passing

### In Progress:
1. **Harmonia Module** - 40% complete
   - Next: Tool router implementation
   - ETA: 2 weeks

### Planned:
1. **Accessibility Integration** - 0% complete
   - Priority: High
   - Start: Next quarter
```

### **Implementation Insights File:**
```markdown
# IMPLEMENTATION_INSIGHTS.md
## Generated: $(date +%Y-%m-%d)

### Patterns Discovered:
1. **Capsule implementation takes 2-3 weeks** on average
2. **Test coverage requirement**: 80% for Tier 5 capsules
3. **Common bottlenecks**: ANE optimization, concurrency safety
4. **Documentation lag**: 1 week after implementation typical

### Recommendations:
1. **Increase test automation** for faster validation
2. **Standardize capsule templates** for consistency
3. **Improve documentation workflow** to reduce lag
4. **Focus on ANE optimization patterns** for performance
```

## Manual Review Process

### **Weekly Review Meeting:**
1. **Review automated scan results**
2. **Validate completion assessments**
3. **Adjust roadmap priorities** based on findings
4. **Update Shared memory** with review insights
5. **Plan next week's focus** based on gaps

### **Monthly Deep Dive:**
1. **Analyze implementation patterns**
2. **Identify systemic issues**
3. **Update architectural decisions**
4. **Adjust roadmap timeline**
5. **Generate quarterly planning insights**

## Integration with Digestion Pipeline

### **Cross-Reference Inspiration:**
```bash
# Check if inspiration patterns have been implemented
memory_store(mode: "search", query: "architecture-pattern source:", scope: "project") | grep -v "implemented"

# Map inspiration patterns to roadmap items
# Track which patterns have been integrated
# Update roadmap with new inspiration opportunities
```

### **Roadmap from Inspiration:**
1. **Scan digested patterns** from inspiration repos
2. **Identify applicable patterns** for Anigma
3. **Add to roadmap** as new features
4. **Track implementation progress**
5. **Update Shared memory** with integration results

## Emergency Procedures

### **Roadmap Drift Detected:**
```bash
# If roadmap completion drops >10%
# 1. Analyze root cause
# 2. Update roadmap priorities
# 3. Adjust implementation focus
# 4. Update Shared memory with corrective actions
```

### **Documentation Lag:**
```bash
# If documentation coverage <70%
# 1. Prioritize documentation updates
# 2. Update Shared memory with documentation patterns
# 3. Adjust workflow to include documentation
# 4. Generate documentation debt report
```

### **Test Coverage Gaps:**
```bash
# If test coverage <80% for Tier 5 features
# 1. Prioritize test implementation
# 2. Update Shared memory with test patterns
# 3. Adjust CI gates to enforce coverage
# 4. Generate test debt report
```

## Implementation Schedule

### **Daily:**
- Monitor implementation progress via commits
- Update Shared memory with daily insights

### **Weekly (Monday):**
- Run automated roadmap scan
- Update documentation
- Generate progress reports
- Review with team

### **Monthly (First Monday):**
- Deep dive analysis
- Update architectural decisions
- Adjust roadmap timeline
- Generate quarterly insights

### **Quarterly:**
- Major roadmap revision
- Architectural review
- Tooling and workflow updates
- Long-term planning

## Related Documentation
- **[AGENTS_DIGESTION.md](AGENTS_DIGESTION.md)** - Inspiration analysis pipeline
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory system integration
- **[AGENTS_GIT.md](AGENTS_GIT.md)** - Workflow and commit tracking
- **** - Overview and quick start
