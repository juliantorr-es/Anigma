#!/usr/bin/env zsh

# Anigma Platform Portability Validator
# Enforces Docs/architecture/PLATFORM_BACKEND_PORTABILITY_DOCTRINE.md

set -e

TIER1_DIR="anigma/Packages/ContractsCore"
FORBIDDEN_SYMBOLS=("CVPixelBuffer" "IOSurface" "MTLTexture" "CMSampleBuffer" "AVAudioPCMBuffer" "AVAsset" "AVCaptureSession" "UTType" "MLModel" "VNRequest" "SecKey")
FORBIDDEN_IMPORTS=("AVFoundation" "VideoToolbox" "CoreVideo" "CoreMedia" "Metal" "UniformTypeIdentifiers" "CoreML" "Vision" "CryptoKit" "Security" "AudioToolbox" "CoreAudio")

echo "=== ANIGMA PLATFORM PORTABILITY CHECK ==="

# Mapping for constructive output
typeset -A APPROVED_SHAPES
APPROVED_SHAPES[CVPixelBuffer]="FrameReference"
APPROVED_SHAPES[IOSurface]="FrameReference"
APPROVED_SHAPES[MTLTexture]="FrameReference or ImageSurfaceReference"
APPROVED_SHAPES[CMSampleBuffer]="FrameReference or AudioBufferReference"
APPROVED_SHAPES[AVAudioPCMBuffer]="AudioBufferReference"
APPROVED_SHAPES[AVAsset]="ArtifactReference"
APPROVED_SHAPES[AVCaptureSession]="CaptureSessionReference"
APPROVED_SHAPES[UTType]="MediaTypeDescriptor or ContainerDescriptor"
APPROVED_SHAPES[MLModel]="ModelReference"
APPROVED_SHAPES[VNRequest]="VisionAnalysisRequestDescriptor"
APPROVED_SHAPES[SecKey]="SigningKeyReference"

VIOLATIONS=0

echo "Checking Tier 1 ($TIER1_DIR) for forbidden symbols..."

for symbol in "${FORBIDDEN_SYMBOLS[@]}"; do
    MATCHES=$(grep -rnE "\b$symbol\b" "$TIER1_DIR" --exclude="*.md" || true)
    if [[ -n "$MATCHES" ]]; then
        APPROVED="${APPROVED_SHAPES[$symbol]}"
        echo "🔴 VIOLATION: $symbol found in Tier 1."
        echo "   Approved Shape: Use $APPROVED in the contract."
        echo "   Allowed Layer: $symbol is allowed only inside macOS backend executors (e.g. VideoToolboxDecodeExecutor) or Tier 2 adapters."
        echo "   Matches:"
        echo "$MATCHES"
        echo ""
        VIOLATIONS=$((VIOLATIONS+1))
    fi
done

echo "Checking Tier 1 ($TIER1_DIR) for forbidden imports..."

for imp in "${FORBIDDEN_IMPORTS[@]}"; do
    MATCHES=$(grep -rnE "import $imp" "$TIER1_DIR" --exclude="*.md" || true)
    if [[ -n "$MATCHES" ]]; then
        echo "🔴 VIOLATION: 'import $imp' found in Tier 1."
        echo "   Doctrine: Tier 1 contracts must remain framework-agnostic."
        echo "   Refactor: Move $imp usage to a backend executor or a Tier 2 adapter module."
        echo "   Matches:"
        echo "$MATCHES"
        echo ""
        VIOLATIONS=$((VIOLATIONS+1))
    fi
done

if [[ $VIOLATIONS -gt 0 ]]; then
    echo "=== FAILED: $VIOLATIONS portability violations found ==="
    exit 1
else
    echo "✅ SUCCESS: No portability violations found in Tier 1."
    exit 0
fi
