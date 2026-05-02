#!/usr/bin/env python3
"""
Final approach: parse Package.swift properly and fix exclude entries.
"""

import re
from pathlib import Path

package_path = Path("/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift")

with open(package_path, 'r') as f:
    content = f.read()

# Invalid files to remove from exclude entries
invalid_files = [
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
    'Packages/AnigmaPrimitives',
    'Packages/CapsuleCore/Sources/CapsuleCore',
]

# Process each line - look for exclude arrays and remove invalid entries
lines = content.split('\n')
output = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if this line starts an exclude array
    if 'exclude:' in line and '[' in line:
        # Collect all lines of the exclude array
        array_start = i
        brace_count = line.count('[') - line.count(']')
        array_lines = [line]
        i += 1
        
        while i < len(lines) and brace_count > 0:
            array_lines.append(lines[i])
            brace_count += lines[i].count('[') - lines[i].count(']')
            i += 1
        
        # Join the array lines
        array_text = '\n'.join(array_lines)
        
        # Extract all quoted strings from the array
        all_strings = re.findall(r'"([^"]+)"', array_text)
        
        # Filter out invalid files
        valid_strings = [s for s in all_strings if s not in invalid_files]
        
        if not valid_strings:
            # No valid files left - use empty array
            # But preserve the structure (replace the array content)
            new_line = re.sub(r'exclude:\s*\[[^\]]*\]', 'exclude: []', array_text)
            output.append(new_line)
        else:
            # Rebuild the array with only valid files
            if len(valid_strings) == 1:
                new_array = f'["{valid_strings[0]}"]'
            else:
                new_array = '[' + ', '.join(f'"{s}"' for s in valid_strings) + ']'
            
            # Replace just the array part
            new_text = re.sub(r'\[[^\]]*\]', new_array, array_text, count=1)
            
            # Split back into lines (preserve original line breaks)
            output.extend(new_text.split('\n'))
        
        continue
    else:
        output.append(line)
        i += 1

# Join output
result = '\n'.join(output)

with open(package_path, 'w') as f:
    f.write(result)

print("Fixed Package.swift")
