#!/bin/bash
# Setup script - run this first to make everything executable

echo "🔧 Setting up Xcode indexing optimization tools..."
echo ""

# Make all shell scripts executable
chmod +x optimize_xcode_indexing.sh 2>/dev/null || true
chmod +x analyze_indexing_impact.sh 2>/dev/null || true
chmod +x disable_debug_stats.sh 2>/dev/null || true
chmod +x show_quick_reference.sh 2>/dev/null || true

echo "✅ Scripts are now executable"
echo ""
echo "📖 What to do next:"
echo ""
echo "   Quick wins:  ./show_quick_reference.sh"
echo "   Analysis:    ./analyze_indexing_impact.sh"
echo "   Apply fixes: ./optimize_xcode_indexing.sh"
echo "   Read guide:  FIXES_APPLIED.md"
echo ""
echo "🚀 Ready to optimize!"
echo ""
echo "💡 TIP: The BIGGEST win is hiding unused schemes in Xcode"
echo "   (Product → Scheme → Manage Schemes → uncheck most)"
