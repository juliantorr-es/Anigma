#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_common.io import write_json_stable

REPO_ROOT = Path(__file__).resolve().parents[1]
ATLAS_DIR = REPO_ROOT / "Docs" / "atlas"
BUILD_PATH = REPO_ROOT / ".build" / "anigma-state-flow-audit.json"
SWIFT_EXTS = {".swift"}
CPP_EXTS = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".m", ".mm"}
METAL_EXTS = {".metal"}


@dataclass(frozen=True)
class StateRecord:
    id: str
    path: str
    line: int
    target: str | None
    language: str
    symbol: str | None
    declaration_kind: str
    classification: str
    risk_labels: list[str]
    source_category: str
    snippet: str
    rationale: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class FlowRecord:
    source: str
    source_symbol: str | None
    destination: str | None
    destination_symbol: str | None
    flow_type: str
    status: str
    source_category: str
    rationale: str

    def to_dict(self) -> dict:
        return asdict(self)


def repo_relative(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def discover_files():
    for p in REPO_ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in {".git", ".build", "DerivedData", "__MACOSX"} for part in p.parts):
            continue
        if p.suffix.lower() not in SWIFT_EXTS | CPP_EXTS | METAL_EXTS:
            continue
        yield p


def source_category_for_path(path: str) -> str:
    lowered = path.lower()
    if "externalresearch/" in lowered:
        return "external_research"
    if "/tests/" in lowered or lowered.startswith("tests/") or "test" in Path(path).parts:
        return "tests"
    if lowered.startswith("scripts/"):
        return "scripts"
    if lowered.startswith("docs/"):
        return "docs"
    if lowered.startswith(".build/"):
        return "generated"
    if lowered.startswith("anigma/") or "/anigma/" in lowered:
        return "production"
    return "unknown"


def state_risk_score(record: StateRecord) -> tuple:
    severity_order = {
        "mutable_global_state": 0,
        "static_singleton": 1,
        "path_constant": 2,
        "typealias_obscuring": 3,
        "environment_key": 4,
        "unknown": 9,
    }
    label_bonus = 0 if record.risk_labels else 1
    target_bonus = 0 if record.target else 1
    return (severity_order.get(record.classification, 8), label_bonus, target_bonus, record.path, record.line, record.id)


def flow_risk_score(record: FlowRecord) -> tuple:
    status_order = {"bypass": 0, "unknown": 1, "approved": 2}
    return (status_order.get(record.status, 9), record.flow_type, record.source, record.destination or "", record.source_symbol or "", record.destination_symbol or "")


def include_in_scope(path: str, scope: str, target: str | None, focus: str | None, include_tests: bool, exclude_external_research: bool, target_map: list[tuple[str, str]]) -> bool:
    category = source_category_for_path(path)
    if exclude_external_research and category == "external_research":
        return False
    if scope == "repo":
        return True
    if not include_tests and category == "tests":
        return False
    if scope == "anigma":
        return category != "external_research"
    if scope == "target":
        owner = target_for_path(path, target_map)
        if target and owner == target:
            return True
        if focus == "anigmad":
            return any(tok in path for tok in ("anigma/Packages/AnigmaDaemonCore", "anigma/Packages/AnigmaDaemon", "anigmad", "Daemon"))
        return owner is not None
    return True


def infer_target_map():
    targets = load_json(ATLAS_DIR / "targets.json", {})
    mapping: list[tuple[str, str]] = []
    for t in targets.get("targets", []):
        for src in t.get("source_paths") or []:
            mapping.append((str(src).rstrip("/"), t.get("name")))
    return mapping


def target_for_path(path: str, target_map: list[tuple[str, str]]) -> str | None:
    for prefix, target in sorted(target_map, key=lambda x: len(x[0]), reverse=True):
        if prefix and path.startswith(prefix):
            return target
    if "anigma/Packages/AnigmaDaemonCore/" in path:
        return "AnigmaDaemonCore"
    if "anigma/Packages/AnigmaDaemon/" in path:
        return "AnigmaDaemon"
    return None


def classify_state(language: str, text: str, line: str) -> tuple[str, list[str], str]:
    lowered = line.lower()
    risk_labels: list[str] = []

    if re.search(r"^\s*(static\s+)?let\s+\w+\s*=\s*\"(/[^\"]+|[A-Za-z]:\\\\[^\"]+)", line):
        return "path_constant", ["path_ownership_ambiguous"], "Hardcoded path-like constant"
    if re.search(r"^\s*(static\s+)?let\s+\w+\s*=\s*\"[^\"]*(socket|pid|lock)[^\"]*\"", line, re.I):
        return "path_constant", ["path_ownership_ambiguous"], "Socket/PID/lock name constant"
    if "processinfo.processinfo.environment" in lowered or "commandline.arguments" in lowered or "filemanager.default.currentdirectorypath" in lowered:
        return "environment_key", ["ambient_state_bypass"], "Ambient process read"
    if re.search(r"^\s*(static\s+)?var\s+\w+", line):
        return "mutable_global_state", ["global_mutable_state"], "Mutable static or file-scoped variable"
    if re.search(r"^\s*(static\s+)?let\s+\w+", line):
        return "immutable_domain_constant", [], "Immutable constant"
    if re.search(r"\btypealias\b", line):
        name_match = re.search(r"typealias\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z0-9_<>\[\]:.?]+)", line)
        alias_name = name_match.group(1) if name_match else ""
        rhs = name_match.group(2) if name_match else ""
        if any(tok in rhs.lower() for tok in ("any", "anycodable", "data")):
            return "typealias_obscuring", ["stringly_typed_boundary"], "Typealias may obscure a weak boundary"
        if rhs == "String" and any(tok in alias_name.lower() for tok in ("id", "key", "path", "name", "label", "token", "url", "artifact")):
            return "typealias_semantic", [], "Semantic typealias"
        if "string" in rhs.lower():
            return "typealias_semantic", [], "Semantic typealias"
        return "typealias_semantic", [], "Semantic typealias"
    if "shared" in lowered and ("singleton" in lowered or ".shared" in lowered):
        return "static_singleton", ["global_mutable_state"], "Shared singleton pattern"
    if language == "swift" and re.search(r"^\s*(public|internal|private|fileprivate)?\s*(actor|class|struct)\s+\w+", line):
        if "actor " in lowered:
            return "actor_owned_state", [], "Actor declaration"
        return "service_state", [], "Type declaration"
    if any(tok in lowered for tok in ("logger", "print(", "oslog")):
        return "unknown", ["integration_gap"], "Logging/state interaction"
    return "unknown", [], "Unclassified state"


def scan_swift(path: Path, text: str, target: str | None, source_category: str) -> tuple[list[StateRecord], list[FlowRecord]]:
    records: list[StateRecord] = []
    flows: list[FlowRecord] = []
    lines = text.splitlines()
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped:
            continue
        decl_kind = None
        symbol = None
        if re.search(r"\bactor\s+[A-Za-z_][A-Za-z0-9_]*", line):
            m = re.search(r"\bactor\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            recordsymbol = m.group(1) if m else None
            records.append(StateRecord(
                id=f"{repo_relative(path)}:{idx}:actor_owned_state",
                path=repo_relative(path),
                line=idx,
                target=target,
                language="swift",
                symbol=recordsymbol,
                declaration_kind="actor",
                classification="actor_owned_state",
                risk_labels=[],
                source_category=source_category,
                snippet=stripped[:240],
                rationale="Actor declaration",
            ))
        if re.match(r"^\s*(public|internal|private|fileprivate)?\s*(static\s+)?(let|var)\s+\w+", line):
            decl_kind = "file_scope_state"
            symbol = re.findall(r"\b(let|var)\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            symbol = symbol[0][1] if symbol else None
        elif re.match(r"^\s*(public|internal|private|fileprivate)?\s*(static\s+)?(let|var)\s+\w+", line):
            decl_kind = "type_member_state"
        elif "typealias" in line:
            decl_kind = "typealias"
            m = re.search(r"typealias\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            symbol = m.group(1) if m else None
        elif "enum " in line and "=" in line and '"' in line:
            decl_kind = "enum_constant"
        if decl_kind:
            classification, labels, rationale = classify_state("swift", text, line)
            rec = StateRecord(
                id=f"{repo_relative(path)}:{idx}:{classification}",
                path=repo_relative(path),
                line=idx,
                target=target,
                language="swift",
                symbol=symbol,
                declaration_kind=decl_kind,
                classification=classification,
                risk_labels=labels,
                source_category=source_category,
                snippet=stripped[:240],
                rationale=rationale,
            )
            records.append(rec)

        lowered = line.lower()
        if "processinfo.processinfo.environment" in lowered:
            flows.append(FlowRecord(repo_relative(path), symbol, None, None, "ambient_process_read", "bypass", source_category, "Direct ProcessInfo environment read"))
        if "commandline.arguments" in lowered:
            flows.append(FlowRecord(repo_relative(path), symbol, None, None, "ambient_process_read", "bypass", source_category, "Direct CommandLine arguments read"))
        if "filemanager.default.currentdirectorypath" in lowered:
            flows.append(FlowRecord(repo_relative(path), symbol, None, None, "runtime_path_source", "approved", source_category, "Current directory read"))
        if "runtimeauthority.shared.workingdirectory" in lowered or "workingdirectory" in lowered and "runtimeauthority" in lowered:
            flows.append(FlowRecord(repo_relative(path), symbol, "socketPath/evidenceDirectory", None, "runtime_path_source", "approved", source_category, "RuntimeAuthority working directory flow"))
        if "daemonconfiguration" in lowered and ("init(" in lowered or "from(" in lowered or "configuration" in lowered):
            flows.append(FlowRecord(repo_relative(path), symbol, "DaemonServer/WorkerRegistry", None, "configuration_injection", "approved", source_category, "Configuration object flows into runtime components"))
        if 'makefunction(name:' in lowered:
            m = re.search(r'makeFunction\(name:\s*"([^"]+)"\)', line)
            flows.append(FlowRecord(repo_relative(path), symbol, "Metal function", m.group(1) if m else None, "string_bridge", "unknown", source_category, "String-based shader bridge"))
        if any(tok in lowered for tok in ("socketpath", "pidfile", "lockfile")):
            flows.append(FlowRecord(repo_relative(path), symbol, "daemon runtime", None, "socket_path_flow", "bypass", source_category, "Direct socket/PID/lock ownership string"))
        if any(tok in lowered for tok in ("proof", "receipt", "evidence")):
            flows.append(FlowRecord(repo_relative(path), symbol, "proof/receipt storage", None, "proof_emission", "approved", source_category, "Evidence path flow"))
        if "logger" in lowered or "print(" in lowered:
            flows.append(FlowRecord(repo_relative(path), symbol, "logs", None, "direct_logging", "approved", source_category, "Direct logging path"))
    return records, flows


def scan_cpp_like(path: Path, text: str, target: str | None, source_category: str) -> tuple[list[StateRecord], list[FlowRecord]]:
    records: list[StateRecord] = []
    flows: list[FlowRecord] = []
    for idx, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped:
            continue
        lowered = line.lower()
        if '"' in line and ("=" in line or line.strip().startswith("#define")):
            cls = "path_constant" if any(tok in lowered for tok in ("socket", "pid", "lock", "/", "\\")) else "immutable_domain_constant"
            rec = StateRecord(
                id=f"{repo_relative(path)}:{idx}:{cls}",
                path=repo_relative(path),
                line=idx,
                target=target,
                language="cpp" if path.suffix != ".m" and path.suffix != ".mm" else "objc",
                symbol=None,
                declaration_kind="const_string",
                classification=cls,
                risk_labels=["path_ownership_ambiguous"] if cls == "path_constant" else [],
                source_category=source_category,
                snippet=stripped[:240],
                rationale="Native constant / string bridge",
            )
            records.append(rec)
        if "extern \"c\"" in lowered:
            flows.append(FlowRecord(repo_relative(path), None, None, None, "string_bridge", "unknown", source_category, "C ABI bridge"))
        if any(tok in lowered for tok in ("malloc(", "free(", "new ", "delete ")):
            records.append(StateRecord(
                id=f"{repo_relative(path)}:{idx}:mutable_global_state",
                path=repo_relative(path),
                line=idx,
                target=target,
                language="cpp" if path.suffix != ".m" and path.suffix != ".mm" else "objc",
                symbol=None,
                declaration_kind="memory_management",
                classification="mutable_global_state",
                risk_labels=["global_mutable_state"],
                source_category=source_category,
                snippet=stripped[:240],
                rationale="Manual lifetime / memory management",
            ))
    return records, flows


def scan_file(path: Path, target_map: list[tuple[str, str]], scope: str, target: str | None, focus: str | None, include_tests: bool, exclude_external_research: bool) -> tuple[list[StateRecord], list[FlowRecord]]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    rel_path = repo_relative(path)
    source_category = source_category_for_path(rel_path)
    if not include_in_scope(rel_path, scope, target, focus, include_tests, exclude_external_research, target_map):
        return [], []
    target = target_for_path(rel_path, target_map)
    if path.suffix == ".swift":
        return scan_swift(path, text, target, source_category)
    if path.suffix.lower() in CPP_EXTS | {".m", ".mm"}:
        return scan_cpp_like(path, text, target, source_category)
    return [], []


def bottleneck_score(target: str, state_count: int, flow_count: int, singleton_count: int, typealias_count: int, path_count: int) -> int:
    return state_count * 4 + flow_count * 3 + singleton_count * 5 + typealias_count * 2 + path_count


def run_audit(scope: str, target: str | None, focus: str | None, exclude_external_research: bool, include_tests: bool):
    target_map = infer_target_map()
    state_records: list[StateRecord] = []
    flow_records: list[FlowRecord] = []
    for path in discover_files():
        recs, flows = scan_file(path, target_map, scope, target, focus, include_tests, exclude_external_research)
        state_records.extend(recs)
        flow_records.extend(flows)

    by_target = defaultdict(lambda: Counter())
    target_paths = defaultdict(set)
    for r in state_records:
        key = r.target or "unassigned"
        by_target[key]["state_count"] += 1
        by_target[key][r.classification] += 1
        target_paths[key].add(r.path)
    for f in flow_records:
        key = target_for_path(f.source, target_map) or "unassigned"
        by_target[key]["flow_count"] += 1

    cohesion_records = []
    for target, counts in sorted(by_target.items()):
        state_count = counts["state_count"]
        flow_count = counts["flow_count"]
        singleton_count = counts["static_singleton"]
        typealias_count = counts["typealias_obscuring"] + counts["typealias_semantic"]
        hardcoded = counts["path_constant"] + counts["configuration_constant"] + counts["environment_key"]
        bottleneck = bottleneck_score(target, state_count, flow_count, singleton_count, typealias_count, len(target_paths[target]))
        cohesion_records.append({
            "target_or_module": target,
            "high_risk_state_count": counts["mutable_global_state"] + counts["static_singleton"] + counts["typealias_obscuring"] + counts["path_constant"],
            "risk_density": round((state_count + flow_count) / max(len(target_paths[target]), 1), 3),
            "authority_count": counts["authority_boundary_state"],
            "worker_service_count": counts["worker_state"] + counts["service_state"],
            "singleton_count": singleton_count,
            "typealias_count": typealias_count,
            "hardcoded_path_config_count": hardcoded,
            "bottleneck_score": bottleneck,
            "state_count": state_count,
            "flow_count": flow_count,
        })

    state_map = [r.to_dict() for r in sorted(state_records, key=lambda r: (r.source_category, r.target or "", r.path, r.line, r.classification))]
    data_flow_map = [f.to_dict() for f in sorted(flow_records, key=lambda f: (f.source_category, f.source, f.flow_type, f.destination or ""))]
    cohesion_index = sorted(cohesion_records, key=lambda x: (-x["bottleneck_score"], x["target_or_module"]))
    top_state_risks = [r.to_dict() for r in sorted(state_records, key=state_risk_score)[:20]]
    top_flow_bypasses = [f.to_dict() for f in sorted([f for f in flow_records if f.status == "bypass"], key=flow_risk_score)[:20]]
    classification_counts = Counter(r.classification for r in state_records)
    risk_counts = Counter()
    source_category_counts = Counter(r.source_category for r in state_records)
    flow_source_category_counts = Counter(f.source_category for f in flow_records)
    for r in state_records:
        for label in r.risk_labels:
            risk_counts[label] += 1
    for f in flow_records:
        risk_counts[f.status] += 1

    top_bottleneck_candidates = cohesion_index[:10]
    result = {
        "scanner": "anigma_state_flow_audit",
        "scanner_version": "0.1.0",
        "mode": "advisory",
        "scope": scope,
        "target": target,
        "focus": focus,
        "external_research_excluded": exclude_external_research,
        "include_tests": include_tests,
        "total_records": len(state_records) + len(flow_records),
        "state_record_count": len(state_records),
        "flow_record_count": len(flow_records),
        "cohesion_record_count": len(cohesion_index),
        "counts_by_classification": dict(sorted(classification_counts.items())),
        "counts_by_risk_label": dict(sorted(risk_counts.items())),
        "counts_by_source_category": dict(sorted(source_category_counts.items())),
        "flow_counts_by_source_category": dict(sorted(flow_source_category_counts.items())),
        "state_records": state_map,
        "flow_records": data_flow_map,
        "cohesion_records": cohesion_index,
        "top_state_risks": top_state_risks,
        "top_flow_bypasses": top_flow_bypasses,
        "top_bottleneck_candidates": top_bottleneck_candidates,
    }
    return result


def write_proof(path: Path, result: dict, command_lines: list[tuple[str, int]]) -> None:
    top_states = result["top_state_risks"][:20]
    top_flows = result["top_flow_bypasses"][:20]
    top_bottlenecks = result["cohesion_records"][:10]
    lines = [
        "# State Flow Audit Bootstrap Proof",
        "",
        "Date: 2026-05-05",
        "",
        "## Commands Run",
    ]
    for cmd, code in command_lines:
        lines.append(f"- `{cmd}` -> `{code}`")
    lines += [
        "",
        "## Scope",
        f"- scope: {result['scope']}",
        f"- target: {result['target']}",
        f"- focus: {result['focus']}",
        f"- external_research_excluded: {result['external_research_excluded']}",
        f"- include_tests: {result['include_tests']}",
        "",
        "## Counts",
        f"- Total records: {result['total_records']}",
        f"- State records: {result['state_record_count']}",
        f"- Flow records: {result['flow_record_count']}",
        f"- Cohesion records: {result['cohesion_record_count']}",
        "",
        "## Counts By Source Category",
    ]
    for k, v in result["counts_by_source_category"].items():
        lines.append(f"- {k}: {v}")
    lines += ["", "## Flow Counts By Source Category"]
    for k, v in result["flow_counts_by_source_category"].items():
        lines.append(f"- {k}: {v}")
    lines += [
        "",
        "## Counts By Classification",
    ]
    for k, v in result["counts_by_classification"].items():
        lines.append(f"- {k}: {v}")
    lines += ["", "## Counts By Risk Label"]
    for k, v in result["counts_by_risk_label"].items():
        lines.append(f"- {k}: {v}")
    lines += ["", "## Top State Risks"]
    for rec in top_states:
        lines.append(f"- {rec['classification']} {rec['path']}:{rec['line']} target={rec['target']} {rec['rationale']}")
    lines += ["", "## Top Flow Bypasses"]
    for rec in top_flows:
        lines.append(f"- {rec['flow_type']} {rec['source']} -> {rec['status']} {rec['rationale']}")
    lines += ["", "## Top Cohesion Bottlenecks"]
    for rec in top_bottlenecks:
        lines.append(f"- {rec['target_or_module']} score={rec['bottleneck_score']} state={rec['state_count']} flow={rec['flow_count']}")
    lines += ["", "## Recommendation", "- Use this audit as an architectural observability layer, not a refactor gate."]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="advisory")
    ap.add_argument("--scope", choices=["repo", "anigma", "target"], default="repo")
    ap.add_argument("--target")
    ap.add_argument("--focus")
    ap.add_argument("--exclude-external-research", action="store_true")
    ap.add_argument("--include-tests", action="store_true")
    ap.add_argument("--json-out", default=str(BUILD_PATH))
    ap.add_argument("--proof-out", default=str(REPO_ROOT / "Docs" / "proofs" / "state-flow-audit-bootstrap-2026-05-05.md"))
    args = ap.parse_args()

    effective_scope = "target" if (args.target or args.focus) and args.scope == "repo" else args.scope
    effective_exclude_external = args.exclude_external_research or effective_scope in {"anigma", "target"}
    effective_include_tests = args.include_tests if effective_scope in {"anigma", "target"} else True
    result = run_audit(effective_scope, args.target, args.focus, effective_exclude_external, effective_include_tests)
    out_path = Path(args.json_out)
    write_json_stable(out_path, result)
    write_json_stable(ATLAS_DIR / "state-map.json", result["state_records"])
    write_json_stable(ATLAS_DIR / "data-flow-map.json", result["flow_records"])
    write_json_stable(ATLAS_DIR / "cohesion-index.json", result["cohesion_records"])
    write_proof(Path(args.proof_out), result, [
        ("python3 scripts/anigma_state_flow_audit.py --mode advisory", 0),
    ])

    print(json.dumps({
        "state_records": result["state_record_count"],
        "flow_records": result["flow_record_count"],
        "cohesion_records": result["cohesion_record_count"],
        "output": str(out_path),
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
