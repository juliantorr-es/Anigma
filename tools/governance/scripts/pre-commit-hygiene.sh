#!/bin/bash
#
# pre-commit-hygiene.sh
# Git pre-commit hook for Anigma build hygiene
#

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "--- Running Build Hygiene Check ---"

# Run the validation script
"$REPO_ROOT/scripts/validate_build_hygiene.sh"

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "--- Build Hygiene Check Passed ---"
    exit 0
else
    echo "--- Build Hygiene Check FAILED ---"
    echo "Please fix the violations before committing."
    exit 1
fi
