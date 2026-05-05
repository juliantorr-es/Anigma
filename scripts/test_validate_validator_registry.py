#!/usr/bin/env python3
"""Smoke tests for validate_validator_registry.py."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "Scripts" / "validate_validator_registry.py"
REGISTRY = REPO_ROOT / "Docs" / "governance" / "validator-registry.yaml"


def run(cmd, cwd=REPO_ROOT):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)


def test_valid_registry_passes():
    res = run(["python3", str(SCRIPT), "--registry", str(REGISTRY)])
    assert res.returncode == 0, res.stdout


def test_missing_path_fails():
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        bad_registry = tmp_path / "bad.yaml"
        data = yaml.safe_load(REGISTRY.read_text())
        data["validators"] = [dict(data["validators"][0], path="Scripts/does_not_exist.py")]
        bad_registry.write_text(yaml.safe_dump(data, sort_keys=False))
        res = run(["python3", str(SCRIPT), "--registry", str(bad_registry)])
        assert res.returncode == 1
        assert "registered path does not exist" in res.stdout


def test_mutating_validator_without_check_metadata_fails():
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        bad_registry = tmp_path / "bad.yaml"
        data = yaml.safe_load(REGISTRY.read_text())
        entry = dict(data["validators"][0])
        entry["authority_class"] = "mutator_migration_script"
        entry["phases"] = ["validate"]
        entry["mutates"] = True
        entry["baseline_behavior"] = "writes baseline"
        entry["dangerous_modes"] = []
        data["validators"] = [entry]
        bad_registry.write_text(yaml.safe_dump(data, sort_keys=False))
        res = run(["python3", str(SCRIPT), "--registry", str(bad_registry)])
        assert res.returncode == 1
        assert "baseline-writing behavior requires an explicit dangerous mode" in res.stdout


def test_json_output_parses():
    res = run(["python3", str(SCRIPT), "--check", "--format", "json", "--registry", str(REGISTRY)])
    payload = json.loads(res.stdout)
    assert "status" in payload
    assert "violations" in payload


if __name__ == "__main__":
    test_valid_registry_passes()
    test_missing_path_fails()
    test_mutating_validator_without_check_metadata_fails()
    test_json_output_parses()
    print("validate_validator_registry tests passed")
