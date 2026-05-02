#!/usr/bin/env python3
"""
Fix Package.swift warnings - conservative approach.
Only remove exclude entries we are CERTAIN are invalid.
"""

import re
from pathlib import Path

package_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

with open(package_path, 'r') as f:
    content = f.read()

# These files DEFINITELY don't exist anywhere in the project
# We verified this earlier
definitely_missing = {
    'README.md',
    'ToolContracts/ToolContracts/README.md',
    'DiagnosticsSchema.md',
    'Governance/INVARIANTS.md',
    'Jobs/README.md',
    'XCTest+Golden.swift',
    'TranscriptumModuleStub.swift',
    'ObservatoriumModuleStub.swift',
    'Model/embedding-model.txt',
    'JobKinds/README.md',
    'Protos/anigma.proto',
    'Protos/anigma.capnp',
    'main.swift',
    'CLIAnalyticsIntegrationGuide.md',
    'Package.swift.backup',
    'Components',
}

# Also these are invalid circular references
invalid_circular = {
    'Packages/AnigmaPrimitives',
    'Packages/CapsuleCore/Sources/CapsuleCore',
}

# Combine
all_invalid = definitely_missing | invalid_circular

# Replace exclude entries containing only invalid files
# Pattern: exclude: ["invalid_file"] -> exclude: []
for invalid_file in sorted(all_invalid, key=len, reverse=True):
    # Escape special regex characters
    escaped = re.escape(invalid_file)
    
    # Case 1: Single item exclude array
    pattern = rf'(exclude:\s*\[\s*"{escaped}"\s*\])'
    content = re.sub(pattern, 'exclude: []', content)
    
    # Case 2: Multi-item, this file is one of them - just remove this one item
    # ["other", "invalid_file", "another"] -> ["other", "another"]
    pattern = rf'"{escaped}"\s*,\s*'
    content = re.sub(pattern, '', content)
    
    pattern = rf',\s*"{escaped}"'
    content = re.sub(pattern, '', content)
    
    # Case 3: First item with trailing comma
    pattern = rf'(exclude:\s*\[\s*"{escaped}",\s*)'
    content = re.sub(pattern, 'exclude: [', content)

# Clean up double commas and trailing commas in arrays
content = re.sub(r'\[\s*,\s*\]', '[]', content)
content = re.sub(r',\s*,', ',', content)
content = re.sub(r',\s*\]', ']', content)
content = re.sub(r'\[\s*,', '[', content)

with open(package_path, 'w') as f:
    f.write(content)

print("Fixed Package.swift")
