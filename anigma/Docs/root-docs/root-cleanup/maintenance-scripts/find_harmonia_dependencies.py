#!/usr/bin/env python3

import re

with open('anigma/Package.swift', 'r') as f:
    content = f.read()

# Find all targets that depend on HarmoniaV2Surface
lines = content.split('\n')
in_target = False
target_name = None
dependencies = []

for line in lines:
    if '.target(name:' in line:
        in_target = True
        name_match = re.search(r'name:\s*"([^"]+)"', line)
        if name_match:
            target_name = name_match.group(1)
    elif in_target and 'dependencies:' in line:
        if 'HarmoniaV2Surface' in line:
            dependencies.append(target_name)
        in_target = False

print(f"Found {len(dependencies)} targets that depend on HarmoniaV2Surface:")
for i, dep in enumerate(dependencies, 1):
    print(f"{i}. {dep}")