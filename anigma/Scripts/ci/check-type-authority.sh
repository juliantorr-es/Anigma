#!/usr/bin/env bash
# Tools/ci/check-type-authority.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Type Authority Check"
echo "Root: ${PROJECT_ROOT}"
echo ""

# Reserved type ownership map
# Format: "TypeName:ExpectedModule"
RESERVED_TYPES=(
    "World:AnigmaCore"
    "EntityId:AnigmaPrimitives"
    "EntityID:AnigmaPrimitives"
    "Component:AnigmaCore"
    "System:AnigmaCore"
    "DatabaseConfiguration:DatabaseCore"
)

violations=0

for item in "${RESERVED_TYPES[@]}"; do
    type_name="${item%%:*}"
    expected_module="${item#*:}"
    
    # Search for public definitions of this type in the wrong modules
    # We use word boundaries \b to avoid matching TypeNameSomething
    find_cmd="grep -rE \"public (struct|class|enum|actor|protocol) $type_name\b\" \"$PROJECT_ROOT/Sources\" \"$PROJECT_ROOT/Packages\" --include=\"*.swift\""
    
    results=$(eval "$find_cmd" || true)
    
    if [[ -n "$results" ]]; then
        while read -r line; do
            file_path=$(echo "$line" | cut -d: -f1)
            # Extract module name from path
            if [[ "$file_path" == *"/Packages/"* ]]; then
                actual_module=$(echo "$file_path" | sed 's|.*/Packages/\([^/]*\)/.*|\1|')
            elif [[ "$file_path" == *"/Sources/"* ]]; then
                actual_module=$(echo "$file_path" | sed 's|.*/Sources/\([^/]*\)/.*|\1|')
            else
                actual_module="Unknown"
            fi
            
            if [[ "$actual_module" != "$expected_module" ]]; then
                echo "❌ AUTHORITY VIOLATION: $type_name redefined in $actual_module"
                echo "   Expected owner: $expected_module"
                echo "   Found in: $file_path"
                violations=$((violations + 1))
            fi
        done <<< "$results"
    fi
done

if [[ "$violations" -gt 0 ]]; then
    echo ""
    echo "FAILED: $violations authority violations found."
    echo "::endgroup::"
    exit 1
fi

echo "✅ PASSED: Type authority verified."
echo "::endgroup::"
exit 0