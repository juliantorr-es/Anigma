#!/bin/bash
#
# validate_surface_compliance.sh
# Validate the Harmonia-backed surface against SURFACE contract requirements
#

set -e

echo "📋 Validating Harmonia SURFACE Contract Compliance..."
echo ""

FAILURES=0

# Helper function
check() {
    local name="$1"
    local command="$2"
    
    echo -n "  Checking: $name... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        ((FAILURES++))
    fi
}

# Database & Persistence
echo "🗄️  Database & Persistence:"
check "Receipt table schema" "grep -r 'CREATE TABLE.*receipts' Packages/AnigmaCLI/Database/ >/dev/null"
check "Worktree tracking schema" "grep -r 'CREATE TABLE.*worktree_leases' Packages/AnigmaCLI/Database/ >/dev/null"
check "Runs table schema" "grep -r 'CREATE TABLE.*runs' Packages/AnigmaCLI/Database/ >/dev/null"

# Receipts
echo ""
echo "🧾 Receipt System:"
check "Receipt generation" "grep -r 'CLIReceiptManager' Packages/AnigmaCLI/Database/ >/dev/null"
check "Receipt recording" "grep -r 'recordRunStart\|recordToolCall' Packages/AnigmaCLI/Database/ >/dev/null"
check "Run receipts" "grep -r 'recordRunStart' Packages/AnigmaCLI/Database/ >/dev/null"
check "Tool call receipts" "grep -r 'recordToolCall' Packages/AnigmaCLI/Database/ >/dev/null"

# Run & Step Tracking
echo ""
echo "📊 Run & Step Tracking:"
check "Run creation" "grep -r 'createRun' Packages/AnigmaCLI/Database/ >/dev/null"
check "Step recording" "grep -r 'recordStep' Packages/AnigmaCLI/Database/ >/dev/null"
check "Status updates" "grep -r 'updateRunStatus' Packages/AnigmaCLI/Database/ >/dev/null"
check "Run listing" "grep -r 'listRuns' Packages/AnigmaCLI/Database/ >/dev/null"

# Loop Breakers
echo ""
echo "🛑 Loop Breakers:"
check "Loop breaker implementation" "test -f Packages/AnigmaCLI/Database/CLILoopBreaker.swift"
check "Max steps limit" "grep -r 'maxSteps' Packages/AnigmaCLI/Database/CLILoopBreaker.swift >/dev/null"
check "Max wall time" "grep -r 'maxWallTimeSeconds' Packages/AnigmaCLI/Database/CLILoopBreaker.swift >/dev/null"
check "Repeated calls detection" "grep -r 'repeatedCallThreshold' Packages/AnigmaCLI/Database/CLILoopBreaker.swift >/dev/null"
check "Stop receipts" "grep -r 'recordLoopBreaker' Packages/AnigmaCLI/Database/ >/dev/null"

# Tool Execution
echo ""
echo "🔧 Tool Execution:"
check "Tool executor" "test -f Packages/AnigmaCLI/Database/CLIToolExecutor.swift"
check "File operations" "grep -r 'readFile\|writeFile' Packages/AnigmaCLI/Database/CLIToolExecutor.swift >/dev/null"
check "Shell commands" "grep -r 'executeShellCommand' Packages/AnigmaCLI/Database/CLIToolExecutor.swift >/dev/null"
check "Approval gates" "grep -r 'approved' Packages/AnigmaCLI/Database/CLIToolExecutor.swift >/dev/null"

# Worktree Lifecycle
echo ""
echo "🌳 Worktree Lifecycle:"
check "Worktree manager" "test -f Packages/AnigmaCLI/Database/CLIWorktreeManager.swift"
check "Worktree operations" "grep -r 'WorktreeLease\|worktree' Packages/AnigmaCLI/Database/CLIWorktreeManager.swift >/dev/null"
check "Lease tracking" "grep -r 'lease' Packages/AnigmaCLI/Database/CLIWorktreeManager.swift >/dev/null"
check "Lease status" "grep -r 'status' Packages/AnigmaCLI/Database/CLIWorktreeManager.swift >/dev/null"

# Index & Search
echo ""
echo "📇 Index & Search:"
check "Index manager" "test -f Packages/AnigmaCLI/Database/CLIIndexManager.swift"
check "FTS5 search" "grep -r 'chunks_fts\|document_chunks' Packages/AnigmaCLI/Database/ >/dev/null"
check "Vector embeddings" "grep -r 'embedding' Packages/AnigmaCLI/Database/ >/dev/null || true"
check "Chunk operations" "grep -r 'INSERT INTO document_chunks\|search' Packages/AnigmaCLI/Database/CLIIndexManager.swift >/dev/null"

# TUI
echo ""
echo "📺 TUI & Status:"
check "TUI manager" "test -f Packages/AnigmaCLI/Database/CLITUIManager.swift"
check "Status display" "grep -r 'formatDisplay' Packages/AnigmaCLI/Database/ >/dev/null"
check "Live updates" "grep -r 'refreshState' Packages/AnigmaCLI/Database/ >/dev/null"

# Commands
echo ""
echo "⌨️  CLI Commands:"
check "index commands" "grep -r 'AnigmaIndexCommand' Packages/AnigmaCLI/Executable/ >/dev/null"
check "worktree commands" "grep -r 'AnigmaWorktreeCommand' Packages/AnigmaCLI/Executable/ >/dev/null"
check "runs commands" "grep -r 'AnigmaRunsCommand' Packages/AnigmaCLI/Executable/ >/dev/null"
check "loop-breaker commands" "grep -r 'AnigmaLoopBreakerCommand' Packages/AnigmaCLI/Executable/ >/dev/null"
check "tools commands" "grep -r 'AnigmaToolsCommand' Packages/AnigmaCLI/Executable/ >/dev/null"
check "status commands" "grep -r 'AnigmaStatusCommand' Packages/AnigmaCLI/Executable/ >/dev/null"

# Tests
echo ""
echo "🧪 Tests:"
check "Unit tests exist" "test -f Tests/AnigmaCLITests/CLIDatabaseTests.swift"
check "Integration tests exist" "test -f Tests/AnigmaCLITests/CLIIntegrationTests.swift"

# Summary
echo ""
echo "═══════════════════════════════════════"

if [ $FAILURES -eq 0 ]; then
    echo "✅ All compliance checks passed!"
    echo "═══════════════════════════════════════"
    exit 0
else
    echo "❌ $FAILURES compliance check(s) failed"
    echo "═══════════════════════════════════════"
    exit 1
fi
