import os
import sys
import subprocess
import json
import yaml
from pathlib import Path
from datetime import datetime

def run_script(script_path):
    print(f"\n>>> Running: {script_path}")
    result = subprocess.run([sys.executable, script_path], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[!] FAILED: {script_path}")
        print(result.stdout)
        print(result.stderr)
        return False
    print(f"[OK] {script_path} passed.")
    return True

def check_file(path_str):
    if Path(path_str).exists():
        print(f"[OK] Found: {path_str}")
        return True
    print(f"[!] MISSING: {path_str}")
    return False

def check_yaml(path_str):
    try:
        with open(path_str, "r") as f:
            yaml.safe_load(f)
        print(f"[OK] YAML valid: {path_str}")
        return True
    except Exception as e:
        print(f"[!] INVALID YAML: {path_str} - {e}")
        return False

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("=========================================")
    print("   ALPHA RELEASE READINESS VALIDATION    ")
    print("=========================================")

    # Parse arguments for JSON output
    report_json_path = None
    if len(sys.argv) == 3 and sys.argv[1] == "--report-json":
        report_json_path = sys.argv[2]

    passed_checks = []
    failed_checks = []
    missing_artifacts = []

    # 1. Run sub-validators
    scripts_to_run = [
        "Scripts/validate_app_store_dependency_boundaries.py",
        "Scripts/validate_app_store_build_profile.py",
        "Scripts/validate_public_project_readiness.py",
        "Scripts/validate_notion_publisher.py"
    ]

    for script in scripts_to_run:
        if run_script(script):
            passed_checks.append(script)
        else:
            failed_checks.append(script)

    # 2. Check essential artifacts
    artifacts_to_check = [
        "Docs/release/ALPHA_RELEASE_READINESS.md",
        "Docs/release/APP_STORE_BUILD_PROFILE.md",
        "Docs/release/app-store-profile.yaml",
        "Docs/legal/THIRD_PARTY_INVENTORY.yaml",
        "THIRD_PARTY_NOTICES.md",
        "CHANGELOG.md",
        "Docs/dashboard/PROJECT_DASHBOARD.md",
        "Docs/proofs/tb-2026-05-04-pdfium-app-store-exclusion.md",
        "Docs/proofs/tb-2026-05-04-app-store-build-profile-gate.md"
    ]

    for artifact in artifacts_to_check:
        if check_file(artifact):
            if artifact.endswith(".yaml"):
                if check_yaml(artifact):
                    passed_checks.append(artifact)
                else:
                    failed_checks.append(artifact)
            else:
                passed_checks.append(artifact)
        else:
            missing_artifacts.append(artifact)
            failed_checks.append(artifact)

    # 3. Determine Overall Status
    is_ready = len(failed_checks) == 0

    print("\n=========================================")
    if is_ready:
        print("  ✅ ALPHA RELEASE GATES: PASS           ")
    else:
        print("  ❌ ALPHA RELEASE GATES: FAIL           ")
    print("=========================================")

    # 4. Generate JSON Report
    if report_json_path:
        report = {
            "status": "pass" if is_ready else "fail",
            "validators_run": scripts_to_run,
            "passed": passed_checks,
            "failed": failed_checks,
            "missing_artifacts": missing_artifacts,
            "release_blockers": failed_checks,
            "needs_review": ["Manual items in ALPHA_RELEASE_READINESS.md"],
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        with open(report_json_path, "w") as f:
            json.dump(report, f, indent=2)
        print(f"[i] JSON report saved to: {report_json_path}")

    if not is_ready:
        sys.exit(1)

if __name__ == "__main__":
    main()
