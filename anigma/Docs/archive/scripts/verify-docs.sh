#!/bin/bash
set -e

echo "Running docs:sync to check for outdated documentation..."
npm run docs:sync

if [[ -n $(git status --porcelain Docs/automation/) ]]; then
    echo "Error: Generated documentation is out of date. Please run 'npm run docs:sync' and commit the changes."
    exit 1
else
    echo "Documentation is up-to-date."
    exit 0
fi
