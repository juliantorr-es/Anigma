#!/usr/bin/env python3

import os
import re
import glob
from pathlib import Path

def find_swift_files(directories):
    """Find all Swift files in the given directories."""
    swift_files = []
    for directory in directories:
        for root, dirs, files in os.walk(directory):
            # Skip build directories and test files
            if '.build' in root or 'Tests' in root or 'Examples' in root:
                continue
            for file in files:
                if file.endswith('.swift'):
                    swift_files.append(os.path.join(root, file))
    return swift_files

def file_needs_conversion(file_path):
    """Check if a file contains print statements and doesn't already have OSLog."""
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        has_print = 'print(' in content
        has_oslog = 'import os.log' in content or 'import os.log' in content
        return has_print and not has_oslog

def add_oslog_import(content):
    """Add OSLog import to the file."""
    # Find the last import statement
    lines = content.split('\n')
    last_import_line = 0
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_line = i
        elif line.strip() and not line.strip().startswith('//'):
            break
    
    # Insert OSLog import after the last import
    if last_import_line > 0:
        lines.insert(last_import_line + 1, 'import os.log')
    else:
        # If no imports, add it after the file header comments
        for i, line in enumerate(lines):
            if line.strip() and not line.strip().startswith('//'):
                lines.insert(i, 'import os.log')
                break
    
    return '\n'.join(lines)

def add_logger_declaration(content):
    """Add logger declaration to the file."""
    # Find a good place to add the logger (after imports, before first class/struct)
    lines = content.split('\n')
    
    # Look for the first class/struct/enum declaration
    for i, line in enumerate(lines):
        if (line.strip().startswith('public class ') or 
            line.strip().startswith('class ') or
            line.strip().startswith('public struct ') or
            line.strip().startswith('struct ') or
            line.strip().startswith('public enum ') or
            line.strip().startswith('enum ') or
            line.strip().startswith('public actor ') or
            line.strip().startswith('actor ')):
            # Add logger before this line
            indent = len(line) - len(line.lstrip())
            logger_line = ' ' * indent + 'private let log = Logger(subsystem: "com.anigma.core", category: "{}")'
            lines.insert(i, logger_line.format('file'))
            break
    
    return '\n'.join(lines)

def convert_print_statements(content):
    """Convert print statements to OSLog."""
    # Convert simple print statements
    pattern = r'print\("([^"]*)"\)'
    replacement = r'log.info("\1")'
    content = re.sub(pattern, replacement, content)
    
    # Convert print statements with string interpolation
    pattern = r'print\("([^"]*)"\)'
    # This is more complex and would need better handling
    
    return content

def convert_file(file_path):
    """Convert a single file from print to OSLog."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        print(f"Converting {file_path}")
        
        # Add OSLog import
        if 'import os.log' not in content:
            content = add_oslog_import(content)
            print(f"  ✓ Added OSLog import")
        
        # Add logger declaration
        if 'private let log = Logger' not in content and 'private let log = Logger' not in content:
            content = add_logger_declaration(content)
            print(f"  ✓ Added logger declaration")
        
        # Convert print statements
        original_count = content.count('print(')
        if original_count > 0:
            content = convert_print_statements(content)
            new_count = content.count('print(')
            converted = original_count - new_count
            print(f"  ✓ Converted {converted} print statements")
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return True
    except Exception as e:
        print(f"  ✗ Error converting {file_path}: {e}")
        return False

def main():
    # Directories to process
    directories = [
        'anigma/Packages/AnigmaCore',
        'anigma/Packages/HarmoniaModule', 
        'anigma/Packages/ConexusModule',
        'anigma/Packages/PragmaModule'
    ]
    
    # Find all Swift files that need conversion
    swift_files = find_swift_files(directories)
    files_to_convert = [f for f in swift_files if file_needs_conversion(f)]
    
    print(f"Found {len(files_to_convert)} files needing conversion")
    
    # Convert files
    success_count = 0
    for file_path in files_to_convert:
        if convert_file(file_path):
            success_count += 1
    
    print(f"\nConversion complete: {success_count}/{len(files_to_convert)} files converted")

if __name__ == '__main__':
    main()