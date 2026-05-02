#!/usr/bin/env python3
import json
import os
import hashlib
import sys

# Mock bootstrap script that validates the lock file and "installs" dependencies
# In a real scenario, this would git clone, check hashes, and run cmake/ninja.

LOCK_FILE = "Native/native-deps.lock.json"
INSTALL_DIR = "Native/ThirdParty"

def main():
    print(f"Bootstrapping native dependencies from {LOCK_FILE}...")
    
    if not os.path.exists(LOCK_FILE):
        print(f"Error: {LOCK_FILE} not found.")
        sys.exit(1)
        
    with open(LOCK_FILE, 'r') as f:
        data = json.load(f)
        
    deps = data.get("dependencies", [])
    if not deps:
        print("No dependencies found in lock file.")
        sys.exit(0)
        
    os.makedirs(INSTALL_DIR, exist_ok=True)
    
    for dep in deps:
        name = dep.get("name")
        version = dep.get("version")
        url = dep.get("url")
        expected_hash = dep.get("hash")
        
        print(f"Processing {name} ({version})...")
        
        # Simulate installation
        dep_dir = os.path.join(INSTALL_DIR, name)
        if not os.path.exists(dep_dir):
            os.makedirs(dep_dir)
            # Write a receipt file
            with open(os.path.join(dep_dir, "receipt.json"), 'w') as receipt:
                json.dump(dep, receipt, indent=2)
            print(f"  - Installed to {dep_dir}")
        else:
            print(f"  - Already installed")
            
    print("Bootstrap complete. Native dependencies are ready (mocked).")

if __name__ == "__main__":
    main()
