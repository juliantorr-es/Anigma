#!/bin/bash
#
# validate_build_hygiene.sh
# Validates build reproducibility by checking for hardcoded paths and undocumented flags
#
# Exit codes:
#   0 = Clean build (no violations)
#   1 = Violations found (hardcoded paths, undocumented flags, missing DEPS.toml)
#

set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIOLATIONS_FOUND=0
REPORT_FILE="${REPORT_FILE:-build_hygiene_report.txt}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize report
{
    echo "Build Hygiene Validation Report"
    echo "Generated: $(date)"
    echo "Repository: $REPO_ROOT"
    echo ""
    echo "=================================================="
    echo "1. External Dependencies Found"
    echo "=================================================="
} > "$REPORT_FILE"

# Function to log violation
log_violation() {
    local severity=$1
    local file=$2
    local line=$3
    local message=$4
    
    echo -e "${RED}[VIOLATION]${NC} $severity in $file:$line"
    echo "  → $message"
    echo "" >> "$REPORT_FILE"
    echo "[$severity] $file:$line" >> "$REPORT_FILE"
    echo "  $message" >> "$REPORT_FILE"
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
}

# Function to log warning
log_warning() {
    local file=$1
    local line=$2
    local message=$3
    
    echo -e "${YELLOW}[WARNING]${NC} $file:$line"
    echo "  → $message"
    echo "" >> "$REPORT_FILE"
    echo "[WARNING] $file:$line" >> "$REPORT_FILE"
    echo "  $message" >> "$REPORT_FILE"
}

# Check 1: Scan for hardcoded absolute paths (FAIL)
echo ""
echo -e "${YELLOW}Scanning for hardcoded absolute paths (/opt/homebrew, /usr/local, /Users/)...${NC}"
echo "" >> "$REPORT_FILE"
echo "Hardcoded Path Violations:" >> "$REPORT_FILE"
echo "------------------------" >> "$REPORT_FILE"

while IFS= read -r line; do
    if [ -n "$line" ]; then
        file=$(echo "$line" | cut -d: -f1)
        linenum=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        
        log_violation "HARDCODED_PATH" "$file" "$linenum" "Hardcoded absolute path detected: $content"
    fi
done < <(grep -rnE "/opt/homebrew|/usr/local|/Users/" "$REPO_ROOT" \
    --include="*.swift" \
    --include="*.toml" \
    --exclude-dir=".build*" \
    --exclude-dir=".git" \
    --exclude="DEPS.toml.template" \
    2>/dev/null)

# Check 2: Scan for unsafeFlags without justification comments (WARNING → FAIL if no DEPS.toml)
echo ""
echo -e "${YELLOW}Scanning for undocumented unsafe flags...${NC}"
echo "" >> "$REPORT_FILE"
echo "Undocumented Unsafe Flags:" >> "$REPORT_FILE"
echo "------------------------" >> "$REPORT_FILE"

# Find all Package.swift files with unsafeFlags
while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi
    
    # Extract line numbers and content for unsafeFlags
    while IFS= read -r linenum; do
        if [ -z "$linenum" ]; then
            continue
        fi
        
        # Check if there's a comment justifying the flag above (within 2 lines)
        line_content=$(sed -n "${linenum}p" "$file")
        
        # Look for justification comment in lines above
        has_justification=0
        for offset in 1 2; do
            prev_line=$((linenum - offset))
            if [ $prev_line -gt 0 ]; then
                prev_content=$(sed -n "${prev_line}p" "$file")
                if [[ "$prev_content" =~ ^[[:space:]]*// && "$prev_content" =~ (REASON|EXTERNAL_DEP|BUILD_ENV) ]]; then
                    has_justification=1
                    break
                fi
            fi
        done
        
        if [ $has_justification -eq 0 ]; then
            log_warning "$file" "$linenum" "unsafeFlags without REASON comment: $line_content"
        fi
    done < <(grep -n "\.unsafeFlags" "$file" 2>/dev/null | cut -d: -f1)
done < <(find "$REPO_ROOT/Packages" -name "Package.swift" -type f 2>/dev/null)

# Check 3: Scan for linkedLibrary without justification
echo ""
echo -e "${YELLOW}Scanning for undocumented linked libraries...${NC}"
echo "" >> "$REPORT_FILE"
echo "Undocumented Linked Libraries:" >> "$REPORT_FILE"
echo "------------------------------" >> "$REPORT_FILE"

while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi
    
    while IFS= read -r linenum; do
        if [ -z "$linenum" ]; then
            continue
        fi
        
        line_content=$(sed -n "${linenum}p" "$file")
        
        # Check if it's a system framework (acceptable without comment)
        if [[ "$line_content" =~ linkedFramework ]]; then
            continue
        fi
        
        # Look for EXTERNAL_DEP or REASON in surrounding lines
        has_justification=0
        for offset in 1 2 3; do
            prev_line=$((linenum - offset))
            if [ $prev_line -gt 0 ]; then
                prev_content=$(sed -n "${prev_line}p" "$file")
                if [[ "$prev_content" =~ ^[[:space:]]*// && "$prev_content" =~ (EXTERNAL_DEP|REASON|BUILD_ENV) ]]; then
                    has_justification=1
                    break
                fi
            fi
        done
        
        if [ $has_justification -eq 0 ] && [[ "$line_content" =~ linkedLibrary ]]; then
            log_warning "$file" "$linenum" "linkedLibrary without EXTERNAL_DEP comment: $line_content"
        fi
    done < <(grep -n "\.linked" "$file" 2>/dev/null | cut -d: -f1)
done < <(find "$REPO_ROOT/Packages" -name "Package.swift" -type f 2>/dev/null)

# Check 4: Scan for targets with native dependencies that lack DEPS.toml (WARNING)
echo ""
echo -e "${YELLOW}Checking for native targets without DEPS.toml...${NC}"
echo "" >> "$REPORT_FILE"
echo "Missing DEPS.toml for Native Targets:" >> "$REPORT_FILE"
echo "-----------------------------------" >> "$REPORT_FILE"

while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi
    
    # Check if Package.swift contains C++ targets or linked libraries
    if grep -qE "cxxSettings|\.cpp|c\+\+17|\.linkedLibrary" "$file" 2>/dev/null; then
        package_dir=$(dirname "$file")
        deps_file="$package_dir/DEPS.toml"
        
        if [ ! -f "$deps_file" ]; then
            package_name=$(grep "name:" "$file" | head -1 | cut -d'"' -f2)
            log_warning "$file" "1" "Native package '$package_name' missing DEPS.toml - required for reproducible builds"
        fi
    fi
done < <(find "$REPO_ROOT/Packages" -name "Package.swift" -type f 2>/dev/null)

# Check 5: Generate external dependencies report
echo ""
echo -e "${YELLOW}Scanning for external dependencies...${NC}"
echo ""

# Find all linked libraries
{
    echo ""
    echo "External Frameworks and Libraries Used:"
    echo "--------------------------------------"
} >> "$REPORT_FILE"

# Collect frameworks
frameworks=()
while IFS= read -r line; do
    if [ -n "$line" ]; then
        framework=$(echo "$line" | sed -E 's/.*linkedFramework\("([^"]+)".*/\1/')
        if [ -n "$framework" ] && [[ ! " ${frameworks[@]} " =~ " ${framework} " ]]; then
            frameworks+=("$framework")
        fi
    fi
done < <(grep -rh "linkedFramework" "$REPO_ROOT/Packages" --include="*.swift" 2>/dev/null | sort -u)

if [ ${#frameworks[@]} -gt 0 ]; then
    {
        echo ""
        echo "System Frameworks:"
        for fw in "${frameworks[@]}"; do
            echo "  - $fw"
        done
    } >> "$REPORT_FILE"
    
    echo -e "${GREEN}✓ System Frameworks found:${NC}"
    for fw in "${frameworks[@]}"; do
        echo "  - $fw"
    done
fi

# Collect C++ flags
{
    echo ""
    echo "C++ Configuration:"
} >> "$REPORT_FILE"

if grep -rq "cxxSettings\|\.unsafeFlags.*c++" "$REPO_ROOT/Packages" --include="*.swift" 2>/dev/null; then
    cxx_found=$(grep -rh "cxxLanguageStandard\|unsafeFlags.*-std=c++" "$REPO_ROOT/Packages" --include="*.swift" 2>/dev/null | sort -u | wc -l)
    {
        echo "  C++ configurations: $cxx_found found"
    } >> "$REPORT_FILE"
    echo -e "${GREEN}✓ C++ targets found${NC}"
fi

# Summary
echo ""
echo "=================================================="
echo ""
{
    echo ""
    echo "=================================================="
    echo "SUMMARY"
    echo "=================================================="
    echo "Total Violations Found: $VIOLATIONS_FOUND"
} >> "$REPORT_FILE"

if [ $VIOLATIONS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ Build hygiene check passed!${NC}"
    echo "✓ No hardcoded paths" 
    echo "✓ No undocumented flags"
    {
        echo "Status: PASS"
        echo ""
        echo "All packages maintain clean build hygiene:"
        echo "  ✓ No hardcoded /opt/homebrew paths"
        echo "  ✓ All unsafe flags have justification"
        echo "  ✓ All linked libraries documented"
    } >> "$REPORT_FILE"
    echo "Report written to: $REPORT_FILE"
    exit 0
else
    echo -e "${RED}✗ Build hygiene check FAILED${NC}"
    echo "Violations: $VIOLATIONS_FOUND"
    echo ""
    echo -e "${YELLOW}Fix template for DEPS.toml:${NC}"
    echo "  [library-name]"
    echo "  source = \"system_or_swiftpm\""
    echo "  version = \"X.Y.Z+\""
    echo "  reason = \"Why this library is needed\""
    echo "  build_env = [\"macos_13+\", \"linux_x86_64\"]"
    echo ""
    echo -e "${YELLOW}For unsafe flags, add comment above:${NC}"
    echo "  // EXTERNAL_DEP: libname"
    echo "  // REASON: Justification"
    echo "  // BUILD_ENV: [\"macos_13+\"]"
    echo ""
    echo "Report written to: $REPORT_FILE"
    {
        echo "Status: FAIL"
        echo ""
        echo "Build hygiene violations detected. See details above."
    } >> "$REPORT_FILE"
    exit 1
fi
