import os
import sys
import yaml
from pathlib import Path

def check_file(path_str):
    p = Path(path_str)
    if p.exists():
        print(f"OK: {path_str} exists.")
        return True
    else:
        print(f"FAILED: {path_str} not found.")
        return False

def validate_yaml(path_str):
    p = Path(path_str)
    if not p.exists():
        print(f"FAILED: {path_str} not found.")
        return False
    try:
        with open(p, "r") as f:
            yaml.safe_load(f)
        print(f"OK: {path_str} is valid YAML.")
        return True
    except Exception as e:
        print(f"FAILED: {path_str} YAML parsing error: {e}")
        return False

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("--- Public Project Readiness Validation ---")

    files_to_check = [
        "Docs/dashboard/PROJECT_DASHBOARD.md",
        "Docs/dashboard/CHANGELOG_HISTORY.md",
        "Docs/dashboard/ISSUE_STATUS.md",
        "Docs/dashboard/PUBLISHING_HEALTH.md",
        "CHANGELOG.md",
        "Docs/legal/DEPENDENCY_POLICY.md",
        "Docs/legal/APP_STORE_DISTRIBUTION_NOTES.md",
        "THIRD_PARTY_NOTICES.md",
        "CONTRIBUTING.md",
        "Docs/publishing/NOTION_PUBLISHER_OPERATIONS.md",
        "Docs/proofs/tb-2026-05-04-public-project-readiness-pass.md"
    ]

    all_passed = True
    for f in files_to_check:
        if not check_file(f):
            all_passed = False

    if not validate_yaml("Docs/legal/THIRD_PARTY_INVENTORY.yaml"):
        all_passed = False

    if not all_passed:
        print("--- Validation Failed ---")
        sys.exit(1)
    
    print("--- Validation Successful ---")

if __name__ == "__main__":
    main()
