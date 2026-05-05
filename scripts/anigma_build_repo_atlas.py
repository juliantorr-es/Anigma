#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_common.io import write_json_stable
from scripts.anigma_common.findings import stable_finding_id
from scripts.anigma_common.package_graph import discover_package_roots, describe_package, parse_package_swift
from scripts.atlas.swift_indexer import index as swift_index
from scripts.atlas.cpp_indexer import index as cpp_index
from scripts.atlas.metal_indexer import index as metal_index
from scripts.atlas.script_indexer import index as script_index
from scripts.atlas.manifest_indexer import index as manifest_index

REPO_ROOT = Path(subprocess.check_output(["git","rev-parse","--show-toplevel"], text=True).strip())
ATLAS_DIR = REPO_ROOT/"Docs"/"atlas"
BUILD_DIR = REPO_ROOT/".build"/"anigma-repo-atlas"
IGNORE = {".build","DerivedData",".git","__MACOSX","ExternalResearch"}

def rel(p): return str(p.relative_to(REPO_ROOT))
def sha(text: bytes): return hashlib.sha256(text).hexdigest()
def is_ignored(p: Path): return any(part in IGNORE for part in p.parts) or p.name == ".DS_Store"
def detect_lang(p: Path):
    if p.suffix == ".swift": return "swift"
    if p.suffix in {".c",".h",".cc",".cpp",".cxx",".hpp",".m",".mm"}: return "cpp" if p.suffix in {".c",".h",".cc",".cpp",".cxx",".hpp"} else "objc"
    if p.suffix == ".metal": return "metal"
    if p.suffix in {".py",".sh",".zsh",".bash"}: return "script"
    if p.name == "Package.swift" or p.suffix in {".json",".yaml",".yml",".md"}: return "manifest"
    return "other"

def iter_files():
    for root, dirs, files in os.walk(REPO_ROOT):
        rootp = Path(root)
        dirs[:] = [d for d in dirs if d not in IGNORE]
        if is_ignored(rootp): continue
        for n in files:
            p = rootp/n
            if is_ignored(p): continue
            yield p

def build():
    repo_map=[]; symbols=[]; deps={"swift_imports":{},"native_includes":{},"metal_includes":{},"script_invocations":{},"target_graph":[]}; entries=[]; auth=[]; native=[]; shaders=[]; bridges=[]; risks=[]; targets={"products":[],"targets":[]}; file_hashes={}
    package_info = None
    for root in discover_package_roots(REPO_ROOT):
        package_info = describe_package(root)
        if package_info:
            break
    file_hashes={}
    text_cache={}
    for p in iter_files():
        try: data=p.read_bytes()
        except OSError: continue
        text=data.decode("utf-8","ignore"); text_cache[rel(p)] = text
        language=detect_lang(p)
        file_hashes[rel(p)] = sha(data)
        repo_map.append({"path":rel(p),"language":language,"file_type":p.suffix.lstrip(".") or p.name,"source_category":"source","module":None,"line_count":text.count("\n")+1 if text else 0,"sha256":file_hashes[rel(p)],"generated":False,"excluded":False})
        if language=="swift":
            out=swift_index(rel(p), text); deps["swift_imports"][rel(p)] = out["imports"]; symbols += [s.to_dict() for s in out["symbols"]]
            if p.name=="main.swift" or "@main" in text: entries.append({"path":rel(p),"language":"swift","kind":"main.swift" if p.name=="main.swift" else "@main"})
        elif language in {"cpp","objc"}:
            out=cpp_index(rel(p), text); deps["native_includes"][rel(p)] = out["imports"]; symbols += [s.to_dict() for s in out["symbols"]]
            native.append({"file":rel(p),"language":language,"native_dependencies":sorted({x.split("/")[0] for x in out["imports"] if x}),"entrypoints":["main"] if "main(" in text else [],"ffi_exports":["extern C"] if 'extern "C"' in text else [],"risk_tags":out["risk_tags"]})
            if "main(" in text: entries.append({"path":rel(p),"language":language,"kind":"main"})
        elif language=="metal":
            out=metal_index(rel(p), text); deps["metal_includes"][rel(p)] = out["imports"]; symbols += [s.to_dict() for s in out["symbols"]]
            shaders.append({"file":rel(p),"language":"metal","functions":[s for s in [s.to_dict() for s in out["symbols"]] if s["kind"].endswith("_function")],"risk_tags":out["risk_tags"]})
        elif language=="script":
            out=script_index(rel(p), text); symbols += [s.to_dict() for s in out["symbols"]]
            deps["script_invocations"][rel(p)] = re.findall(r'\b(?:swift|python3?|xcodebuild|git|rg|make)\b', text)
            if out["symbols"]: entries.append({"path":rel(p),"language":"script","kind":"script"})
        elif language=="manifest":
            out=manifest_index(rel(p), text)
            if p.name=="Package.swift":
                targets["targets"] += [{"name":t,"kind":"target"} for t in out["targets"]]
                targets["products"] += [{"name":pr,"kind":"product"} for pr in out["products"]]
        if any(n in p.name for n in ("Authority","Executor","Registry","Service","Kernel","Worker")) or any(n in rel(p) for n in ("/Authority","/Executor","/Registry","/Service","/Kernel","/Worker")):
            auth.append({"path":rel(p),"language":language,"name":p.stem,"responsibility":None})
    # Import audit findings as first-class risks.
    imported_dead_code_candidates = 0
    imported_executable_findings = 0
    skipped_non_actionable_dead_code_records = 0
    for audit_path in [REPO_ROOT / ".build" / "anigma-dead-code-audit.json", REPO_ROOT / ".build" / "anigma-executable-consolidation-audit.json"]:
        if not audit_path.exists():
            continue
        try:
            audit = json.loads(audit_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        scanner = audit.get("scanner") or ""
        for finding in audit.get("findings", []):
            path = finding.get("path") or finding.get("file")
            if not path:
                continue
            if scanner == "anigma_dead_code_audit":
                cls = finding.get("classification") or finding.get("category") or ""
                if cls not in {"candidate_dead", "high_confidence_candidate", "medium_confidence_candidate"}:
                    skipped_non_actionable_dead_code_records += 1
                    continue
                imported_dead_code_candidates += 1
            elif scanner == "anigma_executable_consolidation_audit":
                imported_executable_findings += 1
            risks.append({
                "risk_id": stable_finding_id({
                    "source": finding.get("source") or audit.get("scanner"),
                    "finding_id": finding.get("finding_id") or finding.get("id"),
                    "path": path,
                    "line": finding.get("line"),
                    "category": finding.get("category") or finding.get("classification") or finding.get("rule_id"),
                }),
                "source": finding.get("source") or audit.get("scanner") or "audit",
                "finding_id": finding.get("finding_id") or finding.get("id"),
                "scanner_name": finding.get("scanner_name") or audit.get("scanner"),
                "scanner_version": finding.get("scanner_version") or audit.get("scanner_version"),
                "rules_version": finding.get("rules_version") or audit.get("rules_version"),
                "rule_id": finding.get("rule_id") or finding.get("classification"),
                "rule_version": finding.get("rule_version"),
                "category": finding.get("category") or finding.get("classification") or finding.get("rule_id"),
                "severity": finding.get("severity"),
                "confidence": finding.get("confidence"),
                "path": path,
                "line": finding.get("line"),
                "symbol": finding.get("symbol"),
                "target": finding.get("target"),
                "language": finding.get("language"),
                "baseline_status": finding.get("baseline_status"),
                "related_symbols": [finding.get("symbol")] if finding.get("symbol") else [],
                "related_entrypoints": [finding.get("entrypoint")] if finding.get("entrypoint") else [],
                "status": "open",
                "baseline_key": finding.get("baseline_key"),
                "rationale": finding.get("rationale") or finding.get("reason"),
            })
    # simple bridge detection
    for path, text in text_cache.items():
        for m in re.finditer(r'makeFunction\(name:\s*"([^"]+)"\)', text):
            bridges.append({"swift_file": path, "native_file": None, "bridge_type": "metal_pipeline_function", "symbol": m.group(1), "risk": "shader name string reference must match .metal function"})
    risks.extend([{"path":x["file"] if "file" in x else x.get("path"),"category":"metal_kernel_string_reference","severity":"medium","confidence":"heuristic","source":"atlas_inference","risk_id":stable_finding_id({"path":x["file"],"category":"metal_kernel_string_reference"})} for x in shaders for _ in x.get("functions",[]) if x.get("functions")])
    for relp,text in text_cache.items():
        if any(tok in text for tok in ("malloc(","free(","new ","delete ","extern \"C\"")) and relp.endswith((".c",".h",".cc",".cpp",".cxx",".hpp",".m",".mm")):
            risks.append({"path":relp,"category":"cpp_raw_pointer","severity":"medium","confidence":"heuristic","source":"atlas_inference","risk_id":stable_finding_id({"path":relp,"category":"cpp_raw_pointer"})})
    if package_info:
        targets["targets"] = [{"name":t.get("name"),"kind":t.get("type"),"source_paths":t.get("path")} for t in package_info.get("targets",[])]
        targets["products"] = [{"name":p.get("name"),"kind":p.get("type"),"targets":p.get("targets",[])} for p in package_info.get("products",[])]
    elif (REPO_ROOT/"anigma"/"Package.swift").exists():
        pkg=parse_package_swift(REPO_ROOT/"anigma"/"Package.swift")
        targets["targets"]=[{"name":t["name"],"kind":"target"} for t in pkg["targets"]]
        targets["products"]=[{"name":p["name"],"kind":"product"} for p in pkg["products"]]
    state_map=[]; data_flow_map=[]; cohesion_index=[]
    state_audit = REPO_ROOT/".build"/"anigma-state-flow-audit.json"
    if state_audit.exists():
        try:
            state_payload = json.loads(state_audit.read_text(encoding="utf-8"))
            state_map = state_payload.get("state_records", [])
            data_flow_map = state_payload.get("flow_records", [])
            cohesion_index = state_payload.get("cohesion_records", [])
        except Exception:
            pass
    atlas={"repo_map":sorted(repo_map,key=lambda x:x["path"]),"targets":targets,"symbols":sorted(symbols,key=lambda x:(x["language"],x["file"],x["line"],x["name"])),"dependencies":deps,"entrypoints":sorted(entries,key=lambda x:x["path"]),"authority_map":sorted(auth,key=lambda x:x["path"]),"native_map":sorted(native,key=lambda x:x["file"]),"shader_map":sorted(shaders,key=lambda x:x["file"]),"bridge_map":sorted(bridges,key=lambda x:(x["swift_file"],x.get("symbol") or "")),"risk_index":sorted(risks,key=lambda x:(x.get("path") or "",x.get("category") or "")),"state_map":state_map,"data_flow_map":data_flow_map,"cohesion_index":cohesion_index,"file_hashes":file_hashes,"atlas_metadata":{"imported_dead_code_candidates":imported_dead_code_candidates,"imported_executable_findings":imported_executable_findings,"skipped_non_actionable_dead_code_records":skipped_non_actionable_dead_code_records,"state_flow_imported":bool(state_map)}}
    return atlas

def wjson(p,data): p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(data,indent=2,sort_keys=True)+"\n",encoding="utf-8")

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--check",action="store_true"); ap.add_argument("--rebuild",action="store_true"); args=ap.parse_args(); atlas=build(); BUILD_DIR.mkdir(parents=True,exist_ok=True); ATLAS_DIR.mkdir(parents=True,exist_ok=True)
    manifest=BUILD_DIR/"repo-atlas-manifest.json"
    if args.check:
        ok=manifest.exists() and json.loads(manifest.read_text(encoding="utf-8")).get("file_hashes")==atlas["file_hashes"]
        print("fresh" if ok else "stale"); raise SystemExit(0 if ok else 1)
    write_json_stable(ATLAS_DIR/"repo-map.json", atlas["repo_map"])
    write_json_stable(ATLAS_DIR/"targets.json", atlas["targets"])
    write_json_stable(ATLAS_DIR/"symbols.json", atlas["symbols"])
    write_json_stable(ATLAS_DIR/"dependencies.json", atlas["dependencies"])
    write_json_stable(ATLAS_DIR/"entrypoints.json", atlas["entrypoints"])
    write_json_stable(ATLAS_DIR/"authority-map.json", atlas["authority_map"])
    write_json_stable(ATLAS_DIR/"native-map.json", atlas["native_map"])
    write_json_stable(ATLAS_DIR/"shader-map.json", atlas["shader_map"])
    write_json_stable(ATLAS_DIR/"bridge-map.json", atlas["bridge_map"])
    write_json_stable(ATLAS_DIR/"risk-index.json", atlas["risk_index"])
    if atlas["state_map"]:
        write_json_stable(ATLAS_DIR/"state-map.json", atlas["state_map"])
    if atlas["data_flow_map"]:
        write_json_stable(ATLAS_DIR/"data-flow-map.json", atlas["data_flow_map"])
    if atlas["cohesion_index"]:
        write_json_stable(ATLAS_DIR/"cohesion-index.json", atlas["cohesion_index"])
    write_json_stable(manifest, atlas)

if __name__=="__main__": main()
