#!/bin/bash
TARGET=$1
LOG_FILE=".build/test_output.log"

echo "Running tests for $TARGET..."
swift test --filter $TARGET > $LOG_FILE 2>&1
EXIT_CODE=$?

python3 ../tools/governance/scripts/generate_test_receipt.py $LOG_FILE $TARGET

if [ $EXIT_CODE -ne 0 ]; then
    echo "Tests failed. See anigma/Docs/Evidence/${TARGET}_receipt.md for details."
    exit $EXIT_CODE
fi
