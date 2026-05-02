#!/bin/bash
# Scripts/generate_docs.sh
# Generate DocC documentation for key modules

OUTPUT_PATH="./docs-out"
mkdir -p "$OUTPUT_PATH"

MODULES=("AnigmaCore" "AnigmaPrimitives" "HarmoniaModule" "DatabaseCore" "StorageCore")

for MODULE in "${MODULES[@]}"; do
    echo "Generating documentation for $MODULE..."
    swift package --allow-writing-to-directory "$OUTPUT_PATH/$MODULE" \
        generate-documentation --target "$MODULE" \
        --output-path "$OUTPUT_PATH/$MODULE" \
        --transform-for-static-hosting --hosting-base-path "Anigma/$MODULE"
done

echo "Documentation generated in $OUTPUT_PATH"
