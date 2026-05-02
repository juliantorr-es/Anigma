#!/bin/bash
# Analyze which targets have the most files (indexing culprits)

echo "🔍 Analyzing Package Targets for Indexing Impact"
echo "================================================"
echo ""

# Function to count files in a directory
count_files() {
    local path=$1
    local swift_count=$(find "$path" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    local cpp_count=$(find "$path" \( -name "*.cpp" -o -name "*.c" -o -name "*.hpp" -o -name "*.h" \) 2>/dev/null | wc -l | tr -d ' ')
    echo "$swift_count $cpp_count"
}

echo "Top File-Heavy Targets:"
echo "----------------------"

# Check some known heavy targets
declare -a TARGETS=(
    "Packages/AnigmaCore"
    "Packages/HarmoniaModule"
    "Packages/DatabaseCore"
    "Packages/AnigmaDaemonCore"
    "Native/Shims"
    "Sources/AnigmaAppMac"
    "Packages/CClipper2"
    "Packages/PDFCapsule"
)

for target in "${TARGETS[@]}"; do
    if [ -d "$target" ]; then
        read swift cpp <<< $(count_files "$target")
        total=$((swift + cpp))
        if [ $total -gt 0 ]; then
            printf "%-40s: %3d Swift, %3d C/C++\n" "$target" $swift $cpp
        fi
    fi
done

echo ""
echo "Vendor Analysis:"
echo "----------------"
if [ -d "Vendor" ]; then
    vendor_files=$(find Vendor -type f 2>/dev/null | wc -l | tr -d ' ')
    vendor_size=$(du -sh Vendor 2>/dev/null | cut -f1)
    echo "Vendor directory: $vendor_files files, $vendor_size"
    echo "⚠️  These should NOT be in your Xcode project!"
fi

echo ""
echo "Build Artifact Analysis:"
echo "------------------------"
if [ -d ".build" ]; then
    build_files=$(find .build -type f 2>/dev/null | wc -l | tr -d ' ')
    build_size=$(du -sh .build 2>/dev/null | cut -f1)
    echo ".build directory: $build_files files, $build_size"
    if [ -d ".build/stats" ]; then
        stats_files=$(find .build/stats -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "  └─ .build/stats: $stats_files stat files"
        echo "     ⚠️  Set ANIGMA_DEBUG_STATS=0 to disable"
    fi
else
    echo ".build directory: Not present (good!)"
fi

echo ""
echo "DerivedData Analysis:"
echo "---------------------"
derived_data=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Anigma-*" 2>/dev/null)
if [ -n "$derived_data" ]; then
    for dd in $derived_data; do
        dd_size=$(du -sh "$dd" 2>/dev/null | cut -f1)
        echo "$(basename $dd): $dd_size"
    done
    echo ""
    echo "💡 Tip: Delete these with:"
    echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/Anigma-*"
else
    echo "No Anigma DerivedData found (good!)"
fi

echo ""
echo "Recommendation Summary:"
echo "----------------------"

# Total Swift files
total_swift=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./.swiftpm/*" 2>/dev/null | wc -l | tr -d ' ')
total_cpp=$(find . \( -name "*.cpp" -o -name "*.c" \) -not -path "./.build/*" -not -path "./Vendor/*" 2>/dev/null | wc -l | tr -d ' ')

echo "Total project files: $total_swift Swift, $total_cpp C/C++"
echo ""

if [ $total_swift -gt 5000 ]; then
    echo "🔴 CRITICAL: $total_swift Swift files is extremely high"
    echo "   → Consider splitting into multiple packages"
elif [ $total_swift -gt 2000 ]; then
    echo "🟡 WARNING: $total_swift Swift files is quite high"
    echo "   → Xcode will struggle with this"
elif [ $total_swift -gt 1000 ]; then
    echo "🟢 OK: $total_swift Swift files is manageable"
    echo "   → Should index reasonably well"
else
    echo "🟢 GOOD: $total_swift Swift files is fine"
fi

echo ""

# Check scheme count
if [ -d ".swiftpm" ]; then
    scheme_count=$(find .swiftpm/xcode -name "*.xcscheme" 2>/dev/null | wc -l | tr -d ' ')
    if [ $scheme_count -gt 0 ]; then
        echo "Schemes found: $scheme_count"
        if [ $scheme_count -gt 50 ]; then
            echo "🔴 CRITICAL: Too many schemes"
            echo "   → Hide all but 3-5 active ones in Xcode"
        elif [ $scheme_count -gt 20 ]; then
            echo "🟡 WARNING: Many schemes"
            echo "   → Hide unused ones for better performance"
        fi
    fi
fi

echo ""
echo "Run './optimize_xcode_indexing.sh' to apply fixes"
