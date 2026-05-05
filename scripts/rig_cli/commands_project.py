from __future__ import annotations

import json
import time
import uuid
from pathlib import Path

from rig_tools import architecture_projector


def register(subparsers, helpers):
    parser = subparsers.add_parser("project", help="Architecture projections", description="Generate evidence-backed architecture projection records.")
    proj = parser.add_subparsers(dest="project_cmd", required=True)

    arch = proj.add_parser("architecture", help="Generate architecture projections")
    arch.add_argument("--mode", default="advisory")
    arch.add_argument("--target")
    arch.add_argument("--risk")
    arch.set_defaults(handler=lambda args: _run(helpers, args))

    desired = proj.add_parser("desired-state", help="Generate desired-state summary")
    desired.add_argument("--target", required=True)
    desired.set_defaults(handler=lambda args: _run(helpers, args))

    coupling = proj.add_parser("coupling", help="Generate coupling summary")
    coupling.add_argument("--target", required=True)
    coupling.set_defaults(handler=lambda args: _run(helpers, args))

    overlap = proj.add_parser("overlap", help="Generate overlap summary")
    overlap.add_argument("--target", required=True)
    overlap.set_defaults(handler=lambda args: _run(helpers, args))

    show = proj.add_parser("show", help="Show a projection by id")
    show.add_argument("--projection-id", required=True)
    show.set_defaults(handler=lambda args: _run(helpers, args))


def _run(helpers, args) -> int:
    run_id = uuid.uuid4().hex[:12]
    started_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    emit_events = helpers.output_mode in {"jsonl", "agent"}
    if emit_events:
        helpers._begin_stream(run_id)  # noqa: SLF001
        helpers._emit({"schema_version": "rig.event.v1", "event_type": "run_started", "timestamp_utc": started_at, "run_id": run_id, "command_group": "project", "command": "rig project architecture", "task": getattr(args, "target", None), "attributes": {"milestone": "scan_started"}})
        helpers._emit({"schema_version": "rig.event.v1", "event_type": "step_started", "timestamp_utc": started_at, "run_id": run_id, "command_group": "project", "command": "rig project architecture", "task": getattr(args, "target", None), "attributes": {"milestone": "records_loaded"}})
    bundle = architecture_projector.build_projection_bundle(
        helpers.repo_root,
        target=getattr(args, "target", None),
        mode=getattr(args, "mode", "advisory"),
        risk=getattr(args, "risk", None),
    )
    outputs = architecture_projector.write_projection_outputs(helpers.repo_root, bundle)
    if emit_events:
        artifact_time = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        helpers._emit({"schema_version": "rig.event.v1", "event_type": "artifact", "timestamp_utc": artifact_time, "run_id": run_id, "command_group": "project", "command": "rig project architecture", "task": getattr(args, "target", None), "attributes": {"milestone": "artifact_written", "path": ".build/rig/projections/latest.json", "artifact_type": "result"}})
        helpers._emit({"schema_version": "rig.event.v1", "event_type": "step_finished", "timestamp_utc": artifact_time, "run_id": run_id, "command_group": "project", "command": "rig project architecture", "task": getattr(args, "target", None), "attributes": {"milestone": "projection_rules_applied", "status": bundle["latest"]["status"]}})
        helpers._emit({"schema_version": "rig.event.v1", "event_type": "run_finished", "timestamp_utc": artifact_time, "run_id": run_id, "command_group": "project", "command": "rig project architecture", "task": getattr(args, "target", None), "attributes": {"status": bundle["latest"]["status"], "exit_code": 0, "result_path": ".build/rig/projections/latest.json"}})
        helpers._finish_stream(run_id)  # noqa: SLF001
    payload = {
        "bundle": bundle["latest"],
        "outputs": {key: str(path.relative_to(helpers.repo_root)) for key, path in outputs.items()},
    }
    if helpers.output_mode == "human":
        print(f"projection_count={bundle['latest']['projection_count']} target={getattr(args, 'target', None) or 'all'}")
    elif helpers.output_mode in {"jsonl", "agent"}:
        print(json.dumps(payload, sort_keys=True))
    else:
        print(json.dumps(payload, indent=2, sort_keys=True))
    return 0
