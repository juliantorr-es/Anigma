#!/bin/bash

# OSLog Audit Script for Anigma Backend
# Usage: ./audit_oslog.sh [module_name]

set -e

echo "=== Anigma OSLog Audit Script ==="
echo "Generated: $(date)"
echo ""

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to count print statements in a file
count_prints() {
    local file="$1"
    local count=$(grep -c "print(" "$file" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to check if file uses OSLog
uses_oslog() {
    local file="$1"
    local oslog_count=$(grep -c "OSLog\|os.log\|Logger" "$file" 2>/dev/null || echo "0")
    if [ "$oslog_count" -gt "0" ]; then
        echo "✅"
    else
        echo "❌"
    fi
}

# Function to check for security issues
check_security() {
    local file="$1"
    local security_issues=$(grep -i "print.*token\|print.*password\|print.*credential\|print.*apiKey" "$file" 2>/dev/null | wc -l || echo "0")
    if [ "$security_issues" -gt "0" ]; then
        echo "${RED}⚠️ SECURITY RISK${NC}"
    else
        echo "✅ Safe"
    fi
}

if [ -z "$1" ]; then
    # Audit entire codebase
    echo "${BLUE}=== Full Codebase Audit ===${NC}"
    echo ""
    
    echo "${YELLOW}Top 10 Files with Most Print Statements:${NC}"
    echo "----------------------------------------"
    find Sources Packages -name "*.swift" -exec grep -l "print(" {} \; | while read -r file; do
        count=$(count_prints "$file")
        if [ "$count" -gt "0" ]; then
            echo "$count - $file"
        fi
    done | sort -rn | head -10
    
    echo ""
    echo "${YELLOW}Files with Security Risks:${NC}"
    echo "-----------------------"
    find Sources Packages -name "*.swift" -exec grep -l "print.*token\|print.*password\|print.*credential\|print.*apiKey" {} \; | while read -r file; do
        echo "⚠️  $file"
    done
    
    echo ""
    echo "${YELLOW}Summary Statistics:${NC}"
    echo "------------------"
    PRINT_FILES=$(find Sources Packages -name "*.swift" -exec grep -l "print(" {} \; | wc -l)
    TOTAL_PRINTS=$(find Sources Packages -name "*.swift" -exec grep -h "print(" {} \; | wc -l)
    OSLOG_FILES=$(find Sources Packages -name "*.swift" -exec grep -l "OSLog\|os.log\|Logger" {} \; | wc -l)
    
    echo "Files with print(): $PRINT_FILES"
    echo "Total print() calls: $TOTAL_PRINTS"
    echo "Files with OSLog: $OSLOG_FILES"
    echo "Swift files analyzed: $(find Sources Packages -name "*.swift" | wc -l)"
    
else
    # Audit specific module
    MODULE="$1"
    echo "${BLUE}=== Auditing Module: $MODULE ===${NC}"
    echo ""
    
    # Find all Swift files in module
    if [ -d "Sources/$MODULE" ]; then
        FILES=$(find "Sources/$MODULE" -name "*.swift")
    elif [ -d "Packages/$MODULE" ]; then
        FILES=$(find "Packages/$MODULE" -name "*.swift")
    else
        echo "Module $MODULE not found!"
        exit 1
    fi
    
    echo "${YELLOW}Print Statement Analysis:${NC}"
    echo "------------------------"
    TOTAL_PRINTS=0
    FILE_COUNT=0
    
    for file in $FILES; do
        count=$(count_prints "$file")
        if [ "$count" -gt "0" ]; then
            security=$(check_security "$file")
            oslog=$(uses_oslog "$file")
            echo "$count prints - $security - $oslog - $file"
            TOTAL_PRINTS=$((TOTAL_PRINTS + count))
            FILE_COUNT=$((FILE_COUNT + 1))
        fi
    done
    
    echo ""
    echo "${YELLOW}Module Summary:${NC}"
    echo "----------------"
    echo "Files with print(): $FILE_COUNT"
    echo "Total print() calls: $TOTAL_PRINTS"
    echo "Swift files in module: $(echo "$FILES" | wc -w)"
fi

echo ""
echo "${GREEN}=== Audit Complete ===${NC}"
echo ""

# Check if this is being run in CI
if [ -n "$CI" ]; then
    PRINT_FILES=$(find Sources Packages -name "*.swift" -exec grep -l "print(" {} \; | wc -l)
    if [ "$PRINT_FILES" -gt "0" ]; then
        echo "❌ Found $PRINT_FILES files with print() statements"
        echo "Please convert to OSLog for production readiness"
        exit 1
    else
        echo "✅ No print() statements found - OSLog compliant!"
        exit 0
    fi
fi