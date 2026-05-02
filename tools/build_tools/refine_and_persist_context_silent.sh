#!/bin/bash

# Script: refine_and_persist_context_silent.sh
# Usage: ./refine_and_persist_context_silent.sh <query> <directory> <output_file>

if [ "$#" -ne 3 ]; then
    exit 1
fi

QUERY=$1
DIRECTORY=$2
OUTPUT_FILE=$3

# Check if the directory exists
if [ ! -d "${DIRECTORY}" ]; then
    exit 1
fi

# Define file extensions to include
FILE_EXTENSIONS="swift cpp mm metal"

# Define directories to ignore
IGNORE_DIRS="(.git|.svn|.venv|venv|.build|build|DerivedData|Pods|Carthage|node_modules|.idea|.vscode|.DS_Store)"

# Initialize temporary files
> /tmp/symbols.json
> /tmp/patterns.json

# Step 1: Extract symbol information using sourcekitten for Swift files
SWIFT_FILES=$(find ${DIRECTORY} -type f -name "*.swift" 2>/dev/null)
if [ -n "$SWIFT_FILES" ]; then
    while IFS= read -r file; do
        sourcekitten doc --file "${file}" --output-format json >> /tmp/symbols.json 2>/dev/null
    done <<< "$SWIFT_FILES"
fi

# Step 2: Perform pattern matching using ast-grep for Swift, C++, and Metal files
fd --type f --extension swift --extension cpp --extension mm --extension metal --exclude ${IGNORE_DIRS} --exec ast-grep -p "${QUERY}" --lang swift {} > /tmp/patterns.json 2>/dev/null

# Step 3: Combine the results for refined context
if [ -f /tmp/symbols.json ] && [ -f /tmp/patterns.json ]; then
    cat /tmp/symbols.json /tmp/patterns.json > /tmp/refined_context.json
else
    > /tmp/refined_context.json
fi

# Step 4: Save the refined context to the knowledge base
mkdir -p ~/.agent_knowledge/tools 2>/dev/null
cp /tmp/refined_context.json ~/.agent_knowledge/tools/${OUTPUT_FILE} 2>/dev/null

# Cleanup
rm -f /tmp/symbols.json /tmp/patterns.json /tmp/refined_context.json 2>/dev/null
