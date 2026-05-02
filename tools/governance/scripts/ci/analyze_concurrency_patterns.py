#!/usr/bin/env python3
# Scripts/ci/analyze_concurrency_patterns.py
# Anigma Concurrency & Data Integrity Diagnostic Tool

import os
import re
import sys

# --- Configuration ---
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

RULES = {
    "SENDABLE_COMPONENT": {
        "pattern": r"(struct|class)\s+(\w+)\s*[:{]",
        "message": "Component is missing Sendable conformance.",
        "remediation": "Add ': Sendable' to the definition. All ECS components must be thread-safe.",
        "severity": "CRITICAL"
    },
    "CODABLE_COMPONENT": {
        "pattern": r"(struct|class)\s+(\w+)\s*[:{]",
        "message": "Component is missing Codable conformance.",
        "remediation": "Add ': Codable' for persistence. If this component should not be saved, add '// NonPersistent'.",
        "severity": "WARNING"
    },
    "LEGACY_DISPATCH": {
        "pattern": r"DispatchQueue\.(global|main)\.async",
        "message": "Detected legacy GCD usage.",
        "remediation": "Use 'Task { ... }' or '@MainActor' instead of DispatchQueue for Swift 6 compatibility.",
        "severity": "CRITICAL"
    },
    "MANUAL_LOCK": {
        "pattern": r"(NSLock|NSRecursiveLock)\(()",
        "message": "Detected manual locking mechanism.",
        "remediation": "Replace manual locks with 'actor' isolation or 'Mutex' (Swift 6.0+).",
        "severity": "WARNING"
    },
    "MUTABLE_GLOBAL": {
        "pattern": r"^var\s+\w+\s*[:=]",
        "message": "Global mutable state detected.",
        "remediation": "Wrap in a global actor like '@MainActor var' or use 'nonisolated(unsafe)' if thread-safety is guaranteed externally.",
        "severity": "CRITICAL"
    }
}

def print_header(title):
    print(f"\n{BOLD}{BLUE}{'='*80}{NC}")
    print(f"{BOLD}{BLUE} {title}{NC}")
    print(f"{BOLD}{BLUE}{'='*80}{NC}")

def report_violation(file_path, line_no, rule_id, context):
    rule = RULES[rule_id]
    color = RED if rule["severity"] == "CRITICAL" else YELLOW
    
    print(f"\n{color}[{rule['severity']}] {rule['message']}{NC}")
    print(f"  {BOLD}File:{NC} {file_path}:{line_no}")
    print(f"  {BOLD}Context:{NC} {context.strip()}")
    print(f"  {BOLD}Remediation:{NC} {rule['remediation']}")

def analyze_file(file_path):
    violations = 0
    with open(file_path, 'r') as f:
        try:
            lines = f.readlines()
        except UnicodeDecodeError:
            return 0

    content = "".join(lines)
    is_component_file = "/Components/" in file_path

    for i, line in enumerate(lines, 1):
        # Rule: Legacy Dispatch
        if re.search(RULES["LEGACY_DISPATCH"]["pattern"], line):
            report_violation(file_path, i, "LEGACY_DISPATCH", line)
            violations += 1
            
        # Rule: Manual Locks
        if re.search(RULES["MANUAL_LOCK"]["pattern"], line):
            report_violation(file_path, i, "MANUAL_LOCK", line)
            violations += 1

        # Rule: Mutable Global (only at start of line in global scope)
        if re.match(RULES["MUTABLE_GLOBAL"]["pattern"], line) and not file_path.endswith("Tests.swift"):
            report_violation(file_path, i, "MUTABLE_GLOBAL", line)
            violations += 1

    # Component-specific checks
    if is_component_file:
        defs = re.findall(r'(struct|class)\s+(\w+)\s*[:{]', content)
        for kind, name in defs:
            if "Sendable" not in content and "Component" not in content:
                # Find line number for the definition
                for i, line in enumerate(lines, 1):
                    if f"{kind} {name}" in line:
                        report_violation(file_path, i, "SENDABLE_COMPONENT", line)
                        violations += 1
                        break
            
            if "Codable" not in content and "Decodable" not in content and "NonPersistent" not in content:
                for i, line in enumerate(lines, 1):
                    if f"{kind} {name}" in line:
                        report_violation(file_path, i, "CODABLE_COMPONENT", line)
                        violations += 1
                        break

    return violations

def main():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    scan_dirs = ["Packages", "Sources"]
    
    print_header("ANIGMA CONCURRENCY & DATA INTEGRITY DIAGNOSTIC")
    
    total_violations = 0
    file_count = 0
    
    for scan_dir in scan_dirs:
        target_path = os.path.join(project_root, scan_dir)
        if not os.path.exists(target_path): continue
        
        for root, _, files in os.walk(target_path):
            if any(x in root for x in [".build", ".git", "Tests", "ThirdParty", "Generated"]):
                continue
            for file in files:
                if file.endswith(".swift"):
                    file_count += 1
                    total_violations += analyze_file(os.path.join(root, file))

    print_header("DIAGNOSTIC SUMMARY")
    print(f"  Files Scanned: {file_count}")
    print(f"  Total Violations: {total_violations}")
    
    if total_violations > 0:
        print(f"\n{RED}❌ Action Required: {total_violations} concurrency/integrity issues found.{NC}")
        print(f"{RED}Please address the CRITICAL violations before committing.{NC}\n")
        # sys.exit(1) # Un-comment to block commits
    else:
        print(f"\n{GREEN}✅ Perfect Score: No concurrency or data integrity patterns detected.{NC}\n")

if __name__ == "__main__":
    main()