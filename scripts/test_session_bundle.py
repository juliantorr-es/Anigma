#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

from rig_tools import schema_validation, session_bundle


REPO_ROOT = Path(__file__).resolve().parents[1]
SESSION_DIR = REPO_ROOT / "Session-bundles"


def run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(REPO_ROOT / "scripts" / "rig.py"), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def test_default_output_directory() -> None:
    assert session_bundle._default_bundle_dir(REPO_ROOT) == SESSION_DIR


def test_excludes_and_zipinfo_are_deterministic() -> None:
    assert session_bundle._should_exclude(".DS_Store")
    assert session_bundle._should_exclude("foo/__pycache__/bar.pyc")
    assert session_bundle._should_exclude(".git/config")
    assert session_bundle._should_exclude("foo.pyc")
    assert session_bundle._should_exclude("__MACOSX/foo")
    info = session_bundle._zipinfo("README.md")
    assert info.date_time == (1980, 1, 1, 0, 0, 0)


def test_dry_run_writes_manifest_and_summary_only() -> None:
    result = session_bundle.write_bundle(REPO_ROOT, task="rig-session-review-bundle-bootstrap", latest_run=True, dry_run=True, overwrite=True)
    assert result.bundle_path is None
    assert result.manifest_path.exists()
    assert result.summary_path.exists()
    manifest = json.loads(result.manifest_path.read_text(encoding="utf-8"))
    assert manifest["schema_version"] == "rig.session_review_bundle.v1"
    assert manifest["sha256"] is None
    assert manifest["bundle_path"] == "Session-bundles/rig-session-review-bundle-bootstrap-session-review.zip"


def test_full_bundle_contains_expected_top_level_files() -> None:
    result = session_bundle.write_bundle(REPO_ROOT, task="rig-session-review-bundle-bootstrap", latest_run=True, dry_run=False, overwrite=True)
    assert result.bundle_path and result.bundle_path.exists()
    assert result.bundle_path.parent == SESSION_DIR
    with zipfile.ZipFile(result.bundle_path) as zf:
        names = zf.namelist()
        assert names == sorted(names)
        assert "README.md" in names
        assert "summary.md" in names
        assert "bundle-manifest.json" in names
        assert not any(name.startswith("/") or ":" in name for name in names)
        assert not any(name.startswith(".git/") for name in names)
        assert not any("__pycache__" in name for name in names)
        assert not any(name.endswith(".pyc") for name in names)
        assert not any(name.endswith(".DS_Store") for name in names)
    manifest = json.loads(result.manifest_path.read_text(encoding="utf-8"))
    assert manifest["sha256"]
    assert manifest["size_bytes"] > 0
    assert result.manifest["bundle_path"] == str(result.bundle_path.relative_to(REPO_ROOT)).replace("\\", "/")


def test_modified_file_copies_and_untracked_manifest_are_recorded() -> None:
    result = session_bundle.write_bundle(REPO_ROOT, task="rig-session-review-bundle-bootstrap", latest_run=True, dry_run=False, include_untracked=True, overwrite=True)
    manifest = json.loads(result.manifest_path.read_text(encoding="utf-8"))
    assert isinstance(manifest["modified_files_included"], list)
    assert "patches/untracked-files-manifest.json" in manifest["patches"]
    assert any(path.startswith("modified-files/") for path in manifest["included_files"])


def test_schema_validation_passes_for_manifest() -> None:
    result = session_bundle.write_bundle(REPO_ROOT, task="rig-session-review-bundle-bootstrap", latest_run=True, dry_run=False, overwrite=True)
    validation = schema_validation.validate_artifacts(REPO_ROOT, artifact_path=str(result.manifest_path.relative_to(REPO_ROOT)))
    assert validation.status == "passed", validation.to_dict()


def test_bundle_listing_command_exists() -> None:
    proc = run_cli("bundle", "sessions")
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["bundle_dir"] == "Session-bundles"
    assert isinstance(payload["bundles"], list)


def main() -> int:
    test_default_output_directory()
    test_excludes_and_zipinfo_are_deterministic()
    test_dry_run_writes_manifest_and_summary_only()
    test_full_bundle_contains_expected_top_level_files()
    test_modified_file_copies_and_untracked_manifest_are_recorded()
    test_schema_validation_passes_for_manifest()
    test_bundle_listing_command_exists()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
