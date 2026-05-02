#!/usr/bin/env python3
"""
Only remove exclude entries for files that DEFINITELY don't exist.
Keep all other exclude entries intact.
"""

import re
from pathlib import Path

package_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

with open(package_path, 'r') as f:
    content = f.read()

# Files that DEFINITELY don't exist (verified earlier)
# These are safe to remove from ALL exclude entries
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
    'Package.swift.backup',
    'Components',
}

# Circular references (path excludes itself)
circular = {
    'Packages/AnigmaPrimitives',
    'Packages/CapsuleCore/Sources/CapsuleCore',
    'Packages/AnigmaASTServices',
    'Packages/CathedralModule',
    'Packages/AnigmaCLI/Core',
    'Packages/AnigmaCLI/Orchestrator',
    'Packages/AnigmaCLI/Database',
    'Packages/AnigmaCLIMCP',
    'Packages/AnigmaCLI/Sources/LocalInference',
}

all_invalid = definitely_missing | circular

# For each invalid file, remove it from exclude arrays
# We need to be careful to only remove the exact string, not break the syntax

for invalid_file in sorted(all_invalid, key=len, reverse=True):
    escaped = re.escape(invalid_file)
    
    # Pattern 1: Single item - exclude: ["invalid_file"] -> exclude: []
    content = re.sub(
        rf'(exclude:\s*\[\s*"{escaped}"\s*\])',
        'exclude: []',
        content
    )
    
    # Pattern 2: First of multiple items - ["invalid_file", "other"] -> ["other"]
    content = re.sub(
        rf'\[\s*"{escaped}",\s*"([^"]+)"\s*\]',
        r'["\1"]',
        content
    )
    
    # Pattern 3: Middle of multiple - ["other", "invalid_file", "another"] -> ["other", "another"]
    content = re.sub(
        rf'"([^"]+)",\s*"{escaped}",\s*"([^"]+)"',
        r'"\1", "\2"',
        content
    )
    
    # Pattern 4: Last of multiple - ["other", "invalid_file"] -> ["other"]
    content = re.sub(
        rf'\[\s*"([^"]+)",\s*"{escaped}"\s*\]',
        r'["\1"]',
        content
    )

# Clean up empty arrays that might have been created
# But be careful not to touch arrays with valid content
content = re.sub(r'exclude:\s*\[\s*\]', 'exclude: []', content)

with open(package_path, 'w') as f:
    f.write(content)

print("Fixed exclude entries")
