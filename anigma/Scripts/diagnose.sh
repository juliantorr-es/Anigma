#!/usr/bin/env bash
# Scripts/diagnose.sh
# Anigma Master Diagnostic & Health Score Tool

set -euo pipefail

# --- Configuration ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}================================================================================${NC}"
echo -e "${BOLD}${BLUE} ANIGMA MASTER DIAGNOSTIC ENGINE${NC}"
echo -e "${BOLD}${BLUE}================================================================================${NC}"

HEALTH_SCORE=100
VIOLATIONS=0

run_check() {
    local name="$1"
    local cmd="$2"
    local penalty="$3"
    
    echo -e "\n${BOLD}${CYAN}▶ Running: $name...${NC}"
    if eval "$cmd"; then
        echo -e "${GREEN}✓ $name passed.${NC}"
    else
        echo -e "${RED}✗ $name failed or found issues.${NC}"
        HEALTH_SCORE=$((HEALTH_SCORE - penalty))
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

# 1. Architecture Check
run_check "Tier Boundary Validation" "python3 Scripts/validate_tiers.py" 20

# 2. Concurrency Check
run_check "Swift 6 Concurrency Build" "./Scripts/ci/check-concurrency.sh" 25

# 3. Pattern Analysis
run_check "Concurrency Pattern Analysis" "python3 Scripts/ci/analyze_concurrency_patterns.py" 15

# 4. Refinement Parity
run_check "Ghost Detector" "./Scripts/check_ghosts.sh" 10

# 5. Design Tokens
run_check "Design Token Compliance" "./Scripts/ci/check-design-tokens.sh" 15

# 6. Type Authority
run_check "Type Authority Enforcement" "./Scripts/ci/check-type-authority.sh" 15

# 7. Runtime Orphan Detection
run_check "Runtime Orphan Detection" "python3 Scripts/ci/detect_runtime_orphans.py" 15

# 8. Maturity Matrix (Unified View)
echo -e "\n${BOLD}${CYAN}▶ Generating Module Maturity Matrix...${NC}"
python3 Scripts/generate_maturity_matrix.py

echo -e "\n${BOLD}${BLUE}================================================================================${NC}"
echo -e "${BOLD}${BLUE} FINAL HEALTH REPORT${NC}"
echo -e "${BOLD}${BLUE}================================================================================${NC}"

# Color coding for score
if [ $HEALTH_SCORE -ge 90 ]; then SCORE_COLOR=$GREEN
elif [ $HEALTH_SCORE -ge 70 ]; then SCORE_COLOR=$YELLOW
else SCORE_COLOR=$RED; fi

echo -e "  Health Score: ${BOLD}${SCORE_COLOR}${HEALTH_SCORE}/100${NC}"
echo -e "  Total Violations: ${BOLD}${VIOLATIONS}${NC}"

if [ $HEALTH_SCORE -eq 100 ]; then
    echo -e "\n${GREEN}✅ EXCELLENT: Codebase is in a high-integrity state.${NC}"
else
    echo -e "\n${YELLOW}⚠️  ATTENTION: Found $VIOLATIONS areas requiring remediation.${NC}"
    echo -e "Check the logs above for specific 'Remediation Blueprints'.\n"
fi

exit 0
