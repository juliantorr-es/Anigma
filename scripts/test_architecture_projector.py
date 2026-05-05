#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import json
import subprocess
import sys
from pathlib import Path

from rig_tools import architecture_projector


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "Docs" / "atlas").mkdir(parents=True, exist_ok=True)
        write(root / "Docs" / "atlas" / "targets.json", '{"targets":[{"name":"RuntimeAuthority"},{"name":"AnigmaDaemonCore"}]}\n')
        write(root / "Docs" / "atlas" / "risk-index.json", '{"risks":[{"target":"RuntimeAuthority"},{"target":"AnigmaDaemonCore"}]}\n')
        write(root / "Docs" / "atlas" / "state-map.json", '{"records":[{"target":"RuntimeAuthority"}]}\n')
        write(root / "Docs" / "atlas" / "data-flow-map.json", '{"flows":[{"target":"AnigmaDaemonCore","path":"foo"}]}\n')
        write(root / "Docs" / "atlas" / "cohesion-index.json", '{"records":[{"target":"RuntimeAuthority"}]}\n')
        write(root / "Docs" / "atlas" / "repo-map.json", '{"targets":[{"name":"AnigmaDaemonCore"}]}\n')
        write(root / "Docs" / "indexes" / "rig-swift-diagnostics-index.json", '[{"target":"AnigmaDaemonCore"}]\n')
        write(root / "Docs" / "indexes" / "rig-affected-index.json", '[{"directly_affected_targets":"AnigmaDaemonCore"}]\n')
        write(root / "anigma" / "RuntimeAuthority.swift", "import Foundation\nfinal class RuntimeAuthority { static let shared = RuntimeAuthority(); func f(){ exit(1) } }\n")
        write(root / "anigma" / "DaemonServer.swift", "let env = ProcessInfo.processInfo.environment\nlet socketPath = \"/tmp/anigma.sock\"\n")

        bundle = architecture_projector.build_projection_bundle(root, target="RuntimeAuthority")
        assert bundle["projections"][0]["kind"] in {"move_lifecycle_to_daemon_owner", "extract_authority", "replace_global_state_with_actor", "defer_no_change"}
        assert bundle["projections"][0]["projection_id"].startswith("projection.RuntimeAuthority.")
        out = architecture_projector.write_projection_outputs(root, bundle)
        assert out["Docs/atlas/architecture-projections.json"].exists()
        assert out["Docs/atlas/coupling-index.json"].exists()
        assert out[".build/rig/projections/latest.json"].exists()

        kind = architecture_projector._projection_kind({"shutdown_and_exit"})
        assert kind == "move_lifecycle_to_daemon_owner"
        kind = architecture_projector._projection_kind({"ambient_process_read"})
        assert kind == "move_config_to_configuration_boundary"
        kind = architecture_projector._projection_kind({"daemon_ipc_binding"})
        assert kind == "extract_authority"
        kind = architecture_projector._projection_kind({"singleton_global_state"})
        assert kind == "replace_global_state_with_actor"

        coupling = architecture_projector._coupling_record(root, "RuntimeAuthority")
        assert coupling["schema_version"] == "rig.coupling_index.v1"
        assert "coupling_score" in coupling

        overlaps = architecture_projector._overlap_records(root, "RuntimeAuthority")
        assert overlaps

    repo = Path(__file__).resolve().parents[1]
    script = repo / "scripts" / "rig.py"
    json_result = subprocess.run([sys.executable, str(script), "--json", "project", "architecture", "--target", "AnigmaDaemonCore"], cwd=repo, text=True, capture_output=True, check=False)
    assert json_result.returncode == 0, json_result.stderr
    assert "run_started" not in json_result.stdout
    assert "projection_count" in json_result.stdout

    jsonl_result = subprocess.run([sys.executable, str(script), "--jsonl", "project", "architecture", "--target", "AnigmaDaemonCore"], cwd=repo, text=True, capture_output=True, check=False)
    assert jsonl_result.returncode == 0, jsonl_result.stderr
    lines = [line for line in jsonl_result.stdout.splitlines() if line.strip()]
    assert any(json.loads(line)["event_type"] == "run_started" for line in lines[:-1])
    assert any(json.loads(line)["event_type"] == "run_finished" for line in lines[:-1])
    assert json.loads(lines[-1])["bundle"]["projection_count"] >= 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
