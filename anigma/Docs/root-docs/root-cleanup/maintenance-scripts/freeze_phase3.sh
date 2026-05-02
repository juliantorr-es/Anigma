#!/bin/bash
# Phase 3 Freeze and Lockdown
# Run ONLY after smoke test passes (8/8)

set -e

echo "=== Phase 3 Freeze and Lockdown ==="
echo ""

# Verify everything is green
echo "1. Running final verification..."
./verify_phase3_build.sh || {
    echo "ERROR: Verification failed. Do not freeze until green."
    exit 1
}

# Check that evidence file has been filled out
if grep -q "PENDING" PHASE3_COMPLETE_EVIDENCE.md; then
    echo "ERROR: PHASE3_COMPLETE_EVIDENCE.md still has PENDING fields."
    echo "Fill out all smoke test results before freezing."
    exit 1
fi

echo ""
echo "2. Creating annotated tag..."

# Get current commit hash
COMMIT=$(git rev-parse HEAD)

# Create annotated tag with full context
git tag -a phase3-complete -m "Phase 3 Complete: Governance Hardened + Minimal Mac App

Governance Harness: 61/61 passing
Mac App Build: <1s incremental
Smoke Test: 8/8 passing
Denial Banner: Structured violations visible
Database: PostgreSQL (db: anigma_v3)

Dependencies:
- HarmoniaV2Surface (LocalAppClient in-process)
- AnigmaCore (Governance + Runtime)
- GovernanceCore (Violation types)

Source Files: 10
- AnigmaAppPhase3.swift
- HarmoniaRootView.swift
- AppModel.swift
- ProjectBootstrapView.swift
- StatusPanelView.swift
- IndexPanelView.swift
- RecallPanelView.swift
- MemoPanelView.swift
- DenialBannerView.swift

Next: Phase 4 - Daemon reintegration as DaemonAppClient (HarmoniaAppClient impl)

Commit: $COMMIT
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

echo ""
echo "3. Committing evidence file..."
git add PHASE3_COMPLETE_EVIDENCE.md
git add .github/workflows/phase3-verification.yml
git commit -m "Phase 3 Evidence: Smoke test results and CI workflow"

echo ""
echo "=== ✅ Phase 3 Frozen ==="
echo ""
echo "Tag created: phase3-complete"
echo "Commit: $COMMIT"
echo ""
echo "Next steps:"
echo "1. Push to remote: git push origin main --tags"
echo "2. Verify CI runs green on GitHub"
echo "3. Create Phase 4 branch: git checkout -b phase4-daemon-client"
echo ""
echo "DO NOT edit Phase 3 target or governance without smoke test + CI verification."
