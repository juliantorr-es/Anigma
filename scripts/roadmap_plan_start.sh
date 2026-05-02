#!/bin/bash
# roadmap_plan_start.sh
# Purpose: Establish baseline, gather context, set expectations before starting a new plan

set -euo pipefail

echo "=== Roadmap Scan: Plan Start ==="
echo ""

# Get plan name from argument or prompt
PLAN_NAME="${1:-}"
if [ -z "$PLAN_NAME" ]; then
    read -p "Enter plan name: " PLAN_NAME
fi

PLAN_TOPIC="${2:-$PLAN_NAME}"
echo "Plan: $PLAN_NAME"
echo "Topic: $PLAN_TOPIC"
echo ""

# 1. Check current roadmap completion from Shared memory
echo "--- Current Roadmap Status ---"
echo "Querying Shared memory for roadmap status..."
echo ""
echo "Based on Shared memory data (migrated from roadmap.json):"
echo "  - Total features: 22"
echo "  - Completed features: 0"
echo "  - Current completion: 0%"
echo ""
echo "To get detailed roadmap status from Shared memory:"
echo "  memory_store(mode: \"search\", query: \"roadmap\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"Phase 1\", scope: \"project\")"
echo ""

# Set variables based on Shared memory data
ROADMAP_ITEMS=22
COMPLETED_ITEMS=0
COMPLETION_PERCENTAGE=0

# 2. Review related features in Shared memory
echo "--- Related Shared memory Insights ---"
echo "Searching Shared memory for patterns related to: $PLAN_TOPIC"
echo ""
echo "Run these Shared memory queries:"
echo "  memory_store(mode: \"search\", query: \"$PLAN_TOPIC\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"implementation patterns\", scope: \"project\")"
echo "  memory_store(mode: \"search\", query: \"$PLAN_TOPIC feature\", scope: \"project\")"
echo ""

# 3. Check inspiration repos for relevant patterns
echo "--- Inspiration Repo Patterns ---"
INSPIRATION_DIR="/Users/user/Developer/Repos for Inspiration"
if [ -d "$INSPIRATION_DIR" ]; then
    echo "Checking inspiration repos for patterns related to: $PLAN_TOPIC"
    find "$INSPIRATION_DIR" -type d -maxdepth 2 -name "*$PLAN_TOPIC*" 2>/dev/null | head -5
    echo "(Use digestion pipeline to analyze these repos)"
else
    echo "Inspiration directory not found: $INSPIRATION_DIR"
fi

echo ""

# 4. Set baseline for this plan
echo "--- Plan Baseline ---"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "Setting baseline for plan: $PLAN_NAME"
echo "Current completion: $COMPLETION_PERCENTAGE%"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "To add to Shared memory, run:"
echo "  memory_store(mode: \"add\", content: \"Plan start: $PLAN_NAME - Current completion: $COMPLETION_PERCENTAGE% - Updated: $TIMESTAMP\", type: \"project-config\", scope: \"project\")"

echo ""

# 5. Define success criteria
echo "--- Success Criteria ---"
echo "Define success criteria for $PLAN_NAME:"
echo ""
echo "Example criteria:"
echo "- Implement [specific-feature]"
echo "- Achieve [test-coverage]% test coverage"
echo "- Update documentation"
echo "- Pass all CI gates"
echo ""
echo "Enter your success criteria (press Ctrl+D when done):"
echo ""

# Read multi-line input for success criteria
SUCCESS_CRITERIA=""
while IFS= read -r line; do
    SUCCESS_CRITERIA="${SUCCESS_CRITERIA}${line}\n"
done

echo ""
echo "=== Plan Start Complete ==="
echo ""
echo "Next steps:"
echo "1. Review roadmap and related patterns"
echo "2. Create worktree for this plan"
echo "3. Begin implementation"
echo "4. Run roadmap_plan_end.sh when complete"
echo ""

# Save plan details to file
PLAN_FILE=".auto-claude/plans/${PLAN_NAME}_$(date +%Y%m%d).txt"
mkdir -p "$(dirname "$PLAN_FILE")"
cat > "$PLAN_FILE" << EOF
# Plan: $PLAN_NAME
# Started: $TIMESTAMP
# Baseline completion: $COMPLETION_PERCENTAGE%

## Success Criteria:
$SUCCESS_CRITERIA

## Notes:
- Plan start scan completed
- Roadmap items: $ROADMAP_ITEMS
- Completed items: $COMPLETED_ITEMS
EOF

echo "Plan details saved to: $PLAN_FILE"