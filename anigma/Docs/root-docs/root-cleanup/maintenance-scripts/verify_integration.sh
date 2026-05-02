#!/bin/bash

echo "=== Verifying Capsule Integration ==="
echo ""

# Check core integration files
echo "1. Checking Core Integration Files..."
files=(
    "anigma/Packages/PDFExporterKit/Sources/PDFExporterKit/LayoutAnalyzerCapsule.swift"
    "anigma/Packages/PDFExporterKit/Sources/PDFExporterKit/Artifacts/LayoutAnalysisResult.swift"
    "anigma/Packages/BookExportCapsule/Sources/BookExportCapsule/BookExportCapsule.swift"
    "anigma/Packages/BookAssemblerCapsule/Sources/BookAssemblerCapsule/BookAssemblerCapsule.swift"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file NOT FOUND"
    fi
done

echo ""
echo "2. Checking Planned Capsule Package.swift Files..."

capsules=("MathOCRCapsule" "CitationExtractionCapsule" "ReferenceResolutionCapsule" "DiffCapsule")

for capsule in "${capsules[@]}"; do
    pkg_file="anigma/Packages/$capsule/Package.swift"
    if [ -f "$pkg_file" ]; then
        echo "  ✅ $pkg_file"
    else
        echo "  ❌ $pkg_file NOT FOUND"
    fi
done

echo ""
echo "3. Checking Native Directory Structure..."

for capsule in "${capsules[@]}"; do
    include_dir="anigma/Packages/$capsule/Native/include"
    src_dir="anigma/Packages/$capsule/Native/src"
    sources_dir="anigma/Packages/$capsule/Sources/$capsule"
    
    if [ -d "$include_dir" ]; then
        echo "  ✅ $include_dir"
    else
        echo "  ❌ $include_dir NOT FOUND"
    fi
    
    if [ -d "$src_dir" ]; then
        echo "  ✅ $src_dir"
    else
        echo "  ❌ $src_dir NOT FOUND"
    fi
    
    if [ -d "$sources_dir" ]; then
        echo "  ✅ $sources_dir"
    else
        echo "  ❌ $sources_dir NOT FOUND"
    fi
done

echo ""
echo "4. Checking Main Package.swift Integration..."

if grep -q "MathOCRCapsule" anigma/Package.swift; then
    echo "  ✅ MathOCRCapsule added to main Package.swift"
else
    echo "  ❌ MathOCRCapsule NOT in main Package.swift"
fi

if grep -q "CitationExtractionCapsule" anigma/Package.swift; then
    echo "  ✅ CitationExtractionCapsule added to main Package.swift"
else
    echo "  ❌ CitationExtractionCapsule NOT in main Package.swift"
fi

if grep -q "ReferenceResolutionCapsule" anigma/Package.swift; then
    echo "  ✅ ReferenceResolutionCapsule added to main Package.swift"
else
    echo "  ❌ ReferenceResolutionCapsule NOT in main Package.swift"
fi

if grep -q "DiffCapsule" anigma/Package.swift; then
    echo "  ✅ DiffCapsule added to main Package.swift"
else
    echo "  ❌ DiffCapsule NOT in main Package.swift"
fi

echo ""
echo "5. Checking Native Targets in Main Package.swift..."

native_targets=("MathOCRNative" "CitationExtractionNative" "ReferenceResolutionNative" "DiffNative")

for target in "${native_targets[@]}"; do
    if grep -q "name: \"$target\"" anigma/Package.swift; then
        echo "  ✅ $target native target configured"
    else
        echo "  ❌ $target native target NOT configured"
    fi
done

echo ""
echo "6. Checking Products in Main Package.swift..."

for capsule in "${capsules[@]}"; do
    if grep -q "name: \"$capsule\"" anigma/Package.swift; then
        echo "  ✅ $capsule product configured"
    else
        echo "  ❌ $capsule product NOT configured"
    fi
done

echo ""
echo "=== Verification Complete ==="
