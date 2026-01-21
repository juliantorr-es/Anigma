#!/usr/bin/env bash
# Scripts/ci/check-design-tokens.sh
# Enforces Bauhaus Design System token usage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Design Token Contract Enforcement"
echo "Root: ${PROJECT_ROOT}"
echo ""

violations=0

# Check 1: No hardcoded colors
echo "✓ Checking color token usage..."
hardcoded_colors=$(grep -rn "Color(\|\.red\|\.blue\|\.green\|\.orange\|\.purple\|\.yellow" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
  | grep -v "Bauhaus.Color\|DesignTokens\|// OK:" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$hardcoded_colors" -gt 0 ]]; then
  echo "❌ Found $hardcoded_colors hardcoded color references"
  echo "   All colors must use Bauhaus.Color tokens"
  violations=$((violations + 1))
else
  echo "✅ All colors use semantic tokens"
fi

# Check 2: No hardcoded fonts
echo ""
echo "✓ Checking font token usage..."
hardcoded_fonts=$(grep -rn "\.font(.system\|Font.system" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
  | grep -v "Bauhaus.Font\|// OK:" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$hardcoded_fonts" -gt 0 ]]; then
  echo "❌ Found $hardcoded_fonts hardcoded font references"
  echo "   All fonts must use Bauhaus.Font tokens"
  violations=$((violations + 1))
else
  echo "✅ All fonts use semantic tokens"
fi

# Check 3: No hardcoded spacing
echo ""
echo "✓ Checking spacing token usage..."
hardcoded_spacing=$(grep -rn "\.padding([0-9]\|\.frame.*width: [0-9]\|\.frame.*height: [0-9]" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
  | grep -v "Bauhaus.Grid\|// OK:" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$hardcoded_spacing" -gt 10 ]]; then
  echo "⚠️  Found $hardcoded_spacing hardcoded spacing values"
  echo "   (Threshold: 10, consider using Bauhaus.Grid tokens)"
fi

# Check 4: Button style usage
echo ""
echo "✓ Checking button style usage..."
unstyle_buttons=$(grep -rn "Button(" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | grep -v "ButtonStyle\|primaryButtonStyle\|secondaryButtonStyle\|destructiveButtonStyle" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$unstyle_buttons" -gt 5 ]]; then
  echo "⚠️  Found $unstyle_buttons buttons without standardized styles"
  echo "   (Threshold: 5, use .primaryButtonStyle() etc.)"
fi

# Check 5: DesignSystem.swift is the source of truth
echo ""
echo "✓ Checking DesignSystem.swift integrity..."
if [[ ! -f "${PROJECT_ROOT}/Sources/AnigmaAppMac/DesignSystem.swift" ]]; then
  echo "❌ DesignSystem.swift not found"
  violations=$((violations + 1))
else
  # Verify it defines Bauhaus namespace
  if ! grep -q "enum Bauhaus" "${PROJECT_ROOT}/Sources/AnigmaAppMac/DesignSystem.swift"; then
    echo "❌ DesignSystem.swift missing Bauhaus namespace"
    violations=$((violations + 1))
  else
    echo "✅ DesignSystem.swift is valid"
  fi
fi

echo ""
echo "::endgroup::"

if [[ "$violations" -gt 0 ]]; then
  echo "❌ FAILED: $violations critical design token violations"
  exit 1
fi

echo "✅ PASSED: Design token contract compliance verified"
exit 0
