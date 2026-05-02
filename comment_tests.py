#!/usr/bin/env python3
import re
from pathlib import Path

package_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

with open(package_path, 'r') as f:
    content = f.read()

# Empty test targets to comment out
empty_tests = [
    "CosineSimilarityCapsuleTests",
    "AssistantEvalFixturesTests",
    "DaemonKernelTests",
    "ExecutionCoreTests",
    "AnigmaCLIOrchestratorTests",
    "MessagingIntegrationTests",
]

for test_name in empty_tests:
    # Escape the test name
    escaped = re.escape(test_name)
    # Find the testTarget block and comment it out
    pattern = r'(\.testTarget\(\s*name:\s*"' + escaped + r'"[^}]+\})'
    replacement = r'// \1'
    # Use DOTALL to match across newlines
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(package_path, 'w') as f:
    f.write(content)

print("Commented out empty test targets")
