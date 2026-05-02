#!/usr/bin/env bash
# Scripts/harmonia-surface.sh
# Surface testing and concurrency validation wrapper for Harmonia

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Harmonia Surface Compliance Layer"
echo "================================="

if [[ "${1:-}" == "--help" ]]; then
    # Show help without building if possible, or just let the tool show it
    echo "This wrapper builds and runs the HarmoniaSurface tool."
    echo ""
fi

# Build deterministicly using release configuration as per strict governance
echo "Compiling Harmonia (release)..."
swift build --product harmonia -c release -Xswiftc -strict-concurrency=complete

echo "Executing Surface Validation..."
# Run the surface tool, passing all arguments
# Surface behavior now lives under the consolidated Harmonia CLI.
swift run -c release harmonia surface "$@"
