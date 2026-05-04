#!/usr/bin/env python3
# Scripts/validate_tiers.py
# Anigma Architecture & Tier-Boundary Diagnostic Tool

import re
import sys
import os

# --- Configuration ---
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
BOLD = '\033[1m'
NC = '\033[0m'

# TIER DEFINITIONS (Per ADR-0006)
TIER_1 = {"GovernanceCore", "DoctrineCore", "AnigmaPrimitives", "ContractsCore", "SecurityEventsManager", "TelemetryCore", "LayoutEngineContracts"}
TIER_2 = {"AnigmaCore", "PlatformCore", "DatabaseCore", "StorageCore", "ExecutionCore", "InferenceCore", "CathedralModule", "CapabilityCore", "AnigmaSystemSpine", "GovernedMigrationCore", "LayoutEngineCapsule", "PDFLayoutExtract"}
TIER_3 = {"HarmoniaModule", "DiaplasionModule", "AccessumModule", "OutlineumModule", "PragmaModule", "ConexusModule", "CodexModule", "TranscriptumModule", "ObservatoriumModule", "PolytroposModule", "VectorumModule", "PraxisModule"}

def get_dependencies(target_name, package_content):
    pattern = rf'\.target\(\s*name:\s*"{target_name}"(.*?)\)'
    match = re.search(pattern, package_content, re.DOTALL)
    if not match:
        pattern = rf'\.executableTarget\(\s*name:\s*"{target_name}"(.*?)\)'
        match = re.search(pattern, package_content, re.DOTALL)
    
    if not match: return set()
    
    body = match.group(1)
    dep_match = re.search(r'dependencies:\s*\[(.*?)\]', body, re.DOTALL)
    if not dep_match: return set()
    
    return set(re.findall(r'"([^"]+)"', dep_match.group(1)))

def report_violation(tier, module, forbidden_deps):
    print(f"\n{RED}[ARCHITECTURE VIOLATION] Tier {tier} Boundary Breach{NC}")
    print(f"  {BOLD}Module:{NC} {module}")
    print(f"  {BOLD}Illegal Dependencies:{NC} {', '.join(forbidden_deps)}")
    
    if tier == 1:
        remediation = "Tier 1 (Policy) MUST NOT depend on Tier 2 (Platform) or Tier 3 (Capability). Move shared logic to AnigmaPrimitives."
    elif tier == 2:
        remediation = "Tier 2 (Platform) MUST NOT depend on Tier 3 (Capability). Tier 2 should only know about Tier 1 and internal Platform types."
    elif tier == 3:
        remediation = "Tier 3 (Capability) MUST NOT depend on other Tier 3 modules. Use Tier 2 ExecutionAuthority to coordinate between capabilities."
    
    print(f"  {BOLD}Remediation:{NC} {remediation}")
    print(f"  {BOLD}Reference:{NC} Docs/ADR/0006-three-tier-runtime-architecture.md")

def main():
    if not os.path.exists("Package.swift"):
        print(f"{RED}Error: Package.swift not found in root.{NC}")
        sys.exit(1)

    with open("Package.swift", "r") as f:
        content = f.read()

    print(f"\n{BOLD}{BLUE}=== ANIGMA TIER VALIDATION (ADR-0006) ==={NC}")
    violations = 0

    # Validate Tier 1
    for m in TIER_1:
        deps = get_dependencies(m, content)
        forbidden = deps & (TIER_2 | TIER_3)
        if forbidden:
            report_violation(1, m, forbidden)
            violations += 1

    # Validate Tier 2
    for m in TIER_2:
        deps = get_dependencies(m, content)
        forbidden = deps & TIER_3
        if forbidden:
            report_violation(2, m, forbidden)
            violations += 1

    # Validate Tier 3 (Decoupling)
    for m in TIER_3:
        deps = get_dependencies(m, content)
        forbidden = (deps & TIER_3) - {m}
        if forbidden:
            report_violation(3, m, forbidden)
            violations += 1

    print(f"\n{BOLD}{BLUE}=== SUMMARY ==={NC}")
    if violations == 0:
        print(f"{GREEN}✅ Architecture is clean. All tier boundaries respected.{NC}")
    else:
        print(f"{RED}❌ Found {violations} architectural boundary violations.{NC}")
        sys.exit(1)

if __name__ == "__main__":
    main()