#!/usr/bin/env python3
import os
import re
import json
import argparse
import time
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.anigma_common.repo import repo_root, repo_relative, iter_repo_files
from scripts.anigma_common.io import write_json_stable
from scripts.anigma_common.findings import stable_finding_id
from scripts.anigma_common.ignore import IGNORE_DIRS

# Scanner Metadata
SCANNER_NAME = "anigma_dead_code_audit"
SCANNER_VERSION = "2.0.0"
RULES_VERSION = "2026-05-05.2"

# Constants
REPO_ROOT = repo_root()
BUILD_DIR = REPO_ROOT / ".build"
DEFAULT_JSON_OUT = BUILD_DIR / "anigma-dead-code-audit.json"
DATE_STR = time.strftime("%Y-%m-%d", time.gmtime())
DEFAULT_PROOF_OUT = REPO_ROOT / f"Docs/proofs/dead-code-audit-{DATE_STR}.md"

# Regex for Swift declarations
# Group 1: Kind (struct, class, etc.), Group 2: Name
DECL_REGEX = re.compile(
    r'^\s*(?:public|open|internal|fileprivate|private)?\s*(?:static|class)?\s*'
    r'(struct|class|actor|enum|protocol|func|var|let)\s+'
    r'([a-zA-Z_][a-zA-Z0-9_]*)',
    re.MULTILINE
)

# Attributes that protect symbols
PROTECT_ATTRIBUTES = [
    "@objc", "@IBAction", "@IBOutlet", "@NSApplicationMain", "@UIApplicationMain",
    "@MainActor", "@discardableResult", "@available", "@frozen", "@propertyWrapper",
    "@resultBuilder", "@State", "@Binding", "@Environment", "@EnvironmentObject",
    "@StateObject", "@ObservedObject", "@AppStorage", "@SceneStorage", "@FocusState",
    "@GestureState", "@Published", "@Observable", "@ObservationIgnored"
]

# Names that are always protected
PROTECTED_NAMES = [
    "main", "CodingKeys", "PreviewProvider", "init", "deinit", "deinit()",
    "setUp", "tearDown", "setUpWithError", "tearDownWithError", "body",
    "allTests", "linuxTests"
]

# Patterns for files to exclude
EXCLUDE_DIRS = [
    ".build", "DerivedData", "Docs", "Generated", "Fixtures", 
    "ExternalResearch", "__MACOSX", ".DS_Store", "Vendor", ".git", "scripts"
]

def get_swift_files(root_dir, include_tests=False):
    swift_files = []
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS or "fixtures" in d]
        if not include_tests and "Tests" in root:
            continue
        for f in files:
            if f.endswith(".swift"):
                swift_files.append(Path(root) / f)
    return swift_files

def parse_declarations(file_path):
    decls = []
    try:
        content = file_path.read_text()
        # Strip comments to avoid false positives
        content = re.sub(r'//.*', '', content)
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        
        lines = content.splitlines()
        for i, line in enumerate(lines):
            # Check for attributes on the previous line or same line
            is_protected = any(attr in line for attr in PROTECT_ATTRIBUTES)
            if i > 0 and any(attr in lines[i-1] for attr in PROTECT_ATTRIBUTES):
                is_protected = True
                
            matches = DECL_REGEX.finditer(line)
            for match in matches:
                kind = match.group(1)
                name = match.group(2)
                
                # Determine if it is a high-confidence candidate for Batch 003
                # - Types, protocols, functions: Yes
                # - static/class members: Yes
                # - top-level var/let: Yes
                # - instance var/let: No (defer until brace-depth)
                
                is_static_or_class = "static" in line or "class" in line
                is_top_level = not line.startswith(" ") and not line.startswith("\t")
                
                is_candidate_type = kind in ["struct", "class", "actor", "enum", "protocol", "func"]
                is_candidate_member = is_static_or_class
                is_candidate_top_level = is_top_level
                
                is_eligible = is_candidate_type or is_candidate_member or is_candidate_top_level
                
                # Further protection checks
                protected = is_protected or name in PROTECTED_NAMES
                if line.strip().startswith("override"):
                    protected = True
                if "public" in line or "open" in line:
                    protected = True
                    
                # We also exclude SwiftUI's body and Codable's CodingKeys
                if name == "body" and kind == "var": protected = True
                if name == "CodingKeys" and kind == "enum": protected = True

                decls.append({
                    "name": name,
                    "kind": kind,
                    "file": repo_relative(file_path),
                    "line": i + 1,
                    "protected": protected,
                    "eligible": is_eligible
                })
    except Exception as e:
        print(f"Warning: Failed to parse {file_path}: {e}")
    return decls

def find_references(decl_names, swift_files, include_tests=False):
    # Use ripgrep if available for speed
    has_rg = subprocess.run(["which", "rg"], capture_output=True).returncode == 0
    ref_counts = {name: 0 for name in decl_names}
    
    if has_rg:
        # Build a temporary file with names to search to avoid shell arg limits
        with open(BUILD_DIR / "dead-code-names.txt", "w") as f:
            for name in decl_names:
                f.write(name + "\n")
        
        try:
            # rg -w matches whole words
            # --count-matches returns number of matches per file
            # We search the root directory but exclude common patterns
            cmd = ["rg", "-w", "-f", str(BUILD_DIR / "dead-code-names.txt"), "--json", "--type", "swift", str(REPO_ROOT)]
            
            # Recursive exclusions
            for d in EXCLUDE_DIRS:
                cmd.extend(["-g", f"!**/{d}/**"])
                cmd.extend(["-g", f"!**/{d}"])
            
            if not include_tests:
                cmd.extend(["-g", "!**/Tests/**"])
                cmd.extend(["-g", "!**/tests/**"])
                cmd.extend(["-g", "!**/TestSupport/**"])
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            for line in result.stdout.splitlines():
                try:
                    data = json.loads(line)
                    if data.get("type") == "match":
                        for submatch in data["data"]["submatches"]:
                            name_match = submatch["match"]["text"]
                            if name_match in ref_counts:
                                ref_counts[name_match] += 1
                except:
                    continue
        except Exception as e:
            print(f"Error running rg: {e}")
    else:
        # Fallback to slow Python-based search
        print("Ripgrep not found, falling back to Python search (slower)...")
        for f in swift_files:
            try:
                content = f.read_text()
                # Crude whole-word search
                for name in decl_names:
                    ref_counts[name] += len(re.findall(r'\b' + re.escape(name) + r'\b', content))
            except:
                continue
                
    return ref_counts

def classify_decls(decls, ref_counts, manifest_refs):
    results = []
    # Map name to how many times it's declared
    decl_counts = {}
    for d in decls:
        decl_counts[d["name"]] = decl_counts.get(d["name"], 0) + 1
        
    for d in decls:
        name = d["name"]
        count = ref_counts.get(name, 0)
        
        # Determine confidence and reason
        classification = "unknown"
        reason = ""
        confidence = "low"
        
        if not d["eligible"]:
            classification = "ignored"
            reason = "non_top_level_instance_property"
            confidence = "none"
        elif d["protected"] or name in manifest_refs:
            classification = "protected"
            reason = "protected_by_attribute_or_name"
            confidence = "high"
        elif count > decl_counts[name]:
            classification = "reachable"
            reason = "multiple_references_detected"
            confidence = "high"
        elif "Test" in d["file"]:
            classification = "test_only"
            reason = "in_test_directory"
            confidence = "medium"
        else:
            classification = "candidate_dead"
            reason = f"found_{count}_total_matches_for_{decl_counts[name]}_declarations"
            # count == decl_counts[name] means zero references outside of declarations
            if count <= decl_counts[name]:
                confidence = "high"
            elif count <= decl_counts[name] + 1:
                confidence = "medium"
            else:
                confidence = "low"
            
        # Refine confidence based on common false positive patterns
        if classification == "candidate_dead":
            if name.startswith("test") and d["kind"] == "func":
                classification = "test_only"
                reason = "looks_like_test_function"
                confidence = "medium"

        # Map to requested fields
        results.append({
            "symbol": name,
            "declaration_kind": d["kind"],
            "file": d["file"],
            "line": d["line"],
            "classification": classification,
            "reason": reason,
            "confidence": f"{confidence}_confidence_candidate" if classification == "candidate_dead" else classification,
            "reference_count": count
        })
    for item in results:
        item["finding_id"] = stable_finding_id({"scanner": SCANNER_NAME, "rule": item["classification"], "path": item["file"], "line": item["line"], "symbol": item["symbol"]})
        item["source"] = "dead-code-audit"
        item["scanner_name"] = SCANNER_NAME
        item["scanner_version"] = SCANNER_VERSION
        item["rules_version"] = RULES_VERSION
        item["rule_id"] = item["classification"]
        item["rule_version"] = 1
        item["category"] = item["classification"]
        item["baseline_key"] = f"{item['file']}:{item['declaration_kind']}:{item['symbol']}"
        item["language"] = "swift"
        item["target"] = get_module_name(item["file"])
        item["package_root"] = "anigma"
        item["rationale"] = item.get("reason", "")
        item["suggested_review_question"] = "Does this symbol still have reachable use?"
        item["snippet"] = item["symbol"]
        item["classification"] = item["classification"]
        item["path"] = item["file"]
    return results

def get_module_name(file_path):
    path = Path(file_path)
    parts = path.parts
    if "Sources" in parts:
        idx = parts.index("Sources")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    if "Packages" in parts:
        idx = parts.index("Packages")
        if idx + 2 < len(parts):
            return parts[idx + 2]
    # Default: try to find the module name from the first part of the relative path if not standard
    if parts:
        return parts[0]
    return "unknown"

def get_manifest_refs():
    # Search Package.swift for identifiers
    package_swift = REPO_ROOT / "anigma/Package.swift"
    if not package_swift.exists():
        package_swift = REPO_ROOT / "Package.swift"
        
    if not package_swift.exists():
        return set()
        
    try:
        content = package_swift.read_text()
        return set(re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', content))
    except:
        return set()

def write_proof(results, swift_files, mode, proof_path):
    candidates = [r for r in results if r["classification"] == "candidate_dead"]
    protected = [r for r in results if r["classification"] == "protected"]
    reachable = [r for r in results if r["classification"] == "reachable"]
    
    command_run = " ".join(os.sys.argv)
    
    with open(proof_path, "w") as f:
        f.write("# Dead Code Audit Report\n\n")
        f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%SZ', time.gmtime())}\n")
        f.write(f"Command: `python3 {command_run}`\n")
        f.write(f"Mode: {mode}\n\n")
        
        f.write("## Summary\n")
        f.write(f"- Swift files scanned: {len(swift_files)}\n")
        f.write(f"- Total declarations found: {len(results)}\n")
        f.write(f"- Protected declarations: {len(protected)}\n")
        f.write(f"- Reachable declarations: {len(reachable)}\n")
        f.write(f"- **Candidate dead declarations: {len(candidates)}**\n\n")
        
        # Stratification
        f.write("## Stratification\n\n")
        
        # By Confidence
        f.write("### By Confidence\n")
        conf_counts = {}
        for c in candidates:
            conf = c["confidence"]
            conf_counts[conf] = conf_counts.get(conf, 0) + 1
        for conf, count in sorted(conf_counts.items()):
            f.write(f"- {conf}: {count}\n")
            
        # By Category
        f.write("\n### By Source Category\n")
        cat_counts = {"production": 0, "tests": 0, "app": 0, "scripts/generated": 0, "unknown": 0}
        for c in candidates:
            if "Tests" in c["file"]: cat_counts["tests"] += 1
            elif "App" in c["file"]: cat_counts["app"] += 1
            elif "scripts" in c["file"] or "Generated" in c["file"]: cat_counts["scripts/generated"] += 1
            elif "anigma" in c["file"] or "Sources" in c["file"]: cat_counts["production"] += 1
            else: cat_counts["unknown"] += 1
        for cat, count in cat_counts.items():
            f.write(f"- {cat}: {count}\n")

        # By Kind
        f.write("\n### By Declaration Kind\n")
        kind_counts = {}
        for c in candidates:
            kind = c["declaration_kind"]
            kind_counts[kind] = kind_counts.get(kind, 0) + 1
        for kind, count in sorted(kind_counts.items(), key=lambda x: x[1], reverse=True):
            f.write(f"- {kind}: {count}\n")
            
        # By Module (Top 10)
        f.write("\n### By Module (Top 10)\n")
        mod_counts = {}
        for c in candidates:
            mod = get_module_name(c["file"])
            mod_counts[mod] = mod_counts.get(mod, 0) + 1
        for mod, count in sorted(mod_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            f.write(f"- {mod}: {count}\n")

        if candidates:
            f.write("\n## High Confidence Candidates (Top 100)\n")
            f.write("| Symbol | Kind | Location | Ref Count |\n")
            f.write("|---|---|---|---|\n")
            high_conf = [c for c in candidates if "high" in c["confidence"]]
            # Sort high conf by symbol name
            high_conf.sort(key=lambda x: x["symbol"])
            for c in high_conf[:100]:
                f.write(f"| `{c['symbol']}` | {c['declaration_kind']} | `{c['file']}:{c['line']}` | {c['reference_count']} |\n")
            if len(high_conf) > 100:
                f.write(f"\n... and {len(high_conf) - 100} more high confidence candidates.\n")
        else:
            f.write("✅ No candidate dead code found.\n")
            
        f.write("\n--- \n*Note: This report is advisory. Candidates should be reviewed by a human before removal. Reference counts are textual upper bounds (strings and comments may inflate reachability).*")

def main():
    parser = argparse.ArgumentParser(description="Conservative Swift Dead Code Audit")
    parser.add_argument("--mode", choices=["advisory", "gate"], default="advisory", help="Audit mode")
    parser.add_argument("--baseline", type=Path, help="Baseline JSON file for gate mode")
    parser.add_argument("--write-baseline", type=Path, help="Write current findings to baseline file")
    parser.add_argument("--json-out", type=Path, default=DEFAULT_JSON_OUT, help="Path for JSON output")
    parser.add_argument("--proof-out", type=Path, default=DEFAULT_PROOF_OUT, help="Path for Markdown proof")
    parser.add_argument("--include-tests", action="store_true", help="Include Test directories in scan")
    parser.add_argument("--fail-on-candidates", action="store_true", help="Fail if any candidates found (advisory mode)")
    parser.add_argument("--no-proof", action="store_true", help="Do not emit Markdown proof")
    
    parser.add_argument("--path", type=Path, default=REPO_ROOT, help="Root directory to scan")
    
    args = parser.parse_args()
    
    BUILD_DIR.mkdir(exist_ok=True)
    
    print(f"Starting dead code audit in {args.mode} mode...")
    
    swift_files = get_swift_files(args.path, include_tests=args.include_tests)
    print(f"Found {len(swift_files)} Swift files.")
    
    all_decls = []
    for f in swift_files:
        all_decls.extend(parse_declarations(f))
    print(f"Parsed {len(all_decls)} declarations.")
    
    manifest_refs = get_manifest_refs()
    
    decl_names = list(set(d["name"] for d in all_decls))
    ref_counts = find_references(decl_names, swift_files, include_tests=args.include_tests)
    
    results = classify_decls(all_decls, ref_counts, manifest_refs)
    
    # Sort results deterministically
    results.sort(key=lambda x: (x["file"], x["line"], x["symbol"]))
    
    total_declarations = len(results)
    analyzed_records = len(results)
    protected_records = [r for r in results if r["classification"] == "protected"]
    reachable_records = [r for r in results if r["classification"] == "reachable"]
    candidate_records = [r for r in results if r["classification"] == "candidate_dead"]
    high_confidence_candidates = [r for r in candidate_records if "high" in r["confidence"]]
    print(f"Analyzed {analyzed_records} declarations.")
    print(f"Protected records: {len(protected_records)}")
    print(f"Reachable records: {len(reachable_records)}")
    print(f"Candidate records: {len(candidate_records)}")
    print(f"High-confidence candidates: {len(high_confidence_candidates)}")
    
    # JSON Output
    output = {
        "scanner": SCANNER_NAME,
        "scanner_version": SCANNER_VERSION,
        "rules_version": RULES_VERSION,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total_declarations": total_declarations,
        "analyzed_records": analyzed_records,
        "protected_records": len(protected_records),
        "reachable_records": len(reachable_records),
        "candidate_records": len(candidate_records),
        "high_confidence_candidates": len(high_confidence_candidates),
        "findings": results
    }
    write_json_stable(args.json_out, output)
        
    def get_candidate_key(c):
        # Strengthened baseline key: path | kind | symbol
        return f"{c['file']}:{c['declaration_kind']}:{c['symbol']}"

    # Baseline
    if args.write_baseline:
        args.write_baseline.parent.mkdir(parents=True, exist_ok=True)
        write_json_stable(args.write_baseline, [get_candidate_key(c) for c in candidate_records])
        print(f"Baseline written to {args.write_baseline}")
        
    # Proof Output
    if not args.no_proof:
        args.proof_out.parent.mkdir(parents=True, exist_ok=True)
        write_proof(results, swift_files, args.mode, args.proof_out)
        print(f"Proof report written to {args.proof_out}")
        
    # Exit logic
    if args.mode == "gate":
        if not args.baseline or not args.baseline.exists():
            print("Error: Baseline file required for gate mode.")
            exit(2)
        
        with open(args.baseline, "r") as f:
            baseline_keys = set(json.load(f))
            
        # Gate mode: Only fail on NEW HIGH CONFIDENCE candidates
        new_high_conf = [c for c in candidate_records 
                        if "high" in c["confidence"] 
                        and get_candidate_key(c) not in baseline_keys]
        
        if new_high_conf:
            print(f"Gate failed: {len(new_high_conf)} new high-confidence dead code candidates found.")
            for c in new_high_conf:
                print(f"  - {c['symbol']} ({c['declaration_kind']}) in {c['file']}:{c['line']}")
            exit(1)
        else:
            print("Gate passed: No new high-confidence dead code candidates found.")
            exit(0)
            
    if args.fail_on_candidates and candidate_records:
        exit(1)
        
    exit(0)

if __name__ == "__main__":
    main()
