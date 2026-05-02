#!/bin/bash
# test_workflow.sh
# Purpose: Test the complete agent workflow system

set -euo pipefail

echo "=== Testing Agent Workflow System ==="
echo ""

# Test 1: Check all scripts exist
echo "Test 1: Script Existence"
SCRIPTS=(
    "scripts/roadmap_plan_start.sh"
    "scripts/roadmap_plan_end.sh"
    "scripts/roadmap_weekly_scan.sh"
    "scripts/digestion_pipeline.sh"
    ".git/hooks/pre-commit"
)

ALL_EXIST=true
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "  ✅ $script"
    else
        echo "  ❌ $script (missing)"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = true ]; then
    echo "  ✅ All scripts exist"
else
    echo "  ❌ Some scripts missing"
fi

echo ""

# Test 2: Check script executability
echo "Test 2: Script Executability"
EXECUTABLE_SCRIPTS=(
    "scripts/roadmap_plan_start.sh"
    "scripts/roadmap_plan_end.sh"
    "scripts/roadmap_weekly_scan.sh"
    "scripts/digestion_pipeline.sh"
    ".git/hooks/pre-commit"
)

ALL_EXECUTABLE=true
for script in "${EXECUTABLE_SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        echo "  ✅ $script (executable)"
    else
        echo "  ❌ $script (not executable)"
        ALL_EXECUTABLE=false
    fi
done

if [ "$ALL_EXECUTABLE" = true ]; then
    echo "  ✅ All scripts executable"
else
    echo "  ❌ Some scripts not executable"
fi

echo ""

# Test 3: Check required tools
echo "Test 3: Required Tools"
REQUIRED_TOOLS=("git" "jq" "bash")

ALL_TOOLS=true
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo "  ✅ $tool"
    else
        echo "  ❌ $tool (not found)"
        ALL_TOOLS=false
    fi
done

if [ "$ALL_TOOLS" = true ]; then
    echo "  ✅ All required tools available"
else
    echo "  ❌ Some tools missing"
fi

echo ""

# Test 4: Check directory structure
echo "Test 4: Directory Structure"
REQUIRED_DIRS=(
    ".auto-claude"
    ".auto-claude/roadmap"
    ".auto-claude/digestion"
    ".auto-claude/plans"
    ".auto-claude/reports"
    "scripts"
)

ALL_DIRS=true
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir (missing)"
        ALL_DIRS=false
    fi
done

if [ "$ALL_DIRS" = true ]; then
    echo "  ✅ All directories exist"
else
    echo "  ❌ Some directories missing"
fi

echo ""

# Test 5: Check documentation
echo "Test 5: Documentation"
DOCS=(
    "AGENTS.md"
    "AGENTS_PLUGINS.md"
    "AGENTS_SUPERMEMORY.md"
    "AGENTS_GIT.md"
    "AGENTS_DIGESTION.md"
    "AGENTS_ROADMAP.md"
    "AGENTS_QUICKREF.md"
    "AGENTS_EXAMPLES.md"
)

ALL_DOCS=true
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        lines=$(wc -l < "$doc" 2>/dev/null || echo "0")
        echo "  ✅ $doc ($lines lines)"
    else
        echo "  ❌ $doc (missing)"
        ALL_DOCS=false
    fi
done

if [ "$ALL_DOCS" = true ]; then
    echo "  ✅ All documentation exists"
else
    echo "  ❌ Some documentation missing"
fi

echo ""

# Test 6: Dry run of scripts (no actual changes)
echo "Test 6: Script Dry Runs"
echo "  Testing roadmap_plan_start.sh (dry run)..."
if ./scripts/roadmap_plan_start.sh --help &>/dev/null; then
    echo "  ✅ roadmap_plan_start.sh dry run successful"
else
    echo "  ❌ roadmap_plan_start.sh dry run failed"
fi

echo "  Testing roadmap_weekly_scan.sh (dry run)..."
if ./scripts/roadmap_weekly_scan.sh --help &>/dev/null; then
    echo "  ✅ roadmap_weekly_scan.sh dry run successful"
else
    echo "  ❌ roadmap_weekly_scan.sh dry run failed"
fi

echo ""

# Test 7: Check git configuration
echo "Test 7: Git Configuration"
if git rev-parse --git-dir &>/dev/null; then
    echo "  ✅ Git repository"
    
    # Check for main branch
    if git branch --list main &>/dev/null; then
        echo "  ✅ Main branch exists"
    else
        echo "  ⚠️  Main branch not found"
    fi
    
    # Check worktrees
    WORKTREE_COUNT=$(git worktree list 2>/dev/null | grep -v "(bare)" | wc -l || echo "0")
    echo "  Active worktrees: $WORKTREE_COUNT"
else
    echo "  ❌ Not a git repository"
fi

echo ""

# Summary
echo "=== Test Summary ==="
echo ""
echo "Agent workflow system includes:"
echo "- 4 main scripts (roadmap planning, weekly scans, digestion)"
echo "- 8 documentation files (AGENTS_*.md)"
echo "- Git pre-commit hook for weekly scans"
echo "- Directory structure for auto-claude data"
echo ""
echo "To use the system:"
echo "1. Start a plan: ./scripts/roadmap_plan_start.sh \"Plan Name\""
echo "2. Work on implementation"
echo "3. End plan: ./scripts/roadmap_plan_end.sh \"Plan Name\" \"YYYY-MM-DD\""
echo "4. Weekly scans: Automatic on first commit of week"
echo "5. Digestion: ./scripts/digestion_pipeline.sh"
echo ""
echo "Always check Shared memory first:"
echo "  memory_store(mode: \"search\", query: \"[topic]\", scope: \"project\")"
echo ""
echo "Test completed at: $(date)"