#!/bin/bash
# digestion_pipeline.sh
# Purpose: Analyze inspiration repos, extract patterns, save to Shared memory, clean up
# Based on AGENTS_DIGESTION.md specifications

set -euo pipefail

echo "=== Digestion Pipeline ==="
echo "Purpose: Extract patterns from inspiration repos for roadmap development"
echo ""

INSPIRATION_DIR="/Users/user/Developer/Repos for Inspiration"
DIGESTION_LOG=".auto-claude/digestion/digestion_log.json"
DIGESTION_OUTPUT=".auto-claude/digestion/patterns.json"

# Create directories if they don't exist
mkdir -p "$(dirname "$DIGESTION_LOG")"
mkdir -p "$(dirname "$DIGESTION_OUTPUT")"

# Initialize log file if it doesn't exist
if [ ! -f "$DIGESTION_LOG" ]; then
    cat > "$DIGESTION_LOG" << EOF
{
  "digestion_runs": [],
  "total_repos_processed": 0,
  "last_run": null
}
EOF
fi

# Function to analyze a single repo
analyze_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    echo "  Analyzing: $repo_name"
    
    # Check if repo has already been processed
    if jq -e --arg repo "$repo_path" '.digestion_runs[] | select(.repo_path == $repo)' "$DIGESTION_LOG" >/dev/null 2>&1; then
        echo "    ⚠️  Already processed, skipping"
        return 0
    fi
    
    # Extract basic information
    local patterns=()
    
    # 1. Check for README or documentation
    if [ -f "$repo_path/README.md" ]; then
        patterns+=("Has README.md documentation")
        # Extract first few lines for context
        local readme_preview=$(head -5 "$repo_path/README.md" | tr '\n' ' ' | sed 's/"/\\"/g')
        patterns+=("README preview: $readme_preview")
    fi
    
    # 2. Check for package.json (Node.js projects)
    if [ -f "$repo_path/package.json" ]; then
        patterns+=("Node.js project with package.json")
        local package_name=$(jq -r '.name // empty' "$repo_path/package.json" 2>/dev/null || echo "")
        if [ -n "$package_name" ]; then
            patterns+=("Package name: $package_name")
        fi
    fi
    
    # 3. Check for Swift Package Manager
    if [ -f "$repo_path/Package.swift" ]; then
        patterns+=("Swift project with Package.swift")
    fi
    
    # 4. Check for Python projects
    if [ -f "$repo_path/requirements.txt" ] || [ -f "$repo_path/pyproject.toml" ]; then
        patterns+=("Python project")
    fi
    
    # 5. Check for Docker
    if [ -f "$repo_path/Dockerfile" ]; then
        patterns+=("Docker configuration")
    fi
    
    # 6. Check for CI/CD
    if [ -d "$repo_path/.github" ] || [ -f "$repo_path/.gitlab-ci.yml" ] || [ -f "$repo_path/.travis.yml" ]; then
        patterns+=("CI/CD configuration")
    fi
    
    # 7. Check for test directories
    if [ -d "$repo_path/tests" ] || [ -d "$repo_path/__tests__" ] || [ -d "$repo_path/Test" ]; then
        patterns+=("Test suite present")
    fi
    
    # 8. Count files by type
    local swift_files=$(find "$repo_path" -name "*.swift" -type f 2>/dev/null | wc -l || echo "0")
    local js_files=$(find "$repo_path" -name "*.js" -type f 2>/dev/null | wc -l || echo "0")
    local ts_files=$(find "$repo_path" -name "*.ts" -type f 2>/dev/null | wc -l || echo "0")
    local py_files=$(find "$repo_path" -name "*.py" -type f 2>/dev/null | wc -l || echo "0")
    
    if [ "$swift_files" -gt 0 ]; then
        patterns+=("Swift files: $swift_files")
    fi
    if [ "$js_files" -gt 0 ]; then
        patterns+=("JavaScript files: $js_files")
    fi
    if [ "$ts_files" -gt 0 ]; then
        patterns+=("TypeScript files: $ts_files")
    fi
    if [ "$py_files" -gt 0 ]; then
        patterns+=("Python files: $py_files")
    fi
    
    # 9. Check for interesting patterns in code
    local has_async=$(find "$repo_path" -name "*.swift" -type f -exec grep -l "async\|await\|Task" {} \; 2>/dev/null | head -1 || echo "")
    if [ -n "$has_async" ]; then
        patterns+=("Uses async/await patterns")
    fi
    
    local has_tests=$(find "$repo_path" -name "*Test*.swift" -o -name "*Spec*.swift" -o -name "*test*.js" 2>/dev/null | head -1 || echo "")
    if [ -n "$has_tests" ]; then
        patterns+=("Contains test files")
    fi
    
    # 10. Check for architecture patterns
    local has_components=$(find "$repo_path" -type d -name "components" -o -name "Components" 2>/dev/null | head -1 || echo "")
    if [ -n "$has_components" ]; then
        patterns+=("Component-based architecture")
    fi
    
    local has_services=$(find "$repo_path" -type d -name "services" -o -name "Services" 2>/dev/null | head -1 || echo "")
    if [ -n "$has_services" ]; then
        patterns+=("Service layer architecture")
    fi
    
    # Save patterns to output
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local pattern_json=""
    
    if [ ${#patterns[@]} -gt 0 ]; then
        # Create JSON array of patterns
        pattern_json="["
        for pattern in "${patterns[@]}"; do
            pattern_json="${pattern_json}\"${pattern}\","
        done
        pattern_json="${pattern_json%,}]"
        
        # Add to digestion output
        if [ ! -f "$DIGESTION_OUTPUT" ]; then
            echo "{\"patterns\": []}" > "$DIGESTION_OUTPUT"
        fi
        
        # Add pattern to output
        jq --arg repo "$repo_path" \
           --arg name "$repo_name" \
           --argjson patterns "$pattern_json" \
           --arg timestamp "$timestamp" \
           '.patterns += [{
             "repo_path": $repo,
             "repo_name": $name,
             "patterns": $patterns,
             "analyzed_at": $timestamp
           }]' "$DIGESTION_OUTPUT" > "${DIGESTION_OUTPUT}.tmp" && mv "${DIGESTION_OUTPUT}.tmp" "$DIGESTION_OUTPUT"
        
        echo "    ✅ Extracted ${#patterns[@]} patterns"
    else
        echo "    ⚠️  No patterns extracted"
        pattern_json="[]"
    fi
    
    # Update log
    jq --arg repo "$repo_path" \
       --arg name "$repo_name" \
       --argjson patterns "$pattern_json" \
       --arg timestamp "$timestamp" \
       '.digestion_runs += [{
         "repo_path": $repo,
         "repo_name": $name,
         "patterns_extracted": ($patterns | length),
         "analyzed_at": $timestamp
       }] | .total_repos_processed = (.digestion_runs | length) | .last_run = $timestamp' \
       "$DIGESTION_LOG" > "${DIGESTION_LOG}.tmp" && mv "${DIGESTION_LOG}.tmp" "$DIGESTION_LOG"
    
    return 0
}

# Function to suggest Shared memory updates
suggest_memory_store_updates() {
    echo ""
    echo "--- Shared memory Update Suggestions ---"
    
    if [ -f "$DIGESTION_OUTPUT" ]; then
        local pattern_count=$(jq '.patterns | length' "$DIGESTION_OUTPUT" 2>/dev/null || echo "0")
        
        if [ "$pattern_count" -gt 0 ]; then
            echo "Found $pattern_count repos with patterns. To add to Shared memory:"
            echo ""
            
            # Get unique pattern types
            local unique_patterns=$(jq -r '.patterns[].patterns[]' "$DIGESTION_OUTPUT" 2>/dev/null | sort | uniq -c | sort -rn | head -10)
            
            echo "Common patterns found:"
            echo "$unique_patterns" | while read -r line; do
                if [ -n "$line" ]; then
                    echo "  $line"
                fi
            done
            
            echo ""
            echo "To add to Shared memory, run:"
            echo "  memory_store(mode: \"add\", content: \"Digestion pipeline completed: $pattern_count repos analyzed, patterns: $(echo "$unique_patterns" | head -3 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' | tr '\n' ', ')\", type: \"learned-pattern\", scope: \"project\")"
        else
            echo "No patterns found in digestion output"
        fi
    else
        echo "No digestion output found"
    fi
}

# Function to suggest roadmap updates
suggest_roadmap_updates() {
    echo ""
    echo "--- Roadmap Update Suggestions ---"
    
    if [ -f "$DIGESTION_OUTPUT" ]; then
        # Look for patterns that might inform roadmap
        local swift_projects=$(jq '[.patterns[] | select(.patterns[] | contains("Swift"))] | length' "$DIGESTION_OUTPUT" 2>/dev/null || echo "0")
        local async_patterns=$(jq '[.patterns[] | select(.patterns[] | contains("async"))] | length' "$DIGESTION_OUTPUT" 2>/dev/null || echo "0")
        local test_patterns=$(jq '[.patterns[] | select(.patterns[] | contains("test"))] | length' "$DIGESTION_OUTPUT" 2>/dev/null || echo "0")
        
        if [ "$swift_projects" -gt 0 ]; then
            echo "✅ Found $swift_projects Swift projects - relevant for Anigma development"
        fi
        
        if [ "$async_patterns" -gt 0 ]; then
            echo "✅ Found $async_patterns projects using async/await - consider for concurrency improvements"
        fi
        
        if [ "$test_patterns" -gt 0 ]; then
            echo "✅ Found $test_patterns projects with tests - review testing patterns"
        fi
        
        # Check for specific inspiration repos
        if [ -d "$INSPIRATION_DIR/opencode-worktree" ]; then
            echo "🎯 Found 'opencode-worktree' - high priority for analysis"
            echo "   This repo likely contains OpenCode patterns relevant to agent development"
        fi
    fi
}

# Function to clean up processed repos
cleanup_repos() {
    echo ""
    echo "--- Cleanup Phase ---"
    read -p "Delete processed inspiration repos? (y/n): " DELETE_REPOS
    
    if [[ "$DELETE_REPOS" == "y" || "$DELETE_REPOS" == "Y" ]]; then
        echo "Checking for repos to delete..."
        
        # Get list of processed repos from log
        local processed_repos=$(jq -r '.digestion_runs[].repo_path' "$DIGESTION_LOG" 2>/dev/null || echo "")
        
        for repo in $processed_repos; do
            if [ -d "$repo" ]; then
                echo "  Deleting: $(basename "$repo")"
                rm -rf "$repo"
            fi
        done
        
        echo "Cleanup complete"
    else
        echo "Skipping cleanup"
    fi
}

# Main execution
echo "Stage 1: Discovery"
echo "Looking for inspiration repos in: $INSPIRATION_DIR"

if [ ! -d "$INSPIRATION_DIR" ]; then
    echo "❌ Inspiration directory not found: $INSPIRATION_DIR"
    echo "Please create the directory or update the path in the script."
    exit 1
fi

# Find all repos (directories that look like git repos or project directories)
REPO_COUNT=0
PROCESSED_COUNT=0

echo "Found repos:"
for repo in "$INSPIRATION_DIR"/*/; do
    if [ -d "$repo" ]; then
        REPO_COUNT=$((REPO_COUNT + 1))
        echo "  $((REPO_COUNT)). $(basename "$repo")"
    fi
done

echo ""
echo "Total repos found: $REPO_COUNT"

echo ""
echo "Stage 2: Analysis"
read -p "Analyze all repos? (y/n): " ANALYZE_ALL

if [[ "$ANALYZE_ALL" == "y" || "$ANALYZE_ALL" == "Y" ]]; then
    for repo in "$INSPIRATION_DIR"/*/; do
        if [ -d "$repo" ]; then
            analyze_repo "$repo"
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
        fi
    done
else
    read -p "How many repos to analyze? (1-$REPO_COUNT): " ANALYZE_COUNT
    ANALYZE_COUNT=${ANALYZE_COUNT:-1}
    
    COUNTER=0
    for repo in "$INSPIRATION_DIR"/*/; do
        if [ -d "$repo" ] && [ "$COUNTER" -lt "$ANALYZE_COUNT" ]; then
            analyze_repo "$repo"
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
            COUNTER=$((COUNTER + 1))
        fi
    done
fi

echo ""
echo "Stage 3: Pattern Extraction"
echo "Processed $PROCESSED_COUNT repos"

# Update log with run summary
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
jq --arg timestamp "$TIMESTAMP" \
   --arg processed "$PROCESSED_COUNT" \
   '.last_run = $timestamp | .total_repos_processed = (.digestion_runs | length)' \
   "$DIGESTION_LOG" > "${DIGESTION_LOG}.tmp" && mv "${DIGESTION_LOG}.tmp" "$DIGESTION_LOG"

echo "Digestion log updated: $DIGESTION_LOG"
if [ -f "$DIGESTION_OUTPUT" ]; then
    OUTPUT_COUNT=$(jq '.patterns | length' "$DIGESTION_OUTPUT" 2>/dev/null || echo "0")
    echo "Patterns saved: $DIGESTION_OUTPUT ($OUTPUT_COUNT entries)"
fi

# Stage 4: Suggestions
suggest_memory_store_updates
suggest_roadmap_updates

# Stage 5: Cleanup (optional)
echo ""
read -p "Proceed to cleanup phase? (y/n): " PROCEED_CLEANUP
if [[ "$PROCEED_CLEANUP" == "y" || "$PROCEED_CLEANUP" == "Y" ]]; then
    cleanup_repos
fi

echo ""
echo "=== Digestion Pipeline Complete ==="
echo ""
echo "Summary:"
echo "- Processed repos: $PROCESSED_COUNT"
echo "- Digestion log: $DIGESTION_LOG"
echo "- Patterns output: $DIGESTION_OUTPUT"
echo ""
echo "Next steps:"
echo "1. Review extracted patterns"
echo "2. Update Shared memory with key insights"
echo "3. Update roadmap based on discovered patterns"
echo "4. Run digestion again for new inspiration repos"
echo ""
echo "To run digestion again later: ./scripts/digestion_pipeline.sh"