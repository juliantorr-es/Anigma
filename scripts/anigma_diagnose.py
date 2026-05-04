import argparse
import os
import subprocess
import json
import shutil
from pathlib import Path

# Constants and Defaults
DIAGNOSTIC_ROOT = ".build/anigma-diagnostics"
REPO_ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip()

def get_task_path(task_id, commit_hash, phase):
    return Path(DIAGNOSTIC_ROOT) / "tasks" / task_id / commit_hash / phase

def run_cmd(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd or REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def baseline(args):
    commit_hash = run_cmd(["git", "rev-parse", "HEAD"]).stdout.strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "baseline")
    path.mkdir(parents=True, exist_ok=True)
    
    # Capture Git Metadata
    with open(path / "git-status.txt", "w") as f:
        f.write(run_cmd(["git", "status"]).stdout)
    
    # Capture Graph/Alignment
    run_cmd(["python3", "Scripts/anigma_package_graph_audit.py", "--output-dir", str(path / "package-graph"), "snapshot"])
    run_cmd(["python3", "Scripts/anigma_package_graph_audit.py", "--output-dir", str(path / "alignment"), "alignment-matrix"])
    
    print(f"Baseline captured: {path}")

def validate(args):
    commit_hash = run_cmd(["git", "rev-parse", "HEAD"]).stdout.strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "validate")
    path.mkdir(parents=True, exist_ok=True)
    
    # Run command and capture
    result = run_cmd(args.command.split())
    with open(path / "command.log", "w") as f:
        f.write(result.stdout)
    
    with open(path / "build-status.json", "w") as f:
        json.dump({"exitCode": result.returncode, "status": "FAILED" if result.returncode != 0 else "PASSED"}, f)
    
    print(f"Validation completed: {path}")

def review(args):
    commit_hash = run_cmd(["git", "rev-parse", "HEAD"]).stdout.strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "review")
    path.mkdir(parents=True, exist_ok=True)
    
    with open(path / "review-bundle.md", "w") as f:
        f.write("# Review Bundle\n\nTask: " + args.task_id)
    
    print(f"Review bundle generated: {path}")

def main():
    parser = argparse.ArgumentParser(description="Master Anigma Diagnostic Harness")
    subparsers = parser.add_subparsers(dest="command")

    # Baseline Parser
    base = subparsers.add_parser("baseline")
    base.add_argument("--task-id", required=True)

    # Validate Parser
    val = subparsers.add_parser("validate")
    val.add_argument("--task-id", required=True)
    val.add_argument("--command", required=True)

    # Review Parser
    rev = subparsers.add_parser("review")
    rev.add_argument("--task-id", required=True)

    args = parser.parse_args()

    if args.command == "baseline":
        baseline(args)
    elif args.command == "validate":
        validate(args)
    elif args.command == "review":
        review(args)

if __name__ == "__main__":
    main()
