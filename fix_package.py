#!/usr/bin/env python3
"""
Fix Package.swift warnings systematically.
"""

import re
from pathlib import Path

package_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

with open(package_path, 'r') as f:
    lines = f.readlines()

# Files that don't exist - remove from all exclude entries
non_existent = {
    'README.md',
    'ToolContracts/ToolContracts/README.md',
    'DiagnosticsSchema.md',
    'Governance/INVARIANTS.md',
    'Jobs/README.md',
    'Pipeline/MLWorkerInterface.swift',
    'XCTest+Golden.swift',
    'TranscriptumModuleStub.swift',
    'ObservatoriumModuleStub.swift',
    'Model/embedding-model.txt',
    'JobKinds/README.md',
    'Protos/anigma.proto',
    'Protos/anigma.capnp',
    'main.swift',
    'Package.swift.backup',
    'Components',  # This is a directory, not in exclude
}

output = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Handle exclude lines
    if 'exclude:' in line:
        # Collect the full exclude array (may span multiple lines)
        exclude_start = i
        brace_count = line.count('[') - line.count(']')
        exclude_lines = [line]
        i += 1
        while i < len(lines) and brace_count > 0:
            exclude_lines.append(lines[i])
            brace_count += lines[i].count('[') - lines[i].count(']')
            i += 1
        
        # Join the exclude lines and process
        exclude_block = ''.join(exclude_lines)
        
        # Remove non-existent files from the array
        # Find all quoted strings
        strings = re.findall(r'"([^"]+)"', exclude_block)
        valid_strings = [s for s in strings if s not in non_existent]
        
        if not valid_strings:
            # Empty exclude array
            output.append(re.sub(r'exclude:\s*\[[^\]]*\]', 'exclude: []', exclude_block))
        else:
            # Rebuild the exclude array with only valid files
            new_array = '[' + ', '.join(f'"{s}"' for s in valid_strings) + ']'
            output.append(re.sub(r'\[[^\]]*\]', new_array, exclude_block, count=1))
        
        continue
    else:
        output.append(line)
        i += 1

# Write back
with open(package_path, 'w') as f:
    f.writelines(output)

print("Fixed exclude entries")
