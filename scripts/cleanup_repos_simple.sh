#!/bin/bash
# cleanup_repos_simple.sh
# Purpose: Simple cleanup of processed inspiration repos

set -euo pipefail

echo "=== Simple Inspiration Repos Cleanup ==="
echo ""

INSPIRATION_DIR="/Users/user/Developer/Repos for Inspiration"
BACKUP_DIR="$INSPIRATION_DIR/_processed_$(date +%Y%m%d)"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Processing repos in: $INSPIRATION_DIR"
echo "Backup to: $BACKUP_DIR"
echo ""

# Get all repos
REPOS=$(find "$INSPIRATION_DIR" -maxdepth 1 -type d ! -name ".*" ! -name "_processed*" ! -path "$INSPIRATION_DIR")

COUNT=0
for repo in $REPOS; do
    if [ -d "$repo" ]; then
        REPO_NAME=$(basename "$repo")
        COUNT=$((COUNT + 1))
        
        echo "Processing $COUNT: $REPO_NAME"
        
        # Backup
        echo "  📦 Backing up..."
        cp -r "$repo" "$BACKUP_DIR/" 2>/dev/null || echo "    ⚠️  Backup warning"
        
        # Delete
        echo "  🗑️  Deleting..."
        rm -rf "$repo" && echo "    ✅ Deleted" || echo "    ❌ Delete failed"
        
        echo ""
    fi
done

echo "=== Cleanup Complete ==="
echo "Processed: $COUNT repos"
echo "Backup: $BACKUP_DIR"
echo "Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")"
echo ""
echo "To verify: ls -la \"$INSPIRATION_DIR\""