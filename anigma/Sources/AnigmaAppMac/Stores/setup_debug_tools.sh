#!/bin/bash
# setup_debug_tools.sh
# One-time setup for build debugging tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Setting up Anigma build debugging tools..."
echo ""

# Make all scripts executable
chmod +x "$SCRIPT_DIR/debug_build.sh"
chmod +x "$SCRIPT_DIR/capture_build_errors.sh"
chmod +x "$SCRIPT_DIR/suggest_fixes.sh"
chmod +x "$SCRIPT_DIR/analyze_build_errors.py"
chmod +x "$SCRIPT_DIR/setup_debug_tools.sh"

echo "✅ Scripts are now executable"
echo ""

# Check Python availability
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python 3 found: $PYTHON_VERSION"
    echo "   Advanced analysis will be available"
else
    echo "⚠️  Python 3 not found"
    echo "   Basic tools will work, but install Python 3 for advanced analysis"
fi

echo ""

# Check Swift
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -1)
    echo "✅ Swift found: $SWIFT_VERSION"
else
    echo "❌ Swift not found!"
    echo "   Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SETUP COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Read the documentation:"
echo "   cat BUILD_DEBUG_TOOLS_README.md"
echo ""
echo "🚀 Run the debugger:"
echo "   bash debug_build.sh"
echo ""
echo "Available tools:"
echo "  • debug_build.sh             - Master script (recommended)"
echo "  • capture_build_errors.sh    - Capture errors only"
echo "  • analyze_build_errors.py    - Advanced analysis (Python)"
echo "  • suggest_fixes.sh           - Generate fix suggestions"
echo ""
