#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PACKAGE_FILE="${PROJECT_ROOT}/Package.swift"
KERNEL_FILE="${PROJECT_ROOT}/Packages/DaemonKernel/Sources/DaemonKernel/DaemonKernel.swift"
CONTRACTS_FILE="${PROJECT_ROOT}/Packages/DaemonFeatureContracts/Sources/DaemonFeatureContracts/DaemonFeatureContracts.swift"
WIRING_FILE="${PROJECT_ROOT}/Packages/AnigmaDaemon/Sources/AnigmaDaemon/AnigmaDaemon.swift"
ENTRYPOINT_FILE="${PROJECT_ROOT}/Packages/AnigmaDaemon/main.swift"

fail() {
    echo "❌ $1" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local needle="$2"
    local message="$3"
    if ! grep -Fq "$needle" "$file"; then
        fail "$message"
    fi
}

assert_only_imports() {
    local file="$1"
    shift
    local allowed=("$@")
    while IFS= read -r import_name; do
        [ -n "$import_name" ] || continue
        local allowed_match=0
        for expected in "${allowed[@]}"; do
            if [[ "$import_name" == "$expected" ]]; then
                allowed_match=1
                break
            fi
        done
        if [[ "$allowed_match" -eq 0 ]]; then
            fail "Unexpected import '$import_name' in $file"
        fi
    done < <(grep -E '^import[[:space:]]+' "$file" | awk '{print $2}')
}

assert_contains "$PACKAGE_FILE" 'name: "AnigmaDaemon"' "AnigmaDaemon target is missing from Package.swift"

anigma_daemon_block="$(awk '
    /name: "AnigmaDaemon"/ { capture=1 }
    capture { print }
    capture && /\),$/ { exit }
' "$PACKAGE_FILE")"

if ! grep -Fq '"DaemonKernel"' <<<"$anigma_daemon_block"; then
    fail "AnigmaDaemon target must depend on DaemonKernel"
fi

if ! grep -Fq '"ModelRegistryDaemonFeature"' <<<"$anigma_daemon_block"; then
    fail "AnigmaDaemon target must depend on ModelRegistryDaemonFeature"
fi

assert_only_imports "$KERNEL_FILE" Foundation DaemonFeatureContracts
assert_only_imports "$CONTRACTS_FILE" Foundation
assert_contains "$WIRING_FILE" 'import DaemonKernel' "AnigmaDaemon wiring must import DaemonKernel"
assert_contains "$WIRING_FILE" 'import ModelRegistryDaemonFeature' "AnigmaDaemon wiring must import ModelRegistryDaemonFeature"
assert_contains "$WIRING_FILE" 'import DaemonStatusDaemonFeature' "AnigmaDaemon wiring must import DaemonStatusDaemonFeature"
assert_contains "$WIRING_FILE" 'bootstrapKernel(kernel, with: [' "AnigmaDaemon wiring must bootstrap the kernel with explicit features"
assert_contains "$WIRING_FILE" 'ModelRegistryDaemonFeature.self' "AnigmaDaemon wiring must register ModelRegistryDaemonFeature explicitly"
assert_contains "$WIRING_FILE" 'DaemonStatusDaemonFeature.self' "AnigmaDaemon wiring must register DaemonStatusDaemonFeature explicitly"
assert_contains "$ENTRYPOINT_FILE" 'AnigmaDaemon(configuration: configuration)' "AnigmaDaemon entrypoint must compose through AnigmaDaemon"
assert_contains "$ENTRYPOINT_FILE" 'try await daemon.start()' "AnigmaDaemon entrypoint must start the composed daemon"

echo "✅ Daemon kernel boundary verified."
