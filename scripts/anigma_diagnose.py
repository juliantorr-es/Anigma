import argparse
import os
import subprocess
import json
import shutil
import time
import csv
from pathlib import Path

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

# Constants and Defaults
REPO_ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip())
DIAGNOSTIC_ROOT = REPO_ROOT / ".build/anigma-diagnostics"
INDEX_PATH = DIAGNOSTIC_ROOT / "index.jsonl"

# Build Status Classifications
STATUS_FAILED = "FAILED"
STATUS_CLEAN = "CLEAN"
STATUS_CONTAMINATED = "CONTAMINATED"
STATUS_PASSED = "PASSED"
STATUS_NOT_APPLICABLE = "NOT_APPLICABLE"

REQUIRED_TOOLS = ["git", "python3", "swift", "rg"]
OPTIONAL_TOOLS = ["fd", "jq", "shellcheck", "td", "bat", "eza", "fzf", "delta", "hyperfine"]

def get_task_path(task_id, commit_hash, phase):
    return DIAGNOSTIC_ROOT / "tasks" / task_id / commit_hash / phase

def run_cmd(cmd, cwd=None, capture_output=True):
    start_time = time.time()
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or REPO_ROOT,
            stdout=subprocess.PIPE if capture_output else None,
            stderr=subprocess.STDOUT if capture_output else None,
            text=True,
            check=False
        )
        duration = time.time() - start_time
        return result, duration
    except Exception as e:
        return None, 0

def run_validator_registry_check(path):
    log_path = path / "logs"
    log_path.mkdir(exist_ok=True)
    json_path = log_path / "validator-registry-check.json"
    text_path = log_path / "validator-registry-check.log"
    cmd = ["python3", "Scripts/validate_validator_registry.py", "--check", "--format", "json", "--registry", "Docs/governance/validator-registry.yaml"]
    result, duration = run_cmd(cmd)
    stdout = result.stdout if result else ""
    with open(text_path, "w") as f:
        f.write(stdout)
    try:
        data = json.loads(stdout) if stdout.strip() else {}
    except Exception:
        data = {}
    with open(json_path, "w") as f:
        json.dump(data, f, indent=2)
    return {
        "command": " ".join(cmd),
        "exitCode": result.returncode if result else 3,
        "duration": duration,
        "outputPath": str(json_path.relative_to(REPO_ROOT)),
        "logPath": str(text_path.relative_to(REPO_ROOT)),
        "failureCount": len(data.get("violations", [])) if isinstance(data, dict) else 0,
        "warningCount": len(data.get("warnings", [])) if isinstance(data, dict) else 0,
        "status": data.get("status") if isinstance(data, dict) else None,
    }

def check_tools():
    availability = {}
    for tool in REQUIRED_TOOLS + OPTIONAL_TOOLS:
        path = shutil.which(tool)
        availability[tool] = {"found": path is not None, "path": path}
    return availability

def save_tool_availability(path, availability):
    with open(path / "tool-availability.json", "w") as f:
        json.dump(availability, f, indent=2)
    
    with open(path / "tool-availability.md", "w") as f:
        f.write("# Tool Availability\n\n")
        f.write("| Tool | Status | Path |\n")
        f.write("|---|---|---|\n")
        for tool, info in availability.items():
            status = "✅" if info["found"] else ("❌" if tool in REQUIRED_TOOLS else "⚠️")
            f.write(f"| {tool} | {status} | {info['path'] or 'N/A'} |\n")

def get_git_metadata(path):
    status, _ = run_cmd(["git", "status"])
    with open(path / "git-status.txt", "w") as f:
        f.write(status.stdout if status else "ERROR: Could not capture git status")
    
    diff, _ = run_cmd(["git", "diff", "HEAD"])
    with open(path / "git-diff.patch", "w") as f:
        f.write(diff.stdout if diff else "")
    
    stat, _ = run_cmd(["git", "diff", "--stat", "HEAD"])
    with open(path / "git-diff-stat.txt", "w") as f:
        f.write(stat.stdout if stat else "")

def get_changed_files():
    result, _ = run_cmd(["git", "diff", "--name-only", "HEAD"])
    if not result or result.returncode != 0:
        # Fallback to status if no commits or other git issues
        result, _ = run_cmd(["git", "status", "--porcelain"])
        if not result or result.returncode != 0:
            return []
        files = [line[3:].strip() for line in result.stdout.splitlines()]
    else:
        files = result.stdout.splitlines()
    return sorted(list(set(files)))

def classify_file(file_path):
    path = Path(file_path)
    if path.name == "Package.swift": return "package_manifest", "high"
    
    # Docs special high-risk files
    if file_path == "Docs/td/td-task-registry.yaml": return "docs_registry", "critical"
    if "Docs/schemas/" in file_path: return "docs_schema", "high"
    if "Docs/governance/" in file_path and (file_path.endswith(".yaml") or file_path.endswith(".yml")): return "docs_governance", "high"
    if "Docs/manifests/" in file_path: return "docs_manifest", "high"
    if "Docs/governance/alignment-diagnostic-rules.yaml" in file_path: return "docs_governance", "high"
    if "Docs/governance/package-graph-rules.yaml" in file_path: return "docs_governance", "high"

    if "Sources/Contracts" in file_path or "DaemonFeatureContracts" in file_path: return "contract_module", "critical"
    
    # New: Canonical Task Artifacts
    if "Docs/td/artifacts/" in file_path: return "canonical_task_artifact", "medium"
    
    if "Native/" in file_path: return "native_shim", "critical"
    if "Sidecar" in file_path and file_path.endswith(".swift"): return "sidecar", "critical"
    if file_path.endswith(".swift"): return "production_swift", "high"
    if file_path.endswith(".sh"): return "scripts_shell", "medium"
    if file_path.endswith(".py"): return "scripts_python", "medium"
    if "Tests/" in file_path: return "tests", "medium"
    
    # Generic Docs
    if "Docs/" in file_path:
        if file_path.endswith(".json"): return "docs_json", "medium"
        if file_path.endswith(".csv"): return "docs_csv", "medium"
        if file_path.endswith(".yaml") or file_path.endswith(".yml"): return "docs_yaml", "medium"
        if "Docs/proofs" in file_path: return "docs_proofs", "low"
        if "Docs/research" in file_path: return "docs_research", "low"
        if "Docs/td" in file_path: return "docs_td", "low"
        return "docs_other", "low"

    if "External/" in file_path or "Vendor/" in file_path: return "vendor_external", "critical"
    return "unknown", "low"

def categorize_changes(files):
    categories = {}
    for f in files:
        cat, risk = classify_file(f)
        if cat not in categories: categories[cat] = []
        categories[cat].append({"path": f, "risk": risk})
    return categories

def extract_findings(log_content):
    warnings = []
    errors = []
    for line in log_content.splitlines():
        if "warning:" in line.lower():
            warnings.append(line.strip())
        if "error:" in line.lower():
            errors.append(line.strip())
    return warnings, errors

def save_artifact_manifest(path, task_id, phase, commit_hash, artifacts, extra_data=None):
    manifest = {
        "schema": "anigma.diagnostic_bundle.v1",
        "taskId": task_id,
        "phase": phase,
        "commitHash": commit_hash,
        "repoRelativeOutputPath": str(path.relative_to(REPO_ROOT)),
        "generatedArtifacts": artifacts,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    if extra_data:
        manifest.update(extra_data)
    with open(path / "artifact-manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    
    update_index_jsonl(task_id, commit_hash, phase, path, manifest)

def update_index_jsonl(task_id, commit_hash, phase, bundle_path, manifest):
    DIAGNOSTIC_ROOT.mkdir(parents=True, exist_ok=True)
    
    categorized = manifest.get("changedFileCategories", {})
    high_risk_count = 0
    critical_risk_count = 0
    for cat, items in categorized.items():
        for item in items:
            if item.get("risk") == "high":
                high_risk_count += 1
            elif item.get("risk") == "critical":
                critical_risk_count += 1

    record = {
        "schema": "anigma.diagnostic_index.v1",
        "taskId": task_id,
        "commitHash": commit_hash,
        "phase": phase,
        "bundlePath": str(bundle_path.relative_to(REPO_ROOT)),
        "artifactManifestPath": str((bundle_path / "artifact-manifest.json").relative_to(REPO_ROOT)),
        "diagnosticSummaryPath": str((bundle_path / "diagnostic-summary.md").relative_to(REPO_ROOT)) if (bundle_path / "diagnostic-summary.md").exists() else None,
        "reviewBundlePath": str((bundle_path / "review-bundle.md").relative_to(REPO_ROOT)) if (bundle_path / "review-bundle.md").exists() else None,
        "buildStatus": manifest.get("buildStatus"),
        "command": manifest.get("commandResults", {}).get("command"),
        "exitCode": manifest.get("commandResults", {}).get("exitCode"),
        "warningCount": manifest.get("warningCount", 0),
        "errorCount": manifest.get("errorCount", 0),
        "changedFileCount": len(manifest.get("changedFiles", [])),
        "highRiskFileCount": high_risk_count,
        "criticalRiskFileCount": critical_risk_count,
        "forbiddenFindingCount": len(manifest.get("forbiddenFindings", [])),
        "docsJsonCount": manifest.get("docsArtifactValidation", {}).get("docsJsonCount", 0),
        "docsCsvCount": manifest.get("docsArtifactValidation", {}).get("docsCsvCount", 0),
        "docsArtifactValidationStatus": manifest.get("docsArtifactValidation", {}).get("validationStatus")
    }
    
    with open(INDEX_PATH, "a") as f:
        f.write(json.dumps(record) + "\n")

def discover_docs_artifacts():
    json_files = []
    csv_files = []
    yaml_files = []
    
    docs_dir = REPO_ROOT / "Docs"
    if not docs_dir.exists():
        return json_files, csv_files, yaml_files
        
    for root, _, files in os.walk(docs_dir):
        for f in files:
            full_path = Path(root) / f
            rel_path = str(full_path.relative_to(REPO_ROOT))
            
            if f.endswith(".json"):
                json_files.append(rel_path)
            elif f.endswith(".csv"):
                csv_files.append(rel_path)
            elif f.endswith(".yaml") or f.endswith(".yml"):
                yaml_files.append(rel_path)
                
    return sorted(json_files), sorted(csv_files), sorted(yaml_files)

def validate_json_artifact(file_path):
    result = {
        "path": file_path,
        "category": classify_file(file_path)[0],
        "parseStatus": "FAILED",
        "schemaId": None,
        "validationNotes": ""
    }
    try:
        with open(REPO_ROOT / file_path, "r") as f:
            data = json.load(f)
        result["parseStatus"] = "PASSED"
        if isinstance(data, dict):
            result["schemaId"] = data.get("$schema") or data.get("schema")
    except Exception as e:
        result["validationNotes"] = str(e)
    return result

def validate_csv_artifact(file_path):
    result = {
        "path": file_path,
        "header": None,
        "rowCount": 0,
        "columnCount": 0,
        "parseStatus": "FAILED",
        "validationNotes": ""
    }
    try:
        with open(REPO_ROOT / file_path, "r", newline="") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            result["header"] = header
            if header:
                result["columnCount"] = len(header)
                if len(set(header)) != len(header):
                    result["validationNotes"] += "Duplicate headers detected. "
                if any(not h.strip() for h in header):
                    result["validationNotes"] += "Empty header fields detected. "
            
            rows = list(reader)
            result["rowCount"] = len(rows)
            result["parseStatus"] = "PASSED"
            
            for i, row in enumerate(rows):
                if len(row) != result["columnCount"]:
                    result["validationNotes"] += f"Ragged row at line {i+2}. "
                    result["parseStatus"] = "CONTAMINATED"
                    break
            
            if result["rowCount"] == 0:
                result["parseStatus"] = "CONTAMINATED"
                result["validationNotes"] += "Empty CSV (no data rows). "
                
    except Exception as e:
        result["validationNotes"] = str(e)
    return result

def validate_yaml_artifact(file_path):
    result = {
        "path": file_path,
        "parseStatus": "FAILED",
        "topLevelType": None,
        "validationNotes": ""
    }
    if not HAS_YAML:
        result["parseStatus"] = "CONTAMINATED"
        result["validationNotes"] = "PyYAML missing, could not validate."
        return result
        
    try:
        with open(REPO_ROOT / file_path, "r") as f:
            data = yaml.safe_load(f)
        result["parseStatus"] = "PASSED"
        result["topLevelType"] = type(data).__name__
    except Exception as e:
        result["validationNotes"] = str(e)
    return result

def validate_docs_artifacts(bundle_path):
    json_files, csv_files, yaml_files = discover_docs_artifacts()
    
    docs_json_results = [validate_json_artifact(f) for f in json_files]
    docs_csv_results = [validate_csv_artifact(f) for f in csv_files]
    docs_yaml_results = [validate_yaml_artifact(f) for f in yaml_files]
    
    summary = {
        "docsJsonCount": len(json_files),
        "docsCsvCount": len(csv_files),
        "docsYamlCount": len(yaml_files),
        "invalidJsonCount": sum(1 for r in docs_json_results if r["parseStatus"] == "FAILED"),
        "invalidCsvCount": sum(1 for r in docs_csv_results if r["parseStatus"] == "FAILED"),
        "invalidYamlCount": sum(1 for r in docs_yaml_results if r["parseStatus"] == "FAILED"),
        "validationStatus": STATUS_CLEAN
    }
    
    if summary["invalidJsonCount"] > 0 or summary["invalidCsvCount"] > 0 or summary["invalidYamlCount"] > 0:
        summary["validationStatus"] = STATUS_FAILED
    elif any(r["parseStatus"] == "CONTAMINATED" for r in docs_json_results + docs_csv_results + docs_yaml_results):
        summary["validationStatus"] = STATUS_CONTAMINATED
    elif summary["docsJsonCount"] == 0 and summary["docsCsvCount"] == 0 and summary["docsYamlCount"] == 0:
        summary["validationStatus"] = STATUS_NOT_APPLICABLE

    artifacts_dir = bundle_path / "docs-artifacts"
    artifacts_dir.mkdir(exist_ok=True)
    
    with open(artifacts_dir / "docs-json-files.json", "w") as f:
        json.dump(docs_json_results, f, indent=2)
    with open(artifacts_dir / "docs-csv-files.json", "w") as f:
        json.dump(docs_csv_results, f, indent=2)
    with open(artifacts_dir / "docs-yaml-files.json", "w") as f:
        json.dump(docs_yaml_results, f, indent=2)
    with open(artifacts_dir / "docs-artifact-validation.json", "w") as f:
        json.dump(summary, f, indent=2)
        
    with open(artifacts_dir / "docs-artifact-validation.md", "w") as f:
        f.write("# Docs Artifact Validation Summary\n\n")
        f.write(f"Status: **{summary['validationStatus']}**\n\n")
        f.write(f"- JSON: {summary['docsJsonCount']} (Invalid: {summary['invalidJsonCount']})\n")
        f.write(f"- CSV: {summary['docsCsvCount']} (Invalid: {summary['invalidCsvCount']})\n")
        f.write(f"- YAML: {summary['docsYamlCount']} (Invalid: {summary['invalidYamlCount']})\n")

    return summary, docs_json_results, docs_csv_results, docs_yaml_results

def run_validation_hooks(files, log_path):
    results = []
    for f in files:
        if f.endswith(".sh"):
            if shutil.which("shellcheck"):
                res, _ = run_cmd(["shellcheck", f])
                results.append({"file": f, "tool": "shellcheck", "exitCode": res.returncode, "output": res.stdout})
        elif f.endswith(".py"):
            res, _ = run_cmd(["python3", "-m", "py_compile", f])
            results.append({"file": f, "tool": "py_compile", "exitCode": res.returncode, "output": res.stdout})
        elif f.endswith(".json"):
            try:
                with open(REPO_ROOT / f, "r") as jf:
                    json.load(jf)
                results.append({"file": f, "tool": "json.tool", "exitCode": 0, "output": "Valid JSON"})
            except Exception as e:
                results.append({"file": f, "tool": "json.tool", "exitCode": 1, "output": str(e)})
    
    with open(log_path / "validation-hooks.json", "w") as f:
        json.dump(results, f, indent=2)
    return results

def scan_forbidden_findings(files):
    findings = []
    
    # 1. Root-level artifacts
    for f in files:
        if Path(f).parent == Path(".") and any(p in f.lower() for p in ["td-", "review", "completion", "handoff"]):
            findings.append({"file": f, "type": "root_artifact", "message": "TD/Review artifact found in root directory"})

    # 2. Forbidden imports
    for f in files:
        if f.endswith(".swift"):
            res, _ = run_cmd(["rg", "@_exported import", f])
            if res and res.stdout:
                for line in res.stdout.splitlines():
                    if "GovernanceCore" not in line: # Basic allowlist
                        findings.append({"file": f, "type": "forbidden_import", "message": f"Unauthorized @_exported import: {line.strip()}"})

    # 3. Native handles in contracts
    contract_files = [f for f in files if "Sources/Contracts" in f or "DaemonFeatureContracts" in f]
    native_patterns = ["MTLBuffer", "CVPixelBuffer", "IOSurface", "CUdeviceptr", "hipDeviceptr", "UnsafeRawPointer", "OpaquePointer", "void *", "PDFium", "FPDF_"]
    for f in contract_files:
        for p in native_patterns:
            res, _ = run_cmd(["rg", p, f])
            if res and res.stdout:
                findings.append({"file": f, "type": "native_handle_in_contract", "message": f"Found native handle pattern '{p}' in contract module"})

    # 4. Zero-copy claims
    zero_copy_patterns = ["zero-copy", "zero copy", "no-copy", "hardware-resident", "hardware resident"]
    for f in files:
        if f.endswith(".swift") or f.endswith(".md"):
            for p in zero_copy_patterns:
                res, _ = run_cmd(["rg", "-i", p, f])
                if res and res.stdout:
                    findings.append({"file": f, "type": "zero_copy_claim", "message": f"Zero-copy claim found: {res.stdout.splitlines()[0][:100]}"})

    return findings

def baseline(args):
    commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "baseline")
    path.mkdir(parents=True, exist_ok=True)
    
    tools = check_tools()
    save_tool_availability(path, tools)
    get_git_metadata(path)
    
    changed_files = get_changed_files()
    with open(path / "changed-files.json", "w") as f:
        json.dump(changed_files, f, indent=2)
    
    categorized = categorize_changes(changed_files)
    with open(path / "changed-files-by-category.json", "w") as f:
        json.dump(categorized, f, indent=2)

    # Capture Graph/Alignment
    run_cmd(["python3", "scripts/anigma_package_graph_audit.py", "--output-dir", str(path / "package-graph"), "snapshot"])
    run_cmd(["python3", "scripts/anigma_package_graph_audit.py", "--output-dir", str(path / "alignment"), "alignment-matrix"])
    
    # Run Dead Code Audit (Advisory)
    dead_code_res = run_dead_code_audit(path)
    
    # Run Executable Consolidation Audit (Advisory)
    executable_consolidation_res = run_executable_consolidation_audit(path)

    docs_val, _, _, _ = validate_docs_artifacts(path)

    extra = {
        "changedFiles": changed_files,
        "changedFileCategories": categorized,
        "graphSnapshot": str(path / "package-graph"),
        "alignmentMatrix": str(path / "alignment"),
        "docsArtifactValidation": docs_val,
        "deadCodeAudit": dead_code_res,
        "executableConsolidationAudit": executable_consolidation_res
    }
    
    artifacts = [
        "tool-availability.json", "tool-availability.md",
        "git-status.txt", "git-diff.patch", "git-diff-stat.txt",
        "changed-files.json", "changed-files-by-category.json",
        "package-graph/", "alignment/",
        "docs-artifacts/",
        "dead-code-audit/",
        "executable-consolidation-audit/"
    ]
    save_artifact_manifest(path, args.task_id, "baseline", commit_hash, artifacts, extra)
    
    print(f"Baseline captured: {path}")

def run_dead_code_audit(path, mode="advisory"):
    audit_path = path / "dead-code-audit"
    audit_path.mkdir(exist_ok=True)
    json_out = audit_path / "findings.json"
    proof_out = audit_path / "report.md"
    
    cmd = ["python3", "scripts/anigma_dead_code_audit.py", "--mode", mode, "--json-out", str(json_out), "--proof-out", str(proof_out)]
    res, _ = run_cmd(cmd)
    
    return {
        "exitCode": res.returncode if res else 2,
        "jsonOut": str(json_out.relative_to(REPO_ROOT)),
        "proofOut": str(proof_out.relative_to(REPO_ROOT))
    }

def run_executable_consolidation_audit(path, mode="advisory"):
    audit_path = path / "executable-consolidation-audit"
    audit_path.mkdir(exist_ok=True)
    json_out = audit_path / "findings.json"
    proof_out = audit_path / "report.md"
    
    cmd = ["python3", "scripts/anigma_executable_consolidation_audit.py", "--mode", mode, "--json-out", str(json_out), "--proof-out", str(proof_out), "--focus", "anigmad"]
    res, _ = run_cmd(cmd)
    
    return {
        "exitCode": res.returncode if res else 2,
        "jsonOut": str(json_out.relative_to(REPO_ROOT)),
        "proofOut": str(proof_out.relative_to(REPO_ROOT))
    }

def validate(args):
    commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "validate")
    path.mkdir(parents=True, exist_ok=True)
    
    tools = check_tools()
    save_tool_availability(path, tools)
    get_git_metadata(path)
    registry_check = run_validator_registry_check(path)
    
    # Run command and capture
    print(f"Executing: {args.command}")
    result, duration = run_cmd(args.command.split())
    
    log_path = path / "logs"
    log_path.mkdir(exist_ok=True)
    
    log_content = result.stdout if result else "ERROR: Command execution failed"
    with open(log_path / "command.log", "w") as f:
        f.write(log_content)
    
    warnings, errors = extract_findings(log_content)
    with open(log_path / "warnings.txt", "w") as f:
        f.write("\n".join(warnings))
    with open(log_path / "errors.txt", "w") as f:
        f.write("\n".join(errors))
    
    exit_code = result.returncode if result else 1
    registry_failed = registry_check["exitCode"] != 0

    if exit_code != 0:
        status = STATUS_FAILED
    elif registry_failed:
        status = STATUS_FAILED
    elif len(warnings) > 0:
        status = STATUS_CONTAMINATED
    else:
        status = STATUS_CLEAN
        
    status_data = {
        "exitCode": exit_code,
        "status": status,
        "duration": duration,
        "warningCount": len(warnings),
        "errorCount": len(errors),
        "validatorRegistryCheck": registry_check
    }
    with open(log_path / "build-status.json", "w") as f:
        json.dump(status_data, f, indent=2)
    
    docs_val, _, _, _ = validate_docs_artifacts(path)

    # Run Dead Code Audit (Advisory)
    dead_code_res = run_dead_code_audit(path)
    
    # Run Executable Consolidation Audit (Advisory)
    executable_consolidation_res = run_executable_consolidation_audit(path)

    extra = {
        "commandResults": {
            "command": args.command,
            "exitCode": exit_code
        },
        "buildStatus": status,
        "warningCount": len(warnings),
        "errorCount": len(errors),
        "validator_registry_check_status": registry_check["status"],
        "validator_registry_check_command": registry_check["command"],
        "validator_registry_check_exit_code": registry_check["exitCode"],
        "validator_registry_check_output_path": registry_check["outputPath"],
        "validator_registry_check_failure_count": registry_check["failureCount"],
        "docsArtifactValidation": docs_val,
        "deadCodeAudit": dead_code_res,
        "executableConsolidationAudit": executable_consolidation_res
    }
    
    artifacts = [
        "tool-availability.json", "tool-availability.md",
        "git-status.txt", "git-diff.patch", "git-diff-stat.txt",
        "logs/command.log", "logs/warnings.txt", "logs/errors.txt", "logs/build-status.json",
        "docs-artifacts/",
        "dead-code-audit/",
        "executable-consolidation-audit/"
    ]
    save_artifact_manifest(path, args.task_id, "validate", commit_hash, artifacts, extra)
    
    print(f"Validation completed: {path} (Status: {status})")
    return 1 if registry_failed or exit_code != 0 else 0

def review(args):
    commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "review")
    path.mkdir(parents=True, exist_ok=True)
    
    tools = check_tools()
    save_tool_availability(path, tools)
    get_git_metadata(path)
    registry_check = run_validator_registry_check(path)
    registry_failed = registry_check["exitCode"] != 0

    review_command_result = None
    if getattr(args, "command", None):
        review_command_result, review_command_duration = run_cmd(args.command.split())
        review_command_log = path / "logs" / "review-command.log"
        with open(review_command_log, "w") as f:
            f.write(review_command_result.stdout if review_command_result else "ERROR: Command execution failed")
    else:
        review_command_duration = 0
    
    changed_files = get_changed_files()
    categorized = categorize_changes(changed_files)
    
    findings = scan_forbidden_findings(changed_files)
    with open(path / "forbidden-findings.json", "w") as f:
        json.dump(findings, f, indent=2)
    
    log_path = path / "logs"
    log_path.mkdir(exist_ok=True)
    hook_results = run_validation_hooks(changed_files, log_path)
    
    docs_val, docs_json, docs_csv, docs_yaml = validate_docs_artifacts(path)

    # Run Dead Code Audit (Advisory)
    dead_code_res = run_dead_code_audit(path)
    
    # Run Executable Consolidation Audit (Advisory)
    executable_consolidation_res = run_executable_consolidation_audit(path)

    with open(path / "review-bundle.md", "w") as f:
        f.write(f"# Review Bundle: {args.task_id}\n\n")
        f.write(f"Commit: `{commit_hash}`\n\n")
        
        f.write("## Changed Files Summary\n")
        for cat, items in categorized.items():
            f.write(f"### {cat}\n")
            for item in items:
                f.write(f"- `{item['path']}` (Risk: {item['risk']})\n")
        
        f.write("\n## Dead Code Audit\n")
        f.write(f"Status: **Advisory**\n")
        f.write(f"Report: [dead-code-audit/report.md](dead-code-audit/report.md)\n")
        
        f.write("\n## Executable Consolidation Audit\n")
        f.write(f"Status: **Advisory**\n")
        f.write(f"Report: [executable-consolidation-audit/report.md](executable-consolidation-audit/report.md)\n")

        f.write("\n## Forbidden Findings\n")
        if not findings:
            f.write("✅ No forbidden findings detected.\n")
        else:
            for find in findings:
                f.write(f"- ❌ **{find['type']}**: `{find['file']}` - {find['message']}\n")
        
        f.write("\n## Docs Artifact Validation\n")
        f.write(f"Overall Status: **{docs_val['validationStatus']}**\n\n")
        f.write(f"- JSON artifacts: {docs_val['docsJsonCount']} (Invalid: {docs_val['invalidJsonCount']})\n")
        f.write(f"- CSV artifacts: {docs_val['docsCsvCount']} (Invalid: {docs_val['invalidCsvCount']})\n")
        f.write(f"- YAML artifacts: {docs_val['docsYamlCount']} (Invalid: {docs_val['invalidYamlCount']})\n")
        
        invalid_artifacts = [r for r in docs_json + docs_csv + docs_yaml if r["parseStatus"] == "FAILED"]
        if invalid_artifacts:
            f.write("\n### ❌ Invalid Artifacts\n")
            for art in invalid_artifacts:
                f.write(f"- `{art['path']}`: {art.get('validationNotes')}\n")
        
        high_risk_docs = categorized.get("docs_schema", []) + categorized.get("docs_registry", []) + categorized.get("docs_manifest", [])
        if high_risk_docs:
            f.write("\n### ⚠️ High-Risk Docs Changes\n")
            for art in high_risk_docs:
                f.write(f"- `{art['path']}` (Risk: {art['risk']})\n")

        f.write("\n## Validation Hooks\n")
        for res in hook_results:
            status = "✅" if res["exitCode"] == 0 else "❌"
            f.write(f"- {status} `{res['file']}` ({res['tool']})\n")

    extra = {
        "changedFiles": changed_files,
        "changedFileCategories": categorized,
        "forbiddenFindings": findings,
        "validationResults": hook_results,
        "reviewCommand": {
            "command": getattr(args, "command", None),
            "exitCode": review_command_result.returncode if review_command_result else None,
            "duration": review_command_duration,
        } if getattr(args, "command", None) else None,
        "validator_registry_check_status": registry_check["status"],
        "validator_registry_check_command": registry_check["command"],
        "validator_registry_check_exit_code": registry_check["exitCode"],
        "validator_registry_check_output_path": registry_check["outputPath"],
        "validator_registry_check_failure_count": registry_check["failureCount"],
        "docsArtifactValidation": docs_val,
        "deadCodeAudit": dead_code_res,
        "executableConsolidationAudit": executable_consolidation_res
    }

    artifacts = [
        "tool-availability.json", "tool-availability.md",
        "git-status.txt", "git-diff.patch", "git-diff-stat.txt",
        "forbidden-findings.json", "logs/validation-hooks.json", "review-bundle.md",
        "docs-artifacts/",
        "dead-code-audit/",
        "executable-consolidation-audit/"
    ]
    save_artifact_manifest(path, args.task_id, "review", commit_hash, artifacts, extra)
    
    print(f"Review bundle generated: {path}")
    return 1 if registry_failed else 0

def diff(args):
    commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()[:8]
    path = get_task_path(args.task_id, commit_hash, "diff")
    path.mkdir(parents=True, exist_ok=True)
    
    changed_files = get_changed_files()
    categorized = categorize_changes(changed_files)
    
    docs_val, _, _, _ = validate_docs_artifacts(path)

    with open(path / "diff-risk-summary.md", "w") as f:
        f.write(f"# Diff Risk Summary: {args.task_id}\n\n")
        f.write(f"Commit: `{commit_hash}`\n\n")
        
        f.write("## Risk Classification\n")
        for cat, items in categorized.items():
            f.write(f"### {cat}\n")
            for item in items:
                f.write(f"- `{item['path']}` (Risk: {item['risk']})\n")
        
        f.write("\n## Docs Artifact Changes\n")
        f.write(f"Validation Status: **{docs_val['validationStatus']}**\n")
        docs_changes = [cf for cf in changed_files if cf.startswith("Docs/")]
        if docs_changes:
            for cf in docs_changes:
                f.write(f"- `{cf}`\n")
        else:
            f.write("No changes to Docs/ artifacts detected in this diff.\n")

    extra = {
        "docsArtifactValidation": docs_val
    }
    artifacts = ["diff-risk-summary.md", "docs-artifacts/"]
    save_artifact_manifest(path, args.task_id, "diff", commit_hash, artifacts, extra)
    
    print(f"Diff risk summary generated: {path}")

def index(args):
    if not INDEX_PATH.exists():
        print(f"Index not found: {INDEX_PATH}")
        return

    records = []
    with open(INDEX_PATH, "r") as f:
        for line in f:
            if line.strip():
                records.append(json.loads(line))

    if args.task_id:
        records = [r for r in records if r.get("taskId") == args.task_id]

    if not records:
        print("No diagnostic records found.")
        return

    print(f"{'Task ID':<40} {'Phase':<12} {'Status':<12} {'Commit'}")
    print("-" * 80)
    for r in records[-50:]: # Show latest 50
        status = r.get("buildStatus") or r.get("docsArtifactValidationStatus") or "N/A"
        print(f"{r.get('taskId'):<40} {r.get('phase'):<12} {status:<12} {r.get('commitHash')}")

def main():
    parser = argparse.ArgumentParser(description="Master Anigma Diagnostic Harness")
    subparsers = parser.add_subparsers(dest="mode")

    # Baseline Parser
    base = subparsers.add_parser("baseline")
    base.add_argument("--task-id", required=True)

    # Validate Parser
    val = subparsers.add_parser("validate")
    val.add_argument("--task-id", required=True)
    val.add_argument("--command", required=True)

    # Review Parser
    rev = subparsers.add_parser("review")
    rev.add_argument("--task-id", required=True)
    rev.add_argument("--command", required=False)
    
    # Diff Parser
    df = subparsers.add_parser("diff")
    df.add_argument("--task-id", required=True)
    df.add_argument("--from-phase", dest="from_phase", default="baseline")
    df.add_argument("--to-phase", dest="to_phase", default="validate")

    # Index Parser
    idx = subparsers.add_parser("index")
    idx.add_argument("--task-id")

    args = parser.parse_args()

    if args.mode == "baseline":
        baseline(args)
    elif args.mode == "validate":
        raise SystemExit(validate(args) or 0)
    elif args.mode == "review":
        raise SystemExit(review(args) or 0)
    elif args.mode == "diff":
        diff(args)
    elif args.mode == "index":
        index(args)

if __name__ == "__main__":
    main()
