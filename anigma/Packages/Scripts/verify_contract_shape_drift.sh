#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== Contract Shape Drift Gate: Phase 1 - Moving EvidenceBundle, EvidenceSignature, VerificationStatus to ContractsCore ==="

# Check for canonical types outside ContractsCore
CANONICAL_TYPES=(
    "EvidenceBundle" "EvidenceHeadInfo" "EvidenceSignature" "VerificationStatus"
    "RedactionPlan" "RedactionTarget" "ContentRedaction" "RedactionPattern" "RedactedBundleManifest"
    "EmbeddingHeader" "EngineMetadata" "RetrievalEvidenceRecord" "RetrievalHit"
    "MLWorkerEngine" "MLWorkerTask" "MLWorkerRequest" "MLWorkerResponse"
    "MLArtifactRef" "MLTaskOptions" "EmbeddingRecipe"
)

VIOLATIONS=0

echo "Checking for canonical type violations..."

for type in "${CANONICAL_TYPES[@]}"; do
    hits="$(rg --type swift "^\s*(public\s+)?(struct|enum|class|protocol|typealias)\s+$type\s*:" Sources/ || true)"
    if [[ -n "$hits" ]]; then
        echo "VIOLATION: Canonical type '$type' defined outside ContractsCore"
        echo "$hits"
        echo "Fix: move '$type' into Sources/ContractsCore and replace other definitions with typealias shims."
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

echo ""
echo "Checking for CryptoKit contamination inside ContractsCore..."
if rg --type swift "^\s*import\s+CryptoKit\b" Sources/ContractsCore/ >/dev/null; then
    echo "VIOLATION: CryptoKit imported inside ContractsCore"
    rg --type swift "^\s*import\s+CryptoKit\b" Sources/ContractsCore || true
    echo "Fix: keep CryptoKit in implementation modules only; ContractsCore must stay transport-only."
    VIOLATIONS=$((VIOLATIONS + 1))
fi

echo ""
echo "Checking for volatile CryptoKit types in public signatures..."
if rg --type swift "^\s*public\s+.*\b(P256|SecureEnclave|SymmetricKey|SHA256|Curve25519|Ed25519)\b" Sources/ >/dev/null; then
    echo "VIOLATION: CryptoKit types appear in public API surface"
    rg --type swift "^\s*public\s+.*\b(P256|SecureEnclave|SymmetricKey|SHA256|Curve25519|Ed25519)\b" Sources || true
    echo "Fix: wrap CryptoKit behind internal adapters; public APIs must return ContractsCore transport types."
    VIOLATIONS=$((VIOLATIONS + 1))
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
    echo "Contract Shape Drift Gate FAILED."
    exit 1
else
    echo "Contract Shape Drift Gate PASSED."
fi

echo ""