#!/bin/bash
# Scripts/check_ghosts.sh
# Anigma Refinement Parity (Ghost Detector) - POSIX Compatible

# --- Configuration ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WHITELIST="CHarfBuzz CFreeType CPDFium Scripts Vendor Demo"
SEARCH_PATHS="Packages Sources"

echo -e "\n${BOLD}${BLUE}=== ANIGMA REFINEMENT PARITY (GHOST DETECTOR) ===${NC}"
echo -e "Objective: Every module must have a corresponding test suite.\n"

GHOST_COUNT=0
TOTAL_COUNT=0

# Print Header
printf "  %-30s | %-10s | %-20s\n" "MODULE" "STATUS" "TEST TARGET"
printf "  %s\n" "--------------------------------------------------------------------------------"

for path in $SEARCH_PATHS; do
    if [ -d "$path" ]; then
        for dir in "$path"/*/; do
            [ -d "$dir" ] || continue
            module=$(basename "$dir")
            
            # Skip logic (String matching for POSIX)
            skip=0
            for item in $WHITELIST; do
                if [ "$module" = "$item" ]; then skip=1; break; fi
            done
            if [ "$module" = "AnigmaAppMac" ] || [ "$module" = "AnigmaMCPExecutable" ] || [ "$module" = "HarmoniaCLI" ]; then skip=1; fi
            if [ $skip -eq 1 ]; then continue; fi

            TOTAL_COUNT=$((TOTAL_COUNT+1))
            
            if [ -d "Tests/${module}Tests" ] || [ -d "Tests/${module}sTests" ]; then
                printf "  %-30s | ${GREEN}%-10s${NC} | Tests/${module}Tests\n" "$module" "VALID"
            else
                printf "  %-30s | ${RED}%-10s${NC} | ${BOLD}MISSING${NC}\n" "$module" "GHOST"
                GHOST_COUNT=$((GHOST_COUNT+1))
            fi
        done
    fi
done

echo -e "\n${BOLD}${BLUE}=== SUMMARY ===${NC}"
if [ $TOTAL_COUNT -eq 0 ]; then
    echo "No modules found."
else
    PERCENTAGE=$(python3 -c "print(round((1 - $GHOST_COUNT/$TOTAL_COUNT) * 100, 1))")
    if [ $GHOST_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ 100% Refinement Parity. No ghosts detected.${NC}"
    else
        echo -e "${YELLOW}⚠️  Parity Score: $PERCENTAGE% ($GHOST_COUNT ghosts found).${NC}"
    fi
fi

exit 0
