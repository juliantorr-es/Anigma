#!/bin/bash
set -e

# Ledger-ready JSON output file
REPORT="governance_audit.json"

echo "Anigma Governance Gate Execution..."

# 1. Run the primary gate (aggregate tool)
# We use the internal anigma_ci_all tool if available
if command -v anigma_ci_all &> /dev/null; then
    echo "Executing anigma_ci_all..."
    anigma_ci_all > "$REPORT"
else
    echo "anigma_ci_all not found in PATH, running individual gates..."
    
    SWIFT6_RES=$(anigma_swift6_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")
    TYPE_AUTH_RES=$(anigma_type_authority_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")
    DEPS_RES=$(anigma_deps_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")

    cat <<EOF > "$REPORT"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gates": {
    "swift6": $SWIFT6_RES,
    "type_authority": $TYPE_AUTH_RES,
    "dependencies": $DEPS_RES
  },
  "governance_status": "audited"
}
EOF
fi

echo "Gate Summary:"
cat "$REPORT"
