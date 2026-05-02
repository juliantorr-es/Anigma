#!/bin/bash
# Install git pre-push hook for governance tests
# Only runs tests when governance-related files are changed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_FILE="$REPO_ROOT/.git/hooks/pre-push"

cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Pre-push hook: Run governance tests if relevant files changed

# Get the remote branch being pushed to
remote="$1"
url="$2"

# Find upstream branch (or use origin/main as fallback)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)
if [ -z "$upstream" ]; then
    upstream="origin/main"
fi

# Check if governance-related files changed
changed_files=$(git diff --name-only "$upstream" HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD)

governance_pattern="Governance/|AuthorityImplementations\.swift|GovernanceHarness/|Package\.swift"

if echo "$changed_files" | grep -qE "$governance_pattern"; then
    echo "🔒 Governance-related files changed, running tests..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    if [ -f "$SCRIPT_DIR/scripts/test-governance.sh" ]; then
        bash "$SCRIPT_DIR/scripts/test-governance.sh"
        if [ $? -ne 0 ]; then
            echo "❌ Governance tests failed. Push aborted."
            echo "   Fix tests or use --no-verify to skip (not recommended)"
            exit 1
        fi
    else
        echo "⚠️  Warning: test-governance.sh not found, skipping tests"
    fi
else
    echo "ℹ️  No governance files changed, skipping governance tests"
fi

exit 0
EOF

chmod +x "$HOOK_FILE"
echo "✅ Git pre-push hook installed at $HOOK_FILE"
echo ""
echo "The hook will run governance tests automatically when you push changes to:"
echo "  - anigma/Packages/AnigmaCore/Sources/AnigmaCore/Governance/"
echo "  - anigma/Packages/AnigmaCore/Sources/AnigmaCore/Runtime/AuthorityImplementations.swift"
echo "  - Tests/GovernanceHarness/"
echo "  - Package.swift files"
echo ""
echo "To bypass the hook (not recommended): git push --no-verify"
