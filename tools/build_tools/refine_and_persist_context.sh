#!/bin/bash

# Script: refine_and_persist_context.sh
# Usage: ./refine_and_persist_context.sh <query> [directory] <output_file>
# If no directory is provided, the current working directory is used.

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <query> [directory] <output_file>"
    exit 1
fi

QUERY=$1
OUTPUT_FILE=${3:-