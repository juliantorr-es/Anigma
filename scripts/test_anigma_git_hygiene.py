#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "anigma_git_hygiene.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


class GitHygieneTests(unittest.TestCase):
    def test_status(self):
        res = run("status")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("branch:", res.stdout)

    def test_diff_summary(self):
        res = run("diff-summary", "--task", "td-cleanup-004")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("summary:", res.stdout)

    def test_commit_message(self):
        res = run("commit-message", "--task", "td-cleanup-004")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertTrue(res.stdout.strip())
        self.assertIn("td-cleanup-004:", res.stdout)

    def test_scope_injection(self):
        res = run("scope", "--task", "td-cleanup-004", "--allowed-path", "scripts", "--changed-file", "scripts/example.py")
        self.assertEqual(res.returncode, 0, res.stderr)
        bad = run("scope", "--task", "td-cleanup-004", "--allowed-path", "scripts", "--changed-file", "anigma/SomeFile.swift")
        self.assertNotEqual(bad.returncode, 0)


if __name__ == "__main__":
    unittest.main()
