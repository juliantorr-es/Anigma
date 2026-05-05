import os
import sys
import argparse
import re
import json
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_common.repo import repo_root, repo_relative
from scripts.anigma_common.io import write_json_stable
from scripts.anigma_common.findings import stable_finding_id

# Scanner Metadata
SCANNER_NAME = "anigma_executable_consolidation_audit"
SCANNER_VERSION = "2.0.0"
RULES_VERSION = "2026-05-05.2"

# Rules Definition
RULES = [
    {
        "id": "identity.process.name",
        "version": 1,
        "category": "process_identity",
        "regex": r"(ProcessInfo\.processInfo\.processName|ProcessInfo\.processInfo\.arguments)",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "Former executable behavior may still branch on process identity after consolidation.",
        "review_question": "Does this code read process identity even though anigmad is now the only entrypoint?"
    },
    {
        "id": "configuration.ingress.argv",
        "version": 1,
        "category": "configuration_ingress",
        "regex": r"(CommandLine\.arguments)",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "Direct access to CommandLine.arguments bypasses the centralized configuration authority.",
        "review_question": "Does this code read CommandLine.arguments directly instead of using injected configuration?"
    },
    {
        "id": "configuration.ingress.env",
        "version": 1,
        "category": "argv_and_environment",
        "regex": r"(ProcessInfo\.processInfo\.environment)",
        "severity": "medium",
        "confidence": "medium_confidence",
        "rationale": "Former executables may depend on env vars that are absent or conflicting inside anigmad.",
        "review_question": "Does this code depend on environment variables originally meant for a standalone CLI tool?"
    },
    {
        "id": "runtime.cwd.direct",
        "version": 1,
        "category": "working_directory",
        "regex": r"(FileManager\.default\.currentDirectoryPath|\.currentDirectoryPath\b|chdir\()",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "A daemon has a different working directory than ad-hoc CLI tools.",
        "review_question": "Does this code assume cwd is repo root, app bundle root, or the old helper executable directory?"
    },
    {
        "id": "bundle.resource.lookup",
        "version": 1,
        "category": "bundle_resource_lookup",
        "regex": r"(Bundle\.main|Bundle\.module|\bpath\(forResource:|\burl\(forResource:|\bresourceURL\b)",
        "severity": "medium",
        "confidence": "medium_confidence",
        "rationale": "Resource lookup may change when code moves from executable target to library/daemon target.",
        "review_question": "Does this code assume Bundle.main is its own standalone executable bundle?"
    },
    {
        "id": "singleton.global.state",
        "version": 1,
        "category": "singleton_global_state",
        "regex": r"(static\s+let\s+shared\s*=\s*|static\s+var\s+[a-zA-Z0-9_]+\s*:)",
        "severity": "medium",
        "confidence": "low_confidence",
        "rationale": "Former process-local singleton state may collide when multiple capabilities share one daemon.",
        "review_question": "Does this code use static shared mutable state that was formerly isolated by process boundaries?"
    },
    {
        "id": "lifecycle.entrypoint.direct",
        "version": 1,
        "category": "entrypoint_lifecycle",
        "regex": r"(@main\b|NSApplicationMain|RunLoop\.main\.run|dispatchMain\(\))",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "Former entrypoint code may survive in library paths or conflict with anigmad lifecycle.",
        "review_question": "Does this code hijack the main thread or define a competing entrypoint?"
    },
    {
        "id": "lifecycle.shutdown.exit",
        "version": 1,
        "category": "shutdown_and_exit",
        "regex": r"(\bexit\(|fatalError\(|preconditionFailure\(|abort\(\))",
        "severity": "critical",
        "confidence": "high_confidence",
        "rationale": "A former helper exiting itself can now terminate the whole daemon.",
        "review_question": "Can this code call exit/fatalError and kill the whole daemon?"
    },
    {
        "id": "lifecycle.signal.handler",
        "version": 1,
        "category": "signal_handling",
        "regex": r"(\bsignal\(|DispatchSource\.makeSignalSource|SIGINT|SIGTERM|SIGHUP)",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "Multiple merged subsystems may install competing signal handlers.",
        "review_question": "Does this code install signal handlers that compete with daemon-level shutdown handling?"
    },
    {
        "id": "ipc.binding.socket",
        "version": 2,
        "category": "daemon_ipc_binding",
        "regex": r"(\.sock\b|\.socket\b|\.pid\"|\.lock\"|localhost|127\.0\.0\.1|::1|\/var\/run|\/run\/|NWListener|NWConnection|UnixDomainSocket|ServerBootstrap|MultiThreadedEventLoopGroup|socketPath|port:|host:|\bbind\(|\blisten\()",
        "severity": "critical",
        "confidence": "medium_confidence",
        "rationale": "Former sidecars may collide on sockets, ports, PID files, or lock files.",
        "review_question": "Does this code bind a socket, port, PID file, or lock file that another folded component also binds?"
    },
    {
        "id": "storage.path.temp",
        "version": 1,
        "category": "temporary_paths",
        "regex": r"(NSTemporaryDirectory\(\)|\"/tmp\"|\"/var/tmp\")",
        "severity": "high",
        "confidence": "high_confidence",
        "rationale": "Former executables may share temp paths and overwrite each other.",
        "review_question": "Does this code write temp/cache files into paths that were formerly executable-specific?"
    },
    {
        "id": "observability.log.direct",
        "version": 1,
        "category": "logging_destination",
        "regex": r"(\bprint\(|NSLog\(|os_log\(|Logger\()",
        "severity": "low",
        "confidence": "medium_confidence",
        "rationale": "Consolidated daemon logging needs subsystem/category separation and governance receipts.",
        "review_question": "Does this code write logs into unstructured stdout/stderr instead of unified daemon logging?"
    },
    {
        "id": "runtime.task.detached",
        "version": 1,
        "category": "detached_tasks_and_lifetime",
        "regex": r"(Task\.detached|DispatchQueue\.global\(\)\.async|Timer\.scheduledTimer)",
        "severity": "medium",
        "confidence": "low_confidence",
        "rationale": "Former short-lived process tasks may now leak for daemon lifetime.",
        "review_question": "Does this code start an unstructured task that used to die when the helper process exited?"
    },
    {
        "id": "security.entitlements.direct",
        "version": 1,
        "category": "security_and_entitlements",
        "regex": r"(SecItemAdd|SecTrust|AVCaptureDevice|kAXISAppleSystemEntitlement)",
        "severity": "high",
        "confidence": "medium_confidence",
        "rationale": "Consolidated executable may need different sandbox/entitlement behavior.",
        "review_question": "Does this code assume permissions/entitlements belong to the old helper executable instead of anigmad?"
    },
    {
        "id": "runtime.test.detection",
        "version": 1,
        "category": "test_mode_detection",
        "regex": r"(XCTest|XCODE_RUNNING_FOR_PREVIEWS|DEBUG|CI\b)",
        "severity": "medium",
        "confidence": "medium_confidence",
        "rationale": "Runtime behavior may accidentally depend on test or preview detection.",
        "review_question": "Does this production code accidentally depend on test mode flags?"
    }
]

# Approved entrypoint boundaries (only files where process-level access is allowed)
APPROVED_ENTRYPOINTS = [
    "anigma/Sources/anigmad/main.swift",
    "anigma/Packages/AnigmaDaemon/main.swift"
]

def normalize_snippet(snippet):
    return re.sub(r'\s+', '', snippet)

def hash_finding(file_path, rule, snippet):
    # Stable semantic key: path + rule_id + normalized_snippet
    rel_path = str(file_path)
    normalized = normalize_snippet(snippet)
    return stable_finding_id({"path": rel_path, "rule_id": rule["id"], "snippet": normalized})

def scan_file(file_path):
    findings = []
    
    # Check if this is RuntimeAuthority (special classification)
    is_authority = file_path.name == "RuntimeAuthority.swift"
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_no, line in enumerate(f, 1):
                for rule in RULES:
                    match = re.search(rule["regex"], line)
                    if match:
                        snippet = line.strip()
                        finding_id = hash_finding(file_path, rule, snippet)
                        
                        severity = rule["severity"]
                        confidence = rule["confidence"]
                        
                        # Special handling for RuntimeAuthority
                        if is_authority:
                            # Classify as authority_boundary/info if it's an approved finding
                            # approved findings are generally those that RuntimeAuthority is designed to handle:
                            # process identity, argv, environment, cwd.
                            if rule["category"] in ["process_identity", "configuration_ingress", "argv_and_environment", "working_directory", "shutdown_and_exit"]:
                                severity = "info"
                                confidence = "high_confidence"
                                rule_category = "authority_boundary"
                            else:
                                rule_category = rule["category"]
                        else:
                            rule_category = rule["category"]

                        findings.append({
                            "finding_id": finding_id,
                            "id": finding_id,
                            "rule_id": rule["id"],
                            "rule_version": rule["version"],
                            "file": str(file_path),
                            "line": line_no,
                            "category": rule_category,
                            "matched_pattern": rule["regex"],
                            "snippet": snippet,
                            "severity": severity,
                            "confidence": confidence,
                            "rationale": rule["rationale"],
                            "suggested_review_question": rule["review_question"],
                            "source": "executable-consolidation-audit",
                            "scanner_name": SCANNER_NAME,
                            "scanner_version": SCANNER_VERSION,
                            "rules_version": RULES_VERSION,
                            "path": str(file_path),
                            "language": "swift",
                            "baseline_key": f"{file_path}:{line_no}:{rule['id']}",
                        })
    except Exception as e:
        pass
    return findings

def is_anigmad_focus(file_path):
    path_str = str(file_path).lower()
    # Explicit focus: only files in the anigmad daemon/core targets
    focus_paths = [
        "anigma/packages/anigmadaemon/",
        "anigma/packages/anigmadaemoncore/"
    ]
    return any(p in path_str for p in focus_paths)

def is_daemon_runtime_broad(file_path):
    path_str = str(file_path).lower()
    focus_keywords = [
        "anigmad", "daemon", "kernel", "runtime", 
        "sidecar", "anigmamcpmodule", "anigmadaemoncore",
        "fixtures"
    ]
    return any(k in path_str for k in focus_keywords)

def load_baseline(baseline_path):
    if not baseline_path or not os.path.exists(baseline_path):
        return set()
    try:
        with open(baseline_path, 'r') as f:
            data = json.load(f)
            if isinstance(data, list):
                return set(data)
            if isinstance(data, dict):
                findings = data.get("findings", [])
                keys = set()
                for item in findings:
                    if isinstance(item, dict):
                        key = item.get("baseline_key") or item.get("finding_id") or item.get("id")
                        if key:
                            keys.add(key)
                    elif isinstance(item, str):
                        keys.add(item)
                return keys
            return set()
    except Exception as e:
        print(f"Error loading baseline: {e}")
        return set()

def main():
    parser = argparse.ArgumentParser(description="Anigma Executable Consolidation Audit")
    parser.add_argument("--mode", choices=["advisory", "gate"], default="advisory")
    parser.add_argument("--baseline", help="Path to baseline JSON file")
    parser.add_argument("--write-baseline", help="Path to write baseline JSON file")
    parser.add_argument("--json-out", help="Path to write findings JSON")
    parser.add_argument("--proof-out", help="Path to write markdown proof report")
    parser.add_argument("--focus", choices=["anigmad"], help="Focus scan on specific subsystem")
    parser.add_argument("--include-tests", action="store_true", help="Include test files")
    parser.add_argument("--no-proof", action="store_true", help="Skip proof generation")
    
    parser.add_argument("--path", help="Root directory to scan")
    
    args = parser.parse_args()
    
    repo_root_path = repo_root()
    scan_path = Path(args.path) if args.path else repo_root_path
    os.chdir(repo_root_path)

    print("Running Executable Consolidation Audit...")
    
    baseline_ids = load_baseline(args.baseline)
    
    all_findings = []
    scanned_files = 0
    
    for root, dirs, files in os.walk(scan_path):
        # Exclude common noisy directories
        # But don't exclude the scan_path itself if it happens to be one of these (e.g. for testing)
        rel_root = os.path.relpath(root, scan_path)
        if any(d in rel_root.split(os.sep) for d in [".build", ".git", "Vendor", "DerivedData"]):
            continue
            
        # Also exclude scripts directory from general scans unless we are explicitly scanning it
        if "scripts" in root.split(os.sep) and "fixtures" not in root.split(os.sep):
             # This is a bit crude but should work for our structure
             if scan_path != repo_root_path / "scripts" and not str(scan_path).startswith(str(repo_root_path / "scripts")):
                 continue
        if not args.include_tests and ("Tests" in root or "tests" in root):
            continue
            
        for file in files:
            if not file.endswith(".swift"):
                continue
            
            file_path = Path(root) / file
            try:
                rel_path = repo_relative(file_path)
            except ValueError:
                # Fallback if not under repo root (e.g. during some tests)
                rel_path = str(file_path)
            
            if rel_path.startswith("./"):
                rel_path = rel_path[2:]
            
            # Explicit entrypoint boundary check
            is_approved_entrypoint = rel_path in APPROVED_ENTRYPOINTS
            
            if args.focus == "anigmad":
                if not is_anigmad_focus(file_path):
                    continue
            else:
                # Broad focus by default
                if not is_daemon_runtime_broad(file_path):
                    continue
                
            scanned_files += 1
            findings = scan_file(file_path)
            
            if is_approved_entrypoint:
                # Filter out approved entrypoint findings
                findings = [f for f in findings if f["category"] in ["authority_boundary"] or f["rule_id"] not in ["identity.process.name", "configuration.ingress.argv", "configuration.ingress.env", "lifecycle.entrypoint.direct"]]
                
            all_findings.extend(findings)

    # Output baseline if requested
    if args.write_baseline:
        baseline_data = {
            "scanner": SCANNER_NAME,
            "scanner_version": SCANNER_VERSION,
            "rules_version": RULES_VERSION,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "findings": all_findings
        }
        write_json_stable(Path(args.write_baseline), baseline_data)
        print(f"Baseline written to {args.write_baseline}")

    # Output JSON if requested
    if args.json_out:
        output = {
            "scanner": SCANNER_NAME,
            "scanner_version": SCANNER_VERSION,
            "rules_version": RULES_VERSION,
            "findings": all_findings
        }
        write_json_stable(Path(args.json_out), output)
            
    # Calculate stats
    stats_severity = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
    stats_confidence = {"high_confidence": 0, "medium_confidence": 0, "low_confidence": 0}
    stats_category = {}
    
    new_findings = []
    
    for f in all_findings:
        stats_severity[f["severity"]] += 1
        stats_confidence[f["confidence"]] += 1
        stats_category[f["category"]] = stats_category.get(f["category"], 0) + 1
        
        if f.get("baseline_key") not in baseline_ids and f.get("id") not in baseline_ids:
            new_findings.append(f)

    # Gate logic
    gate_failed = False
    if args.mode == "gate":
        for f in new_findings:
            if f["confidence"] == "high_confidence" and f["severity"] in ["critical", "high"]:
                print(f"[GATE FAILURE] New high-confidence critical/high finding: {f['file']}:{f['line']} -> {f['snippet']}")
                gate_failed = True

    # Output Markdown Proof
    if args.proof_out and not args.no_proof:
        os.makedirs(os.path.dirname(args.proof_out), exist_ok=True)
        with open(args.proof_out, "w") as f:
            f.write("# Proof: Executable Consolidation Audit\n\n")
            f.write(f"**Date:** {datetime.utcnow().isoformat()[:10]}\n")
            f.write(f"**Mode:** {args.mode}\n")
            f.write(f"**Focus:** {args.focus or 'all'}\n\n")
            f.write("## Summary Stats\n")
            f.write(f"- **Swift Files Scanned:** {scanned_files}\n")
            f.write(f"- **Total Findings:** {len(all_findings)}\n")
            f.write(f"- **New Findings (Unbaselined):** {len(new_findings)}\n\n")
            
            f.write("### By Severity\n")
            for sev, count in stats_severity.items():
                f.write(f"- {sev}: {count}\n")
                
            f.write("\n### By Confidence\n")
            for conf, count in stats_confidence.items():
                f.write(f"- {conf}: {count}\n")
                
            f.write("\n### By Category\n")
            for cat, count in sorted(stats_category.items(), key=lambda x: x[1], reverse=True):
                f.write(f"- {cat}: {count}\n")
                
            f.write("\n## Top 20 Highest-Risk Findings\n")
            high_risk = [x for x in all_findings if x["severity"] in ["critical", "high"] and x["confidence"] == "high_confidence"]
            for idx, fnd in enumerate(high_risk[:20], 1):
                f.write(f"{idx}. `{fnd['file']}:{fnd['line']}` [{fnd['category']}]\n")
                f.write(f"   - **Snippet:** `{fnd['snippet']}`\n")
                f.write(f"   - **Review Question:** {fnd['suggested_review_question']}\n\n")
                
            f.write("## Recommendation\n")
            f.write("⚠️ **WARNING:** These findings are advisory review candidates, not automatically proven bugs. They indicate places where code *thinks* it is still a standalone process.\n\n")
            if high_risk:
                f.write("We recommend creating a targeted TD (Tech Debt) task to manually review the top critical/high findings, especially focusing on `exit(`, `fatalError(`, socket binding, and `CommandLine.arguments` within the `anigmad` target.\n")

    if gate_failed:
        sys.exit(1)
        
    sys.exit(0)

if __name__ == "__main__":
    main()
