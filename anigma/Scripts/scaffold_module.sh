#!/bin/bash
# Scripts/scaffold_module.sh
# Standardized module scaffolding for Anigma

MODULE_NAME=$1
TIER=$2

if [ -z "$MODULE_NAME" ] || [ -z "$TIER" ]; then
    echo "Usage: $0 <ModuleName> <Tier (1|2|3)>"
    echo "Example: $0 MyNewFeature 3"
    exit 1
fi

# Ensure Module suffix if missing (optional, but convention is mixed)
# case $MODULE_NAME in
#     *Module|*Core|*Kit|*CLI|*UI|*TUI) ;;
#     *) MODULE_NAME="${MODULE_NAME}Module" ;;
# esac

MODULE_PATH="Packages/${MODULE_NAME}"

if [ -d "$MODULE_PATH" ]; then
    echo "Error: Module ${MODULE_NAME} already exists at ${MODULE_PATH}"
    exit 1
fi

echo "Creating module ${MODULE_NAME} in Tier ${TIER}..."

# Create directory structure
mkdir -p "${MODULE_PATH}/Sources/${MODULE_NAME}"
mkdir -p "Tests/${MODULE_NAME}Tests"

# Create Source file
cat <<EOF > "${MODULE_PATH}/Sources/${MODULE_NAME}/${MODULE_NAME}.swift"
import Foundation
import AnigmaPrimitives

/// ${MODULE_NAME} - Tier ${TIER} module
public struct ${MODULE_NAME} {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}
EOF

# Create Test file
cat <<EOF > "Tests/${MODULE_NAME}Tests/${MODULE_NAME}Tests.swift"
import XCTest
@testable import ${MODULE_NAME}

final class ${MODULE_NAME}Tests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(${MODULE_NAME}().text, "Hello, World!")
    }
}
EOF

# Create README.md
cat <<EOF > "${MODULE_PATH}/README.md"
# ${MODULE_NAME} (Tier ${TIER})

**Description of ${MODULE_NAME}**

## Responsibilities
- 

## Tier ${TIER} Compliance
- Depends on:
$(if [ "$TIER" -eq 3 ]; then echo "- Tier 2 (Platform Runtime)"; echo "- Tier 1 (Governance)"; elif [ "$TIER" -eq 2 ]; then echo "- Tier 1 (Governance)"; fi)

## Usage
```swift
import ${MODULE_NAME}
// ...
```
EOF

echo "Module ${MODULE_NAME} scaffolded successfully."
echo "---------------------------------------------------"
echo "Next steps:"
echo "1. Add the module to Package.swift:"
echo "   - In products (library or executable)"
echo "   - In targets (${MODULE_NAME} and ${MODULE_NAME}Tests)"
echo "2. Add dependencies to ${MODULE_NAME} target in Package.swift"
echo "---------------------------------------------------"
