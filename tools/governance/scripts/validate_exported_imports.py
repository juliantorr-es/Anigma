import os
import sys

def find_swift_files(root_dir):
    for root, _, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".swift"):
                yield os.path.join(root, file)

def scan_for_exported(file_path):
    issues = []
    with open(file_path, 'r') as f:
        for i, line in enumerate(f, 1):
            if "@_exported" in line and "import" in line:
                # Basic extraction of the module name
                parts = line.split("import")
                if len(parts) > 1:
                    module = parts[1].strip()
                    issues.append((i, module))
    return issues

def validate():
    root_dir = os.path.join(os.getcwd(), 'anigma')
    allowlist = ["GovernanceCore"] # Temporary baseline allowlist
    found_issues = []
    
    print(f"Scanning for @_exported in {root_dir}...")
    for file_path in find_swift_files(root_dir):
        issues = scan_for_exported(file_path)
        for line, module in issues:
            if module not in allowlist:
                found_issues.append((file_path, line, module))
    
    if found_issues:
        print("Violation(s) found:")
        for path, line, mod in found_issues:
            print(f"  {path}:{line} -> @_exported import {mod}")
        sys.exit(1)
    
    print("No non-allowlisted @_exported imports found.")

if __name__ == "__main__":
    validate()
