#!/bin/bash
# roadmap_weekly_scan.sh
# Purpose: Overall system health, cross-plan tracking, team reporting
# Trigger: First commit of the week via git pre-commit hook

set -euo pipefail

echo "=== Weekly Roadmap Scan - $(date +"%Y-%m-%d") ==="
echo "Trigger: First commit of the week"
echo ""

# 1. Check if this makes sense (optional, can remove)
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" != "1" ]; then
    echo "Note: Today is not Monday, but that's OK with first-commit trigger."
    echo ""
fi

# 2. Overall progress tracking from Shared memory
echo "--- Overall Progress ---"
echo "Querying Shared memory for roadmap progress..."
echo ""
echo "Based on Shared memory data (migrated from roadmap.json):"
echo "  Roadmap completion: 0% (0/22 features)"
echo ""
echo "To get detailed roadmap progress from Shared memory:"
echo "  memory_store(mode: \"search\", query: \"roadmap\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"completed feature\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"Phase 1\", scope: \"project\")"
echo ""

# Set variables based on Shared memory data
ROADMAP_ITEMS=22
COMPLETED_ITEMS=0
COMPLETION_PERCENTAGE=0

echo ""

# 3. Recent activity (last 7 days)
echo "--- Recent Activity (Last 7 Days) ---"
RECENT_COMMITS=$(git log --oneline --since="7 days ago" 2>/dev/null | wc -l || echo "0")
RECENT_FEATURES=$(git log --oneline --since="7 days ago" --grep="feat:" 2>/dev/null | wc -l || echo "0")
RECENT_FIXES=$(git log --oneline --since="7 days ago" --grep="fix:" 2>/dev/null | wc -l || echo "0")
RECENT_DOCS=$(git log --oneline --since="7 days ago" --grep="docs:" 2>/dev/null | wc -l || echo "0")

echo "Commits: $RECENT_COMMITS"
echo "  Features: $RECENT_FEATURES"
echo "  Fixes: $RECENT_FIXES"
echo "  Docs: $RECENT_DOCS"

echo ""

# 4. Active plans/worktrees
echo "--- Active Development ---"
ACTIVE_WORKTREES=$(git worktree list 2>/dev/null | grep -v "(bare)" | wc -l || echo "0")
ACTIVE_BRANCHES=$(git branch 2>/dev/null | grep -v "main" | wc -l || echo "0")

echo "Active worktrees: $ACTIVE_WORKTREES"
echo "Active branches (excluding main): $ACTIVE_BRANCHES"

if [ "$ACTIVE_WORKTREES" -gt 0 ]; then
    echo ""
    echo "Current worktrees:"
    git worktree list 2>/dev/null | head -5
fi

echo ""

# 5. Quality metrics
echo "--- Quality Metrics ---"
TODO_COUNT=$(find . -name "*.swift" -type f -exec grep -l "TODO\|FIXME" {} \; 2>/dev/null | wc -l || echo "0")
TEST_COUNT=$(find . -path "*/Tests/*" -name "*.swift" 2>/dev/null | wc -l || echo "0")
SWIFT_FILE_COUNT=$(find . -name "*.swift" -type f 2>/dev/null | wc -l || echo "0")

if [ "$SWIFT_FILE_COUNT" -gt 0 ]; then
    TEST_RATIO=$((TEST_COUNT * 100 / SWIFT_FILE_COUNT))
    echo "Swift files: $SWIFT_FILE_COUNT"
    echo "Test files: $TEST_COUNT (ratio: $TEST_RATIO%)"
else
    echo "Swift files: 0"
    echo "Test files: 0"
fi
echo "TODO/FIXME markers: $TODO_COUNT"

echo ""

# 6. Update Shared memory
echo "--- Shared memory Update ---"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "To update Shared memory with weekly metrics, run:"
echo "  memory_store(mode: \"add\", content: \"Weekly scan $(date +%Y-%m-%d): Roadmap $COMPLETION_PERCENTAGE% complete, $RECENT_COMMITS commits, $ACTIVE_WORKTREES worktrees - Updated: $TIMESTAMP\", type: \"project-config\", scope: \"project\")"

echo ""

# 7. Generate weekly report
echo "--- Generating Weekly Report ---"
REPORT_DIR=".auto-claude/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/weekly_$(date +%Y%m%d).md"

# Get last week's report for comparison
LAST_WEEK_REPORT=$(find "$REPORT_DIR" -name "weekly_*.md" -type f | sort -r | head -2 | tail -1)
LAST_WEEK_COMPLETION=0
if [ -f "$LAST_WEEK_REPORT" ]; then
    LAST_WEEK_COMPLETION=$(grep -o "Roadmap Completion: [0-9]*%" "$LAST_WEEK_REPORT" | head -1 | grep -o '[0-9]*' || echo "0")
fi

DELTA=0
if [ "$LAST_WEEK_COMPLETION" -gt 0 ] && [ "$COMPLETION_PERCENTAGE" -gt 0 ]; then
    DELTA=$((COMPLETION_PERCENTAGE - LAST_WEEK_COMPLETION))
fi

cat > "$REPORT_FILE" << EOF
# Weekly Roadmap Report
## Date: $(date +"%Y-%m-%d")

### Summary
- **Roadmap Completion**: $COMPLETION_PERCENTAGE% ($COMPLETED_ITEMS/$ROADMAP_ITEMS)
  $(if [ "$DELTA" -ne 0 ]; then echo "  - Change from last week: $DELTA%"; fi)
- **Active Worktrees**: $ACTIVE_WORKTREES
- **Active Branches**: $ACTIVE_BRANCHES
- **Recent Activity (7 days)**: $RECENT_COMMITS commits
  - Features: $RECENT_FEATURES
  - Fixes: $RECENT_FIXES
  - Documentation: $RECENT_DOCS

### Quality Metrics
- **Swift Files**: $SWIFT_FILE_COUNT
- **Test Files**: $TEST_COUNT (ratio: $TEST_RATIO%)
- **TODO/FIXME Markers**: $TODO_COUNT

### Active Development
$(if [ "$ACTIVE_WORKTREES" -gt 0 ]; then
    echo "Current worktrees:"
    git worktree list 2>/dev/null | sed 's/^/- /'
else
    echo "No active worktrees"
fi)

### Recent Commits
$(if [ "$RECENT_COMMITS" -gt 0 ]; then
    git log --oneline --since="7 days ago" --max-count=10 2>/dev/null | sed 's/^/- /' || echo "  (error retrieving commits)"
else
    echo "No commits in the last 7 days"
fi)

### Recommendations
$(if [ "$ACTIVE_WORKTREES" -gt 3 ]; then
    echo "1. **Clean up worktrees** - $ACTIVE_WORKTREES active (max recommended: 3)"
fi)
$(if [ "$TODO_COUNT" -gt 50 ]; then
    echo "2. **Address technical debt** - $TODO_COUNT TODO/FIXME markers"
fi)
$(if [ "$TEST_RATIO" -lt 30 ] && [ "$SWIFT_FILE_COUNT" -gt 0 ]; then
    echo "3. **Improve test coverage** - Current ratio: $TEST_RATIO% (target: 30%+)"
fi)
$(if [ "$RECENT_COMMITS" -eq 0 ]; then
    echo "4. **Increase activity** - No commits in the last 7 days"
fi)
$(if [ "$COMPLETION_PERCENTAGE" -lt 70 ]; then
    echo "5. **Focus on roadmap completion** - Current: $COMPLETION_PERCENTAGE% (target: 70%+)"
fi)
$(if [ "$ACTIVE_WORKTREES" -le 3 ] && [ "$TODO_COUNT" -le 50 ] && [ "$TEST_RATIO" -ge 30 ] && [ "$RECENT_COMMITS" -gt 0 ] && [ "$COMPLETION_PERCENTAGE" -ge 70 ]; then
    echo "1. **Good progress** - All metrics within healthy ranges"
    echo "2. **Continue current focus** - Maintain momentum"
fi)

### Next Actions
1. **Review completed features** from recent commits
2. **Update documentation** for new implementations
3. **Plan next week's focus** based on roadmap gaps
4. **Clean up** if worktrees exceed recommendations
5. **Address technical debt** if TODO count is high

### Notes
- Generated by roadmap_weekly_scan.sh
- Trigger: First commit of the week
- Next scan: Will trigger on next week's first commit
EOF

echo "Weekly report generated: $REPORT_FILE"
echo ""

# 8. Cleanup recommendations
echo "--- Cleanup Recommendations ---"
RECOMMENDATIONS=0

if [ "$ACTIVE_WORKTREES" -gt 3 ]; then
    echo "⚠️  Warning: $ACTIVE_WORKTREES active worktrees (max recommended: 3)"
    echo "   Consider: git worktree list"
    RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [ "$TODO_COUNT" -gt 50 ]; then
    echo "⚠️  Warning: $TODO_COUNT TODO/FIXME markers"
    echo "   Consider addressing technical debt"
    RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [ "$TEST_RATIO" -lt 30 ] && [ "$SWIFT_FILE_COUNT" -gt 0 ]; then
    echo "⚠️  Warning: Low test ratio: $TEST_RATIO% (target: 30%+)"
    echo "   Consider adding more tests"
    RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [ "$RECENT_COMMITS" -eq 0 ]; then
    echo "⚠️  Warning: No commits in the last 7 days"
    echo "   Consider increasing development activity"
    RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [ "$COMPLETION_PERCENTAGE" -lt 70 ]; then
    echo "⚠️  Warning: Roadmap completion below 70%: $COMPLETION_PERCENTAGE%"
    echo "   Consider focusing on roadmap items"
    RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [ "$RECOMMENDATIONS" -eq 0 ]; then
    echo "✅ All metrics within healthy ranges"
fi

echo ""
echo "=== Weekly Scan Complete ==="
echo ""
echo "Summary:"
echo "- Report: $REPORT_FILE"
echo "- Roadmap: $COMPLETION_PERCENTAGE% complete"
echo "- Activity: $RECENT_COMMITS commits this week"
echo "- Worktrees: $ACTIVE_WORKTREES active"
echo "- Recommendations: $RECOMMENDATIONS"
echo ""
echo "Review the report and continue with your commit."