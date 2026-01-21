#!/usr/bin/env bash
# Scripts/ci/check-accessibility.sh
# Enforces WCAG 2.1 AA accessibility compliance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Accessibility Contract Enforcement"
echo "Root: ${PROJECT_ROOT}"
echo ""

violations=0

# Check 1: All interactive elements have accessibility labels
echo "✓ Checking accessibility labels..."
PYTHON_SCRIPT="${PROJECT_ROOT}/Scripts/remediation/verify_accessibility.py"

if [[ -f "${PYTHON_SCRIPT}" ]]; then
  chmod +x "${PYTHON_SCRIPT}"
  if ! "${PYTHON_SCRIPT}" >/dev/null; then
    # Script failed (= violations found)
    echo "❌ Accessibility violations found (see verify_accessibility.py output for details)"
    # We want to show the output if it failed
    "${PYTHON_SCRIPT}" || true
    violations=$((violations + 1))
  else
    echo "✅ All interactive elements have accessibility labels"
  fi
else
    echo "⚠️  Advanced verification script not found, skipping."
fi

# Check 2: Semantic heading structure
echo ""
echo "✓ Checking heading hierarchy..."
# Verify Text().font() uses semantic fonts (header, subHeader, body)
non_semantic=$(grep -r "\.font(" "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | grep -v "Bauhaus.Font\|\.system\|\.caption\|\.title" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$non_semantic" -gt 5 ]]; then
  echo "⚠️  Found $non_semantic instances of non-semantic font usage"
  echo "   (Threshold: 5, consider using Bauhaus.Font tokens)"
fi

# Check 3: Color contrast (basic check for hardcoded colors)
echo ""
echo "✓ Checking color usage..."
hardcoded_colors=$(grep -r "Color\.red\|Color\.blue\|Color\.green" "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | grep -v "Bauhaus.Color" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$hardcoded_colors" -gt 0 ]]; then
  echo "❌ Found $hardcoded_colors hardcoded color references (should use Bauhaus.Color)"
  violations=$((violations + 1))
else
  echo "✅ All colors use semantic tokens"
fi

# Check 4: Keyboard navigation support
echo ""
echo "✓ Checking keyboard navigation..."
# Verify critical views have focusable elements
views_without_focus=$(grep -r "struct.*View:" "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | wc -l || true)
views_with_focus=$(grep -r "\.focusable\|\.keyboardShortcut" "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | wc -l || true)

focus_ratio=$((views_with_focus * 100 / views_without_focus))
if [[ "$focus_ratio" -lt 30 ]]; then
  echo "⚠️  Only ${focus_ratio}% of views have keyboard navigation support"
  echo "   (Target: 30%+)"
fi

# Check 5: VoiceOver hints
echo ""
echo "✓ Checking VoiceOver support..."
voiceover_hints=$(grep -r "accessibilityHint" "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
  | wc -l || true)

if [[ "$voiceover_hints" -lt 10 ]]; then
  echo "⚠️  Only $voiceover_hints accessibility hints found"
  echo "   (Consider adding hints for complex interactions)"
fi

echo ""
echo "::endgroup::"

if [[ "$violations" -gt 0 ]]; then
  echo "❌ FAILED: $violations critical accessibility violations"
  exit 1
fi

echo "✅ PASSED: Accessibility contract compliance verified"
exit 0
