#!/bin/bash

#############################################################################
# validate-docs.sh
# 
# Validates Anigma documentation for:
# - Valid YAML frontmatter
# - Broken internal links
# - Missing related_docs references
# - Metadata consistency
#
# Usage:
#   ./scripts/validate-docs.sh                 # Check all docs
#   ./scripts/validate-docs.sh path/to/file.md # Check specific file
#
#############################################################################

DOCS_DIR="docs"
ERRORS=0
WARNINGS=0

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine which files to check
if [ -n "$1" ] && [ "$1" != "--help" ]; then
    if [ -f "$1" ]; then
        FILES="$1"
    else
        echo -e "${RED}Error: File not found: $1${NC}"
        exit 1
    fi
else
    FILES=$(find "$DOCS_DIR" -type f -name "*.md" | sort)
fi

echo -e "${BLUE}=== Anigma Documentation Validation ===${NC}\n"

#############################################################################
# Extract YAML frontmatter
#############################################################################
extract_frontmatter() {
    local file="$1"
    
    if ! head -1 "$file" | grep -q "^---$"; then
        return 1
    fi
    
    awk '
        /^---$/ { count++; next }
        count == 1 { print }
        count == 2 { exit }
    ' "$file"
}

#############################################################################
# Validate a single file
#############################################################################
validate_file() {
    local file="$1"
    local file_dir=$(dirname "$file")
    
    # Skip non-markdown files
    if [[ ! "$file" =~ \.md$ ]]; then
        return
    fi
    
    # Extract frontmatter
    local frontmatter=$(extract_frontmatter "$file")
    
    if [ -z "$frontmatter" ]; then
        echo -e "${RED}✗ $file${NC}: Missing YAML frontmatter"
        ((ERRORS++))
        return
    fi
    
    # Check required fields
    local required_fields=("title" "description" "audience" "complexity" "estimated_time" "last_updated" "status")
    
    for field in "${required_fields[@]}"; do
        if ! echo "$frontmatter" | grep -q "^${field}:"; then
            echo -e "${RED}✗ $file${NC}: Missing required field '${field}'"
            ((ERRORS++))
        fi
    done
    
    # Validate complexity
    local complexity=$(echo "$frontmatter" | grep "^complexity:" | head -1 | sed 's/complexity: //' | tr -d '"' | xargs)
    if ! [[ "$complexity" =~ ^(beginner|intermediate|advanced)$ ]]; then
        echo -e "${RED}✗ $file${NC}: Invalid complexity '${complexity}'"
        ((ERRORS++))
    fi
    
    # Validate status
    local status=$(echo "$frontmatter" | grep "^status:" | head -1 | sed 's/status: //' | tr -d '"' | xargs)
    if ! [[ "$status" =~ ^(stable|beta|experimental|stub)$ ]]; then
        echo -e "${YELLOW}⚠ $file${NC}: Invalid status '${status}'"
        ((WARNINGS++))
    fi
    
    # Validate related_docs if present
    if echo "$frontmatter" | grep -q "^related_docs:"; then
        # Extract related docs paths - handle both formats
        local related=$(echo "$frontmatter" | sed -n '/^related_docs:/,/^[a-z]/p' | grep '- "' | sed 's/.*- "//' | sed 's/".*//')
        
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            
            # Skip example paths
            if [[ "$path" =~ /path/to/ ]] || [[ "$path" =~ example ]]; then
                continue
            fi
            
            # Build full path
            local full_path="$file_dir/$path"
            
            # Check if file exists
            if [ ! -f "$full_path" ] 2>/dev/null; then
                echo -e "${RED}✗ $file${NC}: Related doc not found: $path"
                ((ERRORS++))
            fi
        done <<< "$related"
    fi
}

#############################################################################
# Main validation loop
#############################################################################

echo "Checking documentation files..."
echo ""

while IFS= read -r file; do
    [ -z "$file" ] && continue
    validate_file "$file"
done <<< "$FILES"

#############################################################################
# Print summary
#############################################################################

echo ""
echo -e "${BLUE}=== Validation Summary ===${NC}"

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Errors: $ERRORS${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All documentation validation checks passed!${NC}"
    exit 0
fi

if [ $ERRORS -gt 0 ]; then
    exit 1
fi

exit 0
