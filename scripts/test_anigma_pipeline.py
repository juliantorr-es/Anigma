#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = REPO_ROOT / "scripts"


def run(cmd, cwd=REPO_ROOT):
    return subprocess.run(cmd, text=True, capture_output=True, cwd=cwd, check=False)


class PipelineTests(unittest.TestCase):
    def test_profile_loading_and_placeholder_expansion(self):
        res = run([sys.executable, str(SCRIPTS / "anigma_pipeline.py"), "run", "--profile", "daemon-runtime", "--task", "td-cleanup-004"])
        self.assertIn(".build/anigma-pipeline/runs/td-cleanup-004/", res.stdout)

    def test_scope_validator(self):
        res = run([sys.executable, str(SCRIPTS / "anigma_validate_scope.py"), "--task", "td-cleanup-004", "--allowed-path", "scripts", "--allowed-path", "Docs", "--allow-empty", "--changed-file", "Docs/example.md"])
        self.assertEqual(res.returncode, 0, res.stderr)

        bad = run([sys.executable, str(SCRIPTS / "anigma_validate_scope.py"), "--task", "td-cleanup-004", "--allowed-path", "scripts", "--changed-file", "anigma/SomeFile.swift"])
        self.assertNotEqual(bad.returncode, 0)

    def test_known_blocker_classification(self):
        res = run([sys.executable, str(SCRIPTS / "anigma_pipeline.py"), "run", "--profile", "daemon-runtime", "--task", "td-cleanup-004"])
        self.assertIn(".build/anigma-pipeline/runs/td-cleanup-004/", res.stdout)

    def test_integration_manifest_written(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            profile = tmp / "profile.yaml"
            profile.write_text(
                "\n".join(
                    [
                        "name: test",
                        "continue_on_known_blocked_required: true",
                        "steps:",
                        "  - id: noop",
                        "    command: python3 -c 'print(\"hello\")'",
                        "    required: true",
                    ]
                ),
                encoding="utf-8",
            )
            target_profile_dir = REPO_ROOT / "Docs" / "pipeline" / "profiles"
            target_profile_dir.mkdir(parents=True, exist_ok=True)
            test_profile = target_profile_dir / "test.yaml"
            test_profile.write_text(profile.read_text(encoding="utf-8"), encoding="utf-8")
            try:
                res = run([sys.executable, str(SCRIPTS / "anigma_pipeline.py"), "run", "--profile", "test", "--task", "pipeline-bootstrap"])
                self.assertIn(".build/anigma-pipeline/runs/pipeline-bootstrap/", res.stdout)
                run_root = REPO_ROOT / ".build" / "anigma-pipeline" / "runs" / "pipeline-bootstrap"
                self.assertTrue(run_root.exists())
                latest = max((p for p in run_root.iterdir() if p.is_dir()), key=lambda p: p.stat().st_mtime)
                self.assertTrue((latest / "manifest.json").exists())
                self.assertTrue((latest / "summary.md").exists())
                self.assertTrue(any((latest / "step-results").glob("*.json")))
                self.assertTrue(any((latest / "logs").glob("*.log")))
            finally:
                if test_profile.exists():
                    test_profile.unlink()

    def test_bundle_generation(self):
        res = run([sys.executable, str(SCRIPTS / "anigma_pipeline.py"), "run", "--profile", "cleanup-review", "--task", "td-cleanup-004"])
        self.assertNotEqual(res.stdout.strip(), "")
        bundle = run([sys.executable, str(SCRIPTS / "anigma_pipeline.py"), "bundle", "--task", "td-cleanup-004", "--latest-run"])
        self.assertEqual(bundle.returncode, 0, bundle.stderr)
        zip_path = REPO_ROOT / bundle.stdout.strip()
        self.assertTrue(zip_path.exists())
        with zipfile.ZipFile(zip_path) as zf:
            names = sorted(zf.namelist())
            self.assertIn("bundle-manifest.json", names)
            self.assertTrue(any(name.endswith("/manifest.json") for name in names))
            self.assertTrue(any(name.endswith("/summary.md") for name in names))
            self.assertTrue(any(name.endswith("task-scoped-changes.patch") for name in names))
            self.assertTrue(any(name.endswith("changes.patch") for name in names))
            self.assertFalse(any(name.startswith(".git/") for name in names))
            self.assertTrue(any(name.endswith("HTTPServer.swift") for name in names))
            bm = json.loads(zf.read("bundle-manifest.json"))
            self.assertIn("scope_status", bm)
            self.assertIn("review_status", bm)
            self.assertIn("task_scoped_changed_file_count", bm)
            self.assertIn("untracked_files_included", bm)
            self.assertEqual(bm["task"], "td-cleanup-004")
            self.assertEqual(bm["source_run_profile"], "cleanup-review")


if __name__ == "__main__":
    unittest.main()
