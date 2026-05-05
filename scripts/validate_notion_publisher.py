import os
import sys
import subprocess
from pathlib import Path

def run_cmd(cmd, desc):
    print(f"Running: {desc}...")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"FAILED: {desc}")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    print(f"OK: {desc}")

def main():
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)

    print("--- Anigma Notion Publisher Validation ---")

    run_cmd("python3 -m py_compile scripts/anigma_publish_notion_v2.py", "Compile publisher script")
    run_cmd("python3 -m py_compile scripts/notion/client.py", "Compile notion client")
    run_cmd("python3 -m py_compile Scripts/notion/block_diff.py", "Compile block diff planner")
    
    # Run tests
    run_cmd("export PYTHONPATH=$PYTHONPATH:.:./scripts && python3 tests/test_notion_block_diff.py", "Run block diff tests")
    run_cmd("export PYTHONPATH=$PYTHONPATH:.:./scripts && python3 tests/test_notion_list_diff.py", "Run list diff tests")
    run_cmd("export PYTHONPATH=$PYTHONPATH:.:./scripts && python3 tests/test_notion_publisher_report.py", "Run publisher report tests")

    # Check documentation existence
    if not (repo_root / "Docs" / "publishing" / "NOTION_PUBLISHER_OPERATIONS.md").exists():
        print("FAILED: NOTION_PUBLISHER_OPERATIONS.md not found.")
        sys.exit(1)
        
    print("OK: Operations doc exists.")

    print("--- Validation Successful ---")

if __name__ == "__main__":
    main()
