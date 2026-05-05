import os
import sys
import yaml
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

def check_env():
    # In a real CI environment, this would check if ENABLE_FFMPEG_LINKING is set in the shell
    # For deterministic validation, we assert it must not be "1"
    val = os.environ.get("ENABLE_FFMPEG_LINKING")
    if val == "1" or val == "true":
        print("FAILED: ENABLE_FFMPEG_LINKING is truthy in environment.")
        return False
    return True

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("--- App Store Build Profile Validation ---")
    all_passed = True

    if not check_env():
        all_passed = False

    # Check for profile doc
    if not Path("Docs/release/APP_STORE_BUILD_PROFILE.md").exists():
        print("FAILED: Docs/release/APP_STORE_BUILD_PROFILE.md not found.")
        all_passed = False

    # Check inventory
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
            dist_app_store = dep.get("distributed_in_app_store_build")
            app_store_status = dep.get("app_store_status", "").lower()
            version = str(dep.get("version", "")).lower()
            source_url = str(dep.get("source_url", "")).lower()
            license_text = str(dep.get("license", "")).lower()
            
            if "ffmpeg" in name:
                ffmpeg_found = True
                if dist_app_store is True:
                    print("FAILED: FFmpeg is marked as distributed_in_app_store_build: true.")
                    all_passed = False
                    
            if "pdfium" in name:
                pdfium_found = True
                if dist_app_store is True:
                    if "needs_review" in version or "unknown" in version:
                        print("FAILED: PDFium is distributed but version is needs_review/unknown.")
                        all_passed = False
                    if "needs_review" in source_url or "unknown" in source_url:
                        print("FAILED: PDFium is distributed but source_url is needs_review/unknown.")
                        all_passed = False
                    
                    # Check notices
                    notices_path = Path("THIRD_PARTY_NOTICES.md")
                    if notices_path.exists():
                        with open(notices_path, 'r') as f:
                            notices = f.read().lower()
                            if "pdfium" not in notices:
                                print("FAILED: PDFium is distributed but missing from THIRD_PARTY_NOTICES.md.")
                                all_passed = False
                            if "transitive notices are pending" in notices or "pending review" in notices:
                                print("FAILED: PDFium transitive notices are still pending in THIRD_PARTY_NOTICES.md.")
                                all_passed = False

            # Block GPL/AGPL in App Store builds
            if dist_app_store is True:
                if "gpl" in license_text and "lgpl" not in license_text and "apple" not in license_text:
                    # Allow if explicitly approved
                    if app_store_status not in ["separately_licensed", "approved"]:
                        print(f"FAILED: GPL/AGPL dependency '{dep.get('name')}' is distributed without explicit approval.")
                        all_passed = False

        if not ffmpeg_found:
            print("FAILED: FFmpeg not tracked in THIRD_PARTY_INVENTORY.yaml")
            all_passed = False
            
        if not pdfium_found:
            print("FAILED: PDFium not tracked in THIRD_PARTY_INVENTORY.yaml")
            all_passed = False

    if not all_passed:
        print("--- Build Profile Validation Failed ---")
        sys.exit(1)
    
    print("--- Build Profile Validation Successful ---")

if __name__ == "__main__":
    main()
