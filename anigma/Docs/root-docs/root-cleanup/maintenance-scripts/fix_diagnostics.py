#!/usr/bin/env python3
import re
import sys

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Fix beginSpan calls - change metadata back to tags
    content = re.sub(
        r'beginSpan\s*\(\s*name:\s*[^)]+category:\s*[^)]+correlationID:\s*[^)]+metadata:',
        lambda m: m.group(0).replace('metadata:', 'tags:'),
        content
    )
    
    with open(filepath, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    for filepath in sys.argv[1:]:
        fix_file(filepath)
