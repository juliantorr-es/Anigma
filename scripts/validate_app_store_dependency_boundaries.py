import os
import sys
import yaml
import re
from pathlib import Path

def validate_yaml(path_str):
    p = Path(path_str)
    if not p.exists():
        print(f"FAILED: {path_str} not found.")
        return False, {}
    try:
        with open(p, "r") as f:
            data = yaml.safe_load(f)
        return True, data
    except Exception as e:
        print(f"FAILED: {path_str} YAML parsing error: {e}")
        return False, {}

def check_package_swift(path_str):
    p = Path(path_str)
    if not p.exists():
        print(f"OK (skip): {path_str} not found.")
        return True
        
    with open(p, 'r') as f:
        content = f.read()
        
    # Check for hardcoded ENABLE_FFMPEG_LINKING environment overrides that might force it on
    if 'setenv("ENABLE_FFMPEG_LINKING", "1"' in content:
        print("FAILED: ENABLE_FFMPEG_LINKING forced ON in Package.swift.")
        return False
        
    return True

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("--- App Store Dependency Boundaries Validation ---")
    
    all_passed = True
    
    # 1. Check Package.swift
    if not check_package_swift("anigma/Package.swift"):
        all_passed = False
        
    # 2. Validate YAML and check dependencies
    yaml_path = "Docs/legal/THIRD_PARTY_INVENTORY.yaml"
    is_valid_yaml, inventory = validate_yaml(yaml_path)
    
    if not is_valid_yaml:
        all_passed = False
    else:
        dependencies = inventory.get("dependencies", [])
        
        ffmpeg_found = False
        pdfium_found = False
        
        for dep in dependencies:
            name = dep.get("name", "").lower()
            
            if "ffmpeg" in name:
                ffmpeg_found = True
                if dep.get("distributed_in_app_store_build") is True:
                    print("FAILED: FFmpeg is marked as distributed_in_app_store_build: true. This violates copyleft App Store policy.")
                    all_passed = False
                    
            if "pdfium" in name:
                pdfium_found = True
                
            # Block GPL/AGPL in App Store builds
            if dep.get("distributed_in_app_store_build") is True:
                license_text = dep.get("license", "").lower()
                if "gpl" in license_text and "lgpl" not in license_text: # Block GPL/AGPL
                    if "apple" not in license_text: # ignore false positives
                        print(f"FAILED: Dependency '{dep.get('name')}' is distributed in App Store build but has GPL/AGPL license: {dep.get('license')}")
                        all_passed = False
                        
        if not ffmpeg_found:
            print("FAILED: FFmpeg not tracked in THIRD_PARTY_INVENTORY.yaml")
            all_passed = False
            
        if not pdfium_found:
            print("FAILED: PDFium not tracked in THIRD_PARTY_INVENTORY.yaml")
            all_passed = False

    # 3. Check THIRD_PARTY_NOTICES.md for PDFium if it exists
    notices_path = Path("THIRD_PARTY_NOTICES.md")
    if notices_path.exists():
        with open(notices_path, 'r') as f:
            notices = f.read().lower()
            if "pdfium" not in notices:
                print("WARNING: PDFium is not mentioned in THIRD_PARTY_NOTICES.md. If bundled, it requires notices.")
                # We won't fail the script just for the warning, but we flag it.

    if not all_passed:
        print("--- Boundary Validation Failed ---")
        sys.exit(1)
    
    print("--- Boundary Validation Successful ---")

if __name__ == "__main__":
    main()
