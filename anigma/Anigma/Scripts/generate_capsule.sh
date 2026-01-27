#!/bin/bash

# generate_capsule.sh
# Creates a new Anigma capsule from the VizAggregationCapsule template.
# Usage: ./scripts/generate_capsule.sh MyVizAggregationCapsule [Tier]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CapsuleName> [Tier]"
    echo "Example: $0 MyAwesomeCapsule 2"
    exit 1
fi

CAPSULE_NAME=$1
TIER=${2:-2}
TEMPLATE_DIR="Templates/VizAggregationCapsule"
TARGET_DIR="Packages/${CAPSULE_NAME}"

if [ -d "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR already exists."
    exit 1
fi

echo "Generating capsule ${CAPSULE_NAME} (Tier ${TIER}) from template..."

# Copy template
cp -R "$TEMPLATE_DIR" "$TARGET_DIR"

# Rename directories
mv "$TARGET_DIR/Sources/VizAggregationCapsule" "$TARGET_DIR/Sources/${CAPSULE_NAME}"
mv "$TARGET_DIR/Sources/VizAggregationCapsuleNative" "$TARGET_DIR/Sources/${CAPSULE_NAME}Native"
mv "$TARGET_DIR/Tests/VizAggregationCapsuleTests" "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests"

# Rename files
mv "$TARGET_DIR/Sources/${CAPSULE_NAME}/VizAggregationCapsule.swift" "$TARGET_DIR/Sources/${CAPSULE_NAME}/${CAPSULE_NAME}.swift"
mv "$TARGET_DIR/Sources/${CAPSULE_NAME}/VizAggregationCapsuleInternal.swift" "$TARGET_DIR/Sources/${CAPSULE_NAME}/${CAPSULE_NAME}Internal.swift"
mv "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/VizAggregationCapsuleTests.swift" "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/${CAPSULE_NAME}Tests.swift"
mv "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/VizAggregationCapsuleGoldenTests.swift" "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/${CAPSULE_NAME}GoldenTests.swift"
mv "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/VizAggregationCapsuleContractTests.swift" "$TARGET_DIR/Tests/${CAPSULE_NAME}Tests/${CAPSULE_NAME}ContractTests.swift"

if [ -f "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/newcapsule.cpp" ]; then
    mv "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/newcapsule.cpp" "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/${CAPSULE_NAME,,}.cpp"
fi
if [ -f "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/include/newcapsule.hpp" ]; then
    mv "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/include/newcapsule.hpp" "$TARGET_DIR/Sources/${CAPSULE_NAME}Native/include/${CAPSULE_NAME,,}.hpp"
fi

# Perform string replacement
# Use different sed options for macOS and Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    find "$TARGET_DIR" -type f -not -path '*/.*' -exec sed -i '' "s/VizAggregationCapsule/${CAPSULE_NAME}/g" {} +
    find "$TARGET_DIR" -type f -not -path '*/.*' -exec sed -i '' "s/newcapsule/${CAPSULE_NAME,,}/g" {} +
    sed -i '' "s/tier = 2/tier = ${TIER}/" "$TARGET_DIR/MANIFEST.toml"
else
    find "$TARGET_DIR" -type f -not -path '*/.*' -exec sed -i "s/VizAggregationCapsule/${CAPSULE_NAME}/g" {} +
    find "$TARGET_DIR" -type f -not -path '*/.*' -exec sed -i "s/newcapsule/${CAPSULE_NAME,,}/g" {} +
    sed -i "s/tier = 2/tier = ${TIER}/" "$TARGET_DIR/MANIFEST.toml"
fi

echo "Capsule ${CAPSULE_NAME} generated successfully at ${TARGET_DIR}"
echo "Next steps:"
echo "1. CD into ${TARGET_DIR}"
echo "2. Run 'swift build' to verify"
echo "3. Run 'swift test' to check template tests"
echo "4. Start implementing your logic in Sources/${CAPSULE_NAME}/${CAPSULE_NAME}Internal.swift"
