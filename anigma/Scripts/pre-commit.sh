#!/bin/bash
# Anigma Pre-Commit Hook: Governance & Integrity Enforcement
# This script ensures that structural parity is maintained and critical 
# governance invariants are not broken before a commit is allowed.

set -e

echo "🔍 Running Anigma Integrity Checks..."

# 1. Structural Parity Check (Ghost Detector)
if [ -f "Scripts/check_ghosts.sh" ]; then
    echo "👻 Checking for ghost modules..."
    # Run in fail-fast mode for pre-commit
    ./Scripts/check_ghosts.sh
else
    echo "⚠️ Scripts/check_ghosts.sh not found, skipping ghost check."
fi

# 2. Strict Concurrency & Build Check
echo "🛠 Verifying build & strict concurrency..."
./Scripts/ci/check-concurrency.sh

# 3. Concurrency Pattern Analysis
echo "🧬 Analyzing concurrency patterns..."
python3 Scripts/ci/analyze_concurrency_patterns.py

# 4. Governance Invariant Check
echo "🛡 Verifying governance invariants..."
swift test --filter GovernanceCoreTests > /dev/null

echo "✅ Integrity checks passed. Proceeding with commit."
exit 0
