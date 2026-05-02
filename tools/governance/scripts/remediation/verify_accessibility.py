#!/usr/bin/env python3
import os
import re
import sys

# Configuration
SEARCH_PATHS = [
    "Sources/AnigmaAppMac/Surfaces",
    "Sources/AnigmaAppMac/Components"
]
LOOKAHEAD_LINES = 50  # Number of lines to check after a UI element for accessibility modifiers

# Patterns to detect UI elements
UI_ELEMENTS = [
    (r'(?<![a-zA-Z0-9])Button\s*\(', "Button"),
    (r'(?<![a-zA-Z0-9])TextField\s*\(', "TextField"),
    (r'(?<![a-zA-Z0-9])Toggle\s*\(', "Toggle"),
    (r'(?<![a-zA-Z0-9])Picker\s*\(', "Picker"),
    (r'onTapGesture', "TapGesture") # Often makes things interactive
]

# Patterns that satisfy accessibility requirement
ACCESSIBILITY_MODIFIERS = [
    r'\.accessibilityLabel',
    r'\.accessibilityHint',
    r'// OK: Accessibility', # Allow manual suppression
    r'\.accessibilityHidden\(true\)' # Hidden elements don't need labels
]

def check_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    violations = []
    
    for i, line in enumerate(lines):
        for pattern, element_type in UI_ELEMENTS:
            if re.search(pattern, line):
                # Found a UI element. Check subsequent lines.
                is_compliant = False
                
                # Check current line first
                for mod in ACCESSIBILITY_MODIFIERS:
                    if re.search(mod, line):
                        is_compliant = True
                        break
                
                if is_compliant:
                    continue

                # Check lookahead lines
                lookahead = min(len(lines), i + LOOKAHEAD_LINES)
                block = "".join(lines[i+1:lookahead])
                
                # Check if specific modifiers exist in the block
                for mod in ACCESSIBILITY_MODIFIERS:
                    if re.search(mod, block):
                        is_compliant = True
                        break
                        
                if not is_compliant:
                    # Double check we didn't hit another element start which might confuse things
                    # (Simple heuristic: if we see another element of same type, we might be looking too far, 
                    # but usually modifiers interfere closer. We'll stick to simple lookahead for now)
                    violations.append({
                        "file": file_path,
                        "line": i + 1,
                        "type": element_type,
                        "content": line.strip()
                    })

    return violations

def main():
    print("🔍 Advanced Accessibility Verification (Multi-line Support)")
    root_dir = os.getcwd()
    
    all_violations = []
    
    for search_path in SEARCH_PATHS:
        full_path = os.path.join(root_dir, search_path)
        if not os.path.exists(full_path):
            print(f"⚠️  Path not found: {search_path}")
            continue
            
        for root, _, files in os.walk(full_path):
            for file in files:
                if file.endswith(".swift"):
                    file_path = os.path.join(root, file)
                    violations = check_file(file_path)
                    all_violations.extend(violations)

    # Report
    if not all_violations:
        print("✅ No accessibility violations found!")
        sys.exit(0)
    
    print(f"❌ Found {len(all_violations)} violations:")
    
    # Group by file
    files_with_violations = {}
    for v in all_violations:
        f = v['file']
        if f not in files_with_violations:
            files_with_violations[f] = []
        files_with_violations[f].append(v)
        
    for f, vs in files_with_violations.items():
        rel_path = f.replace(root_dir + "/", "")
        print(f"\n📄 {rel_path} ({len(vs)} violations)")
        for v in vs:
            print(f"   Line {v['line']} [{v['type']}]: {v['content']}")

    print(f"\n❌ Total Violations: {len(all_violations)}")
    sys.exit(1)

if __name__ == "__main__":
    main()
