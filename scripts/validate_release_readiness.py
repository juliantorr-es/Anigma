import os
import sys
import subprocess
from pathlib import Path

def run_script(script_path):
    print(f"\n>>> Running: {script_path}")
    result = subprocess.run([sys.executable, script_path], capture_output=False)
    if result.returncode != 0:
        print(f"\n[!] VALIDATION FAILED: {script_path} exited with code {result.returncode}")
        return False
    return True

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("=========================================")
    print("      RELEASE READINESS VALIDATION       ")
    print("=========================================")

    scripts_to_run = [
        "Scripts/validate_app_store_dependency_boundaries.py",
        "Scripts/validate_app_store_build_profile.py",
        "Scripts/validate_public_project_readiness.py",
        "Scripts/validate_notion_publisher.py"
    ]

    all_passed = True
    for script in scripts_to_run:
        if not run_script(script):
            all_passed = False

    print("\n=========================================")
    if all_passed:
        print("  ✅ ALL READINESS VALIDATIONS PASSED    ")
    else:
        print("  ❌ ONE OR MORE VALIDATIONS FAILED      ")
        sys.exit(1)
    print("=========================================")

if __name__ == "__main__":
    main()
