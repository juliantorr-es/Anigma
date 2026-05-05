#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from pathlib import Path

from rig_tools.cache_metadata import build_cache_key, record_metadata

REPO_ROOT = Path(__file__).resolve().parents[1]
TMP = REPO_ROOT / ".build" / "rig" / "cache-metadata"


def main() -> int:
    shutil.rmtree(TMP, ignore_errors=True)
    sample = REPO_ROOT / "scripts" / "rig.py"
    out = record_metadata(
        REPO_ROOT,
        artifact_id="atlas-build",
        producer="anigma_build_repo_atlas",
        command="python3 scripts/anigma_build_repo_atlas.py",
        input_paths=[sample],
        output_paths=[sample],
        duration_seconds=1.23,
    )
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["schema_version"] == "rig.cache-metadata.v1"
    assert payload["status"] == "fresh"
    assert payload["input_files"][0]["path"] == "scripts/rig.py"
    assert payload["output_files"][0]["path"] == "scripts/rig.py"
    key1 = build_cache_key("cmd", [{"path": "a", "sha256": "1"}], {"python_version": "3"})
    key2 = build_cache_key("cmd", [{"path": "a", "sha256": "1"}], {"python_version": "3"})
    key3 = build_cache_key("cmd", [{"path": "a", "sha256": "2"}], {"python_version": "3"})
    assert key1 == key2
    assert key1 != key3
    assert payload["cache_key"]
    assert payload["environment_fingerprint"]["python_version"]
    missing = record_metadata(
        REPO_ROOT,
        artifact_id="state-flow-audit",
        producer="anigma_state_flow_audit",
        command="python3 scripts/anigma_state_flow_audit.py",
        input_paths=[sample],
        output_paths=[REPO_ROOT / ".build" / "does-not-exist.json"],
        duration_seconds=2.0,
    )
    missing_payload = json.loads(missing.read_text(encoding="utf-8"))
    assert missing_payload["status"] == "missing_outputs"
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
