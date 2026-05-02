#!/bin/bash
# cleanup_inspiration_repos.sh
# Purpose: Clean up processed inspiration repos after digestion pipeline
# Based on AGENTS_DIGESTION.md specifications

set -euo pipefail

echo "=== Inspiration Repos Cleanup ==="
echo "Purpose: Remove processed inspiration repos to prevent accumulation"
echo ""

INSPIRATION_DIR="/Users/user/Developer/Repos for Inspiration"
DIGESTION_LOG=".auto-claude/digestion/digestion_log.json"
BACKUP_DIR="$INSPIRATION_DIR/_processed_$(date +%Y%m%d)"

# Check if inspiration directory exists
if [ ! -d "$INSPIRATION_DIR" ]; then
    echo "❌ Inspiration directory not found: $INSPIRATION_DIR"
    exit 1
fi

# Check if digestion log exists
if [ ! -f "$DIGESTION_LOG" ]; then
    echo "❌ Digestion log not found: $DIGESTION_LOG"
    echo "Run digestion pipeline first: ./scripts/digestion_pipeline.sh"
    exit 1
fi

# Get list of processed repos from digestion log
echo "--- Processed Repos from Digestion Log ---"
PROCESSED_REPOS=$(jq -r '.digestion_runs[].repo_path' "$DIGESTION_LOG" 2>/dev/null || echo "")
PROCESSED_COUNT=$(echo "$PROCESSED_REPOS" | grep -c "^" || echo "0")

if [ "$PROCESSED_COUNT" -eq 0 ]; then
    echo "No processed repos found in digestion log"
    echo "Run digestion pipeline first: ./scripts/digestion_pipeline.sh"
    exit 1
fi

echo "Found $PROCESSED_COUNT processed repos in digestion log:"
echo "$PROCESSED_REPOS" | while read -r repo; do
    if [ -n "$repo" ]; then
        echo "  - $(basename "$repo")"
    fi
done

echo ""

# Create backup directory
echo "--- Backup Creation ---"
mkdir -p "$BACKUP_DIR"
echo "Backup directory created: $BACKUP_DIR"
echo ""

# Process each repo
echo "--- Processing Repos ---"
DELETED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for repo in $PROCESSED_REPOS; do
    if [ -z "$repo" ]; then
        continue
    fi
    
    REPO_NAME=$(basename "$repo")
    
    if [ ! -d "$repo" ]; then
        echo "  ⚠️  $REPO_NAME: Not found (may have been deleted already)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Create backup
    echo "  📦 Backing up: $REPO_NAME"
    if cp -r "$repo" "$BACKUP_DIR/" 2>/dev/null; then
        echo "    ✅ Backup created"
    else
        echo "    ⚠️  Backup failed (continuing anyway)"
    fi
    
    # Delete the repo
    echo "  🗑️  Deleting: $REPO_NAME"
    if rm -rf "$repo"; then
        echo "    ✅ Deleted"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        echo "    ❌ Delete failed"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
    
    echo ""
done

# Update digestion log with cleanup info
echo "--- Updating Digestion Log ---"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
jq --arg timestamp "$TIMESTAMP" \
   --arg deleted "$DELETED_COUNT" \
   --arg backup "$BACKUP_DIR" \
   '.last_cleanup = {
     "timestamp": $timestamp,
     "repos_deleted": $deleted,
     "backup_location": $backup
   }' "$DIGESTION_LOG" > "${DIGESTION_LOG}.tmp" && mv "${DIGESTION_LOG}.tmp" "$DIGESTION_LOG"

echo "Digestion log updated with cleanup information"
echo ""

# Check remaining repos
echo "--- Remaining Repos ---"
REMAINING_REPOS=$(find "$INSPIRATION_DIR" -maxdepth 1 -type d ! -name ".*" ! -name "$(basename "$BACKUP_DIR")" ! -path "$INSPIRATION_DIR" | wc -l || echo "0")
echo "Repos remaining in inspiration directory: $REMAINING_REPOS"

if [ "$REMAINING_REPOS" -gt 0 ]; then
    echo "Remaining repos:"
    find "$INSPIRATION_DIR" -maxdepth 1 -type d ! -name ".*" ! -name "$(basename "$BACKUP_DIR")" ! -path "$INSPIRATION_DIR" -exec basename {} \;
else
    echo "✅ All processed repos cleaned up"
fi

echo ""

# Summary
echo "=== Cleanup Summary ==="
echo ""
echo "Processed:"
echo "  ✅ Deleted: $DELETED_COUNT repos"
echo "  ⚠️  Skipped: $SKIPPED_COUNT repos (not found)"
echo "  ❌ Errors: $ERROR_COUNT repos"
echo ""
echo "Backup:"
echo "  📦 Location: $BACKUP_DIR"
echo "  📊 Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")"
echo ""
echo "Remaining:"
echo "  📁 Repos in $INSPIRATION_DIR: $REMAINING_REPOS"
echo ""
echo "Digestion log updated: $DIGESTION_LOG"
echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Next steps:"
echo "1. Verify backup contains all processed repos"
echo "2. Review remaining repos for future digestion"
echo "3. Add new inspiration repos to $INSPIRATION_DIR"
echo "4. Run digestion pipeline again when new repos are added"
echo ""
echo "To add cleanup to Shared memory:"
echo "  memory_store(mode: \"add\", content: \"Inspiration repos cleanup completed $TIMESTAMP - $DELETED_COUNT repos deleted, backup: $BACKUP_DIR - Updated: $TIMESTAMP\", type: \"project-config\", scope: \"project\")"