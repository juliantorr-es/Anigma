#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_common.io import write_json_stable

REPO_ROOT = Path(__file__).resolve().parents[1]
ATLAS = REPO_ROOT / "Docs" / "atlas"
TEMPLATES = REPO_ROOT / "scripts" / "task_brief_templates"

def load(name):
    p = ATLAS / name
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []

def tokset(s):
    return set(re.findall(r"[A-Za-z0-9_]+", s.lower()))

def rank_key(f):
    sev = {"critical":0,"high":1,"medium":2,"low":3,"info":4}.get(f.get("severity"), 9)
    conf = {"high_confidence":0,"medium_confidence":1,"low_confidence":2,"heuristic":3}.get(f.get("confidence"), 9)
    return (sev, conf, f.get("target") or "", f.get("category") or "", f.get("path") or "", f.get("line") or 0, f.get("finding_id") or "")

def select_findings(risk, target, limit, query):
    risks = load("risk-index.json")
    qt = tokset(query or "")
    out = []
    for r in risks:
        if risk and r.get("category") != risk:
            continue
        if target and r.get("target") != target and target not in json.dumps(r):
            continue
        if qt and not (qt & tokset(json.dumps(r))):
            continue
        out.append(r)
    out.sort(key=rank_key)
    return out[:limit]

def render(template_text, mapping):
    for k,v in mapping.items():
        template_text = template_text.replace(f"{{{{{k}}}}}", v)
    return template_text

def find_unreplaced_placeholders(text: str) -> list[str]:
    return sorted(set(re.findall(r"\{\{[^{}]+\}\}", text)))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-templates", action="store_true")
    ap.add_argument("--task", required=False)
    ap.add_argument("--template", default="cleanup_executable_consolidation")
    ap.add_argument("--risk")
    ap.add_argument("--target")
    ap.add_argument("--query")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--format", choices=["markdown","json"], default="markdown")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--write")
    args = ap.parse_args()

    if args.list_templates:
        for p in sorted(TEMPLATES.glob("*.md")):
            print(p.stem)
        return 0

    template_path = TEMPLATES / f"{args.template}.md"
    if not template_path.exists():
        print(f"Missing template: {template_path}", file=sys.stderr)
        return 2

    findings = select_findings(args.risk, args.target, args.limit, args.query)
    query_risk = args.risk or ""
    if args.template == "cleanup_singleton_triage":
        query_risk = "singleton_global_state"
    selected_lines = []
    change_map_lines = []
    for i,f in enumerate(findings, 1):
        selected_lines.append(
            f"{i}. {f.get('finding_id')} | {f.get('rule_id')} | {f.get('severity')} | {f.get('confidence')} | {f.get('path')}:{f.get('line')} | target={f.get('target')} | symbol={f.get('symbol')} | snippet={f.get('snippet') or ''} | rationale={f.get('rationale') or f.get('reason') or ''}"
        )
        change_map_lines.append(
            f"{i}. {f.get('path')}\n   current assumption/risk: {f.get('rationale') or f.get('reason') or f.get('category')}\n   desired alignment: route {f.get('category')} through daemon-owned boundary\n   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership\n   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json\n   expected audit effect: reduce or eliminate this finding"
        )
    mapping = {
        "title": f"Implement {args.task or 'task'}: {args.template}",
        "task_id": args.task or "",
        "source_of_truth": "- Docs/atlas/risk-index.json\n- Docs/atlas/targets.json\n- Docs/atlas/entrypoints.json\n- Docs/atlas/authority-map.json\n- Docs/governance/CLEANUP_ALIGNMENT_DOCTRINE.md\n- Docs/proofs/td-cleanup-002-batch-001-post-review.md\n- Docs/proofs/td-cleanup-003-batch-002-process-configuration-alignment.md\n- Docs/proofs/context-pipeline-audit-normalization-2026-05-05.md",
        "context_summary": f"Selected {len(findings)} focused risks for risk={args.risk!r} target={args.target!r}.",
        "selected_findings": "\n".join(selected_lines) if selected_lines else "None.",
        "change_map": "\n".join(change_map_lines) if change_map_lines else "None.",
        "proposed_change_map": "\n".join(change_map_lines) if change_map_lines else "None.",
        "non_goals": "- Do not modify unrelated runtime code.\n- Do not refresh baselines unless explicitly justified.\n- Do not suppress findings instead of repairing them.\n- Do not treat scanner findings as automatic bugs.",
        "approved_repair_shapes": "- Route socket/listener ownership through a daemon IPC authority or lifecycle owner.\n- Replace hard-coded socket paths, PID files, or lock files with injected/runtime-owned configuration.\n- Keep bind/listen lifecycle explicit and testable.\n- Preserve existing behavior.\n- Use typed errors for bind/listen failures.\n- Keep process exit/shutdown behavior at top-level boundaries only.",
        "implementation_sequence": "1. Inspect each selected source file.\n2. Classify findings.\n3. Repair confirmed/likely risks only.\n4. Re-run executable-consolidation audit.\n5. Rebuild atlas.\n6. Verify query output and gate state.",
        "validation_commands": (
            "- python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json\n"
            "- python3 scripts/anigma_executable_consolidation_audit.py --mode gate --baseline Docs/baselines/executable-consolidation-baseline.json --focus anigmad\n"
            "- python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json\n"
            "- python3 scripts/anigma_build_repo_atlas.py\n"
            f"- python3 scripts/anigma_context_query.py --risk {query_risk or 'daemon_ipc_binding'} --target AnigmaDaemonCore --limit 10\n"
            "- swift build --target AnigmaDaemonCore\n"
            "- python3 scripts/anigma_diagnose.py validate --task-id td-cleanup-004 --command true"
        ),
        "proof_requirements": "- Document selected finding statuses.\n- Document audit deltas.\n- Document build/test results.\n- Note whether production Swift changed.",
        "acceptance_criteria": "- No production Swift/C++/Metal source changed.\n- Query remains focused.\n- Repair scope limited to confirmed/likely risks.\n- Proof artifact exists.",
        "final_report_format": "- files modified\n- each selected finding status\n- audit deltas\n- build/test results\n- remaining daemon_ipc_binding findings\n- whether production Swift changed",
    }
    template_text = template_path.read_text(encoding="utf-8")
    output = render(template_text, mapping)
    placeholders = find_unreplaced_placeholders(output)
    if placeholders:
        print(f"Unreplaced placeholders in generated brief: {', '.join(placeholders)}", file=sys.stderr)
        return 3
    if args.format == "json":
        print(json.dumps({"task": args.task, "template": args.template, "selected_count": len(findings), "findings": findings, "brief": output}, indent=2, sort_keys=True))
    else:
        print(output)
    if args.write and not args.dry_run:
        out = Path(args.write)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(output, encoding="utf-8")
    if args.dry_run:
        print(output)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
