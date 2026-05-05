#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "rig.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def main() -> int:
    snap = run("monitor", "snapshot")
    assert snap.returncode == 0, snap.stderr
    state = json.loads((REPO_ROOT / ".build" / "rig" / "monitor" / "state.json").read_text(encoding="utf-8"))
    assert state["schema_version"] == "rig.monitor_state.v1"
    assert isinstance(state["runs"], list)
    assert isinstance(state["tasks"], list)
    assert isinstance(state["latest_events"], list)

    runs = run("monitor", "runs")
    assert runs.returncode == 0, runs.stderr

    tasks = run("monitor", "tasks")
    assert tasks.returncode == 0, tasks.stderr

    tail = run("monitor", "tail", "--run-id", "latest")
    assert tail.returncode == 0, tail.stderr

    html = (REPO_ROOT / ".build" / "rig" / "monitor" / "index.html").read_text(encoding="utf-8")
    assert "http://" not in html and "https://" not in html

    missing = run("monitor", "tui")
    assert missing.returncode == 0, missing.stderr
    assert "tool_missing" in missing.stdout or "step_skipped" in missing.stdout
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
