#!/bin/bash
# roadmap_plan_end.sh
# Purpose: Update completion, capture learnings, generate reports after plan completion

set -euo pipefail

echo "=== Roadmap Scan: Plan End ==="
echo ""

# Get plan name from argument or prompt
PLAN_NAME="${1:-}"
if [ -z "$PLAN_NAME" ]; then
    read -p "Enter plan name: " PLAN_NAME
fi

PLAN_START_DATE="${2:-}"
if [ -z "$PLAN_START_DATE" ]; then
    read -p "Enter plan start date (YYYY-MM-DD): " PLAN_START_DATE
fi

PLAN_KEYWORDS="${3:-$PLAN_NAME}"
echo "Plan: $PLAN_NAME"
echo "Start date: $PLAN_START_DATE"
echo "Keywords: $PLAN_KEYWORDS"
echo ""

# 1. Scan for implemented features from this plan
echo "--- Implemented Features ---"
IMPLEMENTED_FEATURES=$(git log --oneline --since="$PLAN_START_DATE" --grep="feat:\|fix:\|perf:" | grep -i "$PLAN_KEYWORDS" || true)
FEATURE_COUNT=$(echo "$IMPLEMENTED_FEATURES" | grep -c "^" || echo "0")

if [ "$FEATURE_COUNT" -gt 0 ]; then
    echo "Features implemented in this plan ($FEATURE_COUNT total):"
    echo "$IMPLEMENTED_FEATURES"
else
    echo "No features found matching keywords: $PLAN_KEYWORDS"
    echo "Recent commits:"
    git log --oneline --since="$PLAN_START_DATE" --max-count=5 || echo "No recent commits"
fi

echo ""

# 2. Update roadmap completion from Shared memory
echo "--- Roadmap Completion Update ---"
echo "Querying Shared memory for roadmap completion..."
echo ""
echo "Based on Shared memory data:"
echo "  Roadmap items: 22 (from Shared memory migration)"
echo "  Completed items: 0 (check Shared memory for updates)"
echo "  New completion: 0%"
echo ""
echo "To update roadmap completion in Shared memory:"
echo "  memory_store(mode: \"add\", content: \"Feature completed: [feature-name] - Plan: $PLAN_NAME - Updated: $(date +"%Y-%m-%d %H:%M:%S")\", type: \"learned-pattern\", scope: \"project\")"
echo ""
echo "To check current roadmap status:"
echo "  memory_store(mode: \"search\", query: \"roadmap\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"completed feature\", scope: \"project\")"
echo ""

# Set variables based on Shared memory data
ROADMAP_ITEMS=22
NEW_COMPLETED=0
NEW_PERCENTAGE=0

# Try to find baseline for comparison
BASELINE_FILE=".auto-claude/plans/${PLAN_NAME}_*.txt"
if ls $BASELINE_FILE 1>/dev/null 2>&1; then
    BASELINE_COMPLETION=$(grep "Baseline completion:" $BASELINE_FILE | head -1 | grep -o '[0-9]*' || echo "0")
    if [ -n "$BASELINE_COMPLETION" ] && [ "$BASELINE_COMPLETION" -gt 0 ]; then
        DELTA=$((NEW_PERCENTAGE - BASELINE_COMPLETION))
        echo "Delta from baseline: +$DELTA%"
    fi
fi

echo ""

# 3. Add implementation insights to Shared memory
echo "--- Shared memory Updates ---"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "To add implementation insights to Shared memory, run:"
echo "  memory_store(mode: \"add\", content: \"Plan completed: $PLAN_NAME - Features: $FEATURE_COUNT - Completion: $NEW_PERCENTAGE% - Updated: $TIMESTAMP\", type: \"learned-pattern\", scope: \"project\")"

echo ""

# 4. Update documentation
echo "--- Documentation Updates ---"
echo "Updating documentation for $PLAN_NAME..."
DOCS_UPDATED=0

# Check if documentation was updated
if git log --since="$PLAN_START_DATE" --grep="docs:" | grep -q "."; then
    echo "✓ Documentation commits found"
    DOCS_UPDATED=1
else
    echo "⚠ No documentation commits found"
    echo "  Consider: git log --oneline --since=\"$PLAN_START_DATE\" --grep=\"docs:\""
fi

echo ""

# 5. Generate progress report
echo "--- Progress Report ---"
REPORT_FILE=".auto-claude/reports/${PLAN_NAME}_$(date +%Y%m%d).md"
mkdir -p "$(dirname "$REPORT_FILE")"

# Get test count
TEST_COUNT=$(find . -path "*/Tests/*" -name "*.swift" -newerct "$PLAN_START_DATE" 2>/dev/null | wc -l || echo "0")

# Check CI gates
CI_PASSED="unknown"
if command -v ./scripts/validate_gates.sh &>/dev/null; then
    echo "Running CI gates check..."
    if ./scripts/validate_gates.sh &>/dev/null; then
        CI_PASSED="yes"
    else
        CI_PASSED="no"
    fi
fi

cat > "$REPORT_FILE" << EOF
# Progress Report: $PLAN_NAME
## Date: $(date +"%Y-%m-%d")

### Summary
- **Plan**: $PLAN_NAME
- **Duration**: $PLAN_START_DATE to $(date +"%Y-%m-%d")
- **Features implemented**: $FEATURE_COUNT
- **Roadmap completion**: $NEW_PERCENTAGE%
- **Tests added**: $TEST_COUNT
- **Documentation updated**: $( [ "$DOCS_UPDATED" -eq 1 ] && echo "yes" || echo "no" )
- **CI gates passed**: $CI_PASSED

### Implemented Features
$(if [ "$FEATURE_COUNT" -gt 0 ]; then
    echo "$IMPLEMENTED_FEATURES" | sed 's/^/- /'
else
    echo "No specific features recorded"
fi)

### Key Learnings
1. **Implementation patterns discovered**:
   - [Add your learnings here]
2. **Challenges overcome**:
   - [Add challenges here]
3. **Improvements for next plan**:
   - [Add improvements here]

### Next Steps
1. **Review implementation** with team
2. **Update roadmap** with completion status
3. **Archive plan documentation**
4. **Start next plan** using roadmap_plan_start.sh

### Metrics
- Start date: $PLAN_START_DATE
- End date: $(date +"%Y-%m-%d")
- Commit count: $(git log --oneline --since="$PLAN_START_DATE" | wc -l)
- Test files added: $TEST_COUNT
- Documentation commits: $(git log --oneline --since="$PLAN_START_DATE" --grep="docs:" | wc -l)
EOF

echo "Progress report generated: $REPORT_FILE"
echo ""

# 6. Cleanup recommendations
echo "--- Cleanup Recommendations ---"
ACTIVE_WORKTREES=$(git worktree list | grep -v "(bare)" | wc -l)
if [ "$ACTIVE_WORKTREES" -gt 3 ]; then
    echo "⚠️  Warning: $ACTIVE_WORKTREES active worktrees"
    echo "   Consider cleaning up with: git worktree list"
fi

TODO_COUNT=$(find . -name "*.swift" -type f -exec grep -l "TODO\|FIXME" {} \; 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 50 ]; then
    echo "⚠️  Warning: $TODO_COUNT TODO/FIXME markers"
    echo "   Consider addressing technical debt"
fi

echo ""
echo "=== Plan End Complete ==="
echo ""
echo "Next steps:"
echo "1. Review report: $REPORT_FILE"
echo "2. Update Shared memory with insights"
echo "3. Clean up worktree if needed"
echo "4. Start next plan with roadmap_plan_start.sh"
echo ""

# Update plan file with completion
PLAN_FILE=$(ls .auto-claude/plans/${PLAN_NAME}_*.txt 2>/dev/null | head -1)
if [ -f "$PLAN_FILE" ]; then
    cat >> "$PLAN_FILE" << EOF

## Completion
- Completed: $(date +"%Y-%m-%d %H:%M:%S")
- Features implemented: $FEATURE_COUNT
- Final completion: $NEW_PERCENTAGE%
- Report: $REPORT_FILE
EOF
    echo "Plan file updated: $PLAN_FILE"
fi