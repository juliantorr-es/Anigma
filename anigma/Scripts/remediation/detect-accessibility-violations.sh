#!/usr/bin/env bash
# Scripts/remediation/detect-accessibility-violations.sh
# Detection script for accessibility violations
# Delegates to verify_accessibility.py for advanced multi-line support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/verify_accessibility.py"

if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
    echo "❌ Error: verify_accessibility.py not found at ${PYTHON_SCRIPT}"
    exit 1
fi

chmod +x "${PYTHON_SCRIPT}"
"${PYTHON_SCRIPT}"
