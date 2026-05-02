#!/usr/bin/env python3
"""
Script to fix Swift Package Manager warnings in Package.swift.

Issues addressed:
1. Invalid exclude: entries for non-existent files (README.md, etc.)
2. Test target paths that don't match actual file locations
3. Test targets with no source files
4. Unhandled files (not declared as resources or excluded)
"""

import re
import os
from pathlib import Path

# Path to the Package.swift file
package_swift_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

# Read the original file
with open(package_swift_path, 'r') as f:
    content = f.read()

# List of files that DON'T exist (from the warnings)
# We'll remove these from exclude: entries
non_existent_files = [
    "README.md",
    "ToolContracts/ToolContracts/README.md",
    "DiagnosticsSchema.md",
    "Governance/INVARIANTS.md",
    "Jobs/README.md",
    "Pipeline/MLWorkerInterface.swift",
    "XCTest+Golden.swift",
    "TranscriptumModuleStub.swift",
    "ObservatoriumModuleStub.swift",
    "Model/embedding-model.txt",
    "JobKinds/README.md",
    "Protos/anigma.proto",
    "Protos/anigma.capnp",
    "main.swift",
    "Package.swift.backup",
]

# Remove exclude entries for non-existent files
# This is tricky because we need to handle arrays properly
for file_path in non_existent_files:
    # Pattern: exclude: ["file_path"] or exclude: ["...", "file_path", "..."]
    # We'll replace "file_path" in exclude arrays with empty string and clean up
    
    # Simple case: exclude: ["file_path"]
    pattern1 = rf'(exclude:\s*\[\s*"{re.escape(file_path)}"\s*\])'
    content = re.sub(pattern1, 'exclude: []', content)
    
    # In array with other items: ["other", "file_path", "another"]
    pattern2 = rf'"{re.escape(file_path)}"\s*,\s*'
    content = re.sub(pattern2, '', content)
    
    pattern3 = rf',\s*"{re.escape(file_path)}"'
    content = re.sub(pattern3, '', content)
    
    # Also handle the case where it's the only item but with trailing comma
    pattern4 = rf'(exclude:\s*\[\s*"{re.escape(file_path)}",\s*\])'
    content = re.sub(pattern4, 'exclude: []', content)

# Clean up empty strings in arrays and arrays with only commas
# Replace [", "] with []
content = re.sub(r'\[\s*",\s*"\s*\]', '[]', content)
# Replace [","] with []
content = re.sub(r'\[\s*",\s*\]', '[]', content)
# Replace [", "] with []
content = re.sub(r'\[\s*",\s*"\s*\]', '[]', content)

# Now handle test targets with no source files
# These are the empty directories that have test targets defined
empty_test_targets = [
    "GovernanceCoreTests",
    "CathedralModuleTests", 
    "AnigmaPrimitivesTests",
    "CosineSimilarityCapsuleTests",
    "AssistantEvalFixturesTests",
    "DaemonKernelTests",
    "ExecutionCoreTests",
    "AnigmaCLIOrchestratorTests",
    "MessagingIntegrationTests",
    "AnigmaCLIDatabaseTests",
    "AnigmaDaemonVerifierTests",
    "BackendStabilizationTests",
]

# For test targets that have files in nested directories, update the path
# AnigmaPrimitivesTests files are in Tests/Constitutional/AnigmaPrimitivesTests
content = re.sub(
    r'name:\s*"AnigmaPrimitivesTests"[^}]+path:\s*"Tests/AnigmaPrimitivesTests"',
    'name: "AnigmaPrimitivesTests",\n    dependencies: [\n      "AnigmaPrimitives"\n    ],\n    path: "Tests/Constitutional/AnigmaPrimitivesTests"',
    content
)

# Comment out test targets that have no source files
# We'll comment out the entire .testTarget block
for test_name in empty_test_targets:
    # Find the testTarget block for this name
    pattern = rf'(\.testTarget\(\s*name:\s*"{re.escape(test_name)}"[^}]+\})'
    # Replace with commented version
    content = re.sub(pattern, r'// \1', content, flags=re.DOTALL)

# Write the fixed content
with open(package_swift_path, 'w') as f:
    f.write(content)

print("Fixed Package.swift")
