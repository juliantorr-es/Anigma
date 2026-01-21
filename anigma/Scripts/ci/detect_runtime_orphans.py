#!/usr/bin/env python3
# Scripts/ci/detect_runtime_orphans.py
# Diagnostic tool to identify systems and actors that should be on the runtime

import os
import re
import sys

# --- Configuration & Colors ---
BOLD = '\033[1m'
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'

TIER_1 = {"GovernanceCore", "DoctrineCore", "AnigmaPrimitives", "ContractsCore", "SecurityEventsManager", "TelemetryCore"}
TIER_2 = {"AnigmaCore", "PlatformCore", "DatabaseCore", "StorageCore", "ExecutionCore", "InferenceCore", "CathedralModule", "CapabilityCore", "AnigmaSystemSpine", "GovernedMigrationCore"}

class RuntimeElement:
    def __init__(self, name, type, file_path, tier):
        self.name = name
        self.type = type # 'System' or 'Actor'
        self.file_path = file_path
        self.tier = tier
        self.is_registered = False

def get_module_tier(module_name):
    if module_name in TIER_1: return 1
    if module_name in TIER_2: return 2
    return 3 # Assume Tier 3 for others

def analyze_runtime():
    project_root = os.getcwd()
    elements = []
    registered_systems = set()
    
    # 1. Find all registrations
    print(f"{BOLD}{BLUE}🔍 Scanning for Runtime Registrations...{NC}")
    for root, _, files in os.walk(project_root):
        if any(x in root for x in [".build", ".git", "Tests"]): continue
        for file in files:
            if file.endswith(".swift"):
                with open(os.path.join(root, file), 'r') as f:
                    content = f.read()
                    # Find registerSystem(SystemName()) or registerSystem(Name.self)
                    matches = re.findall(r'registerSystem\s*\(\s*([A-Za-z0-9_]+)\s*\(', content)
                    for m in matches: registered_systems.add(m)
                    
                    # Also look for Type-based registration
                    matches_type = re.findall(r'registerSystem\s*\(\s*([A-Za-z0-9_]+)\.self', content)
                    for m in matches_type: registered_systems.add(m)

    # 2. Find all System/Actor definitions
    print(f"{BOLD}{BLUE}🔍 Scanning for Runtime Elements (Systems/Actors)...{NC}")
    for root, _, files in os.walk(project_root):
        if any(x in root for x in [".build", ".git", "Tests", "ThirdParty"]): continue
        
        # Determine module name and tier
        parts = root.split(os.sep)
        module_name = "Unknown"
        if "Packages" in parts:
            idx = parts.index("Packages")
            if idx + 1 < len(parts): module_name = parts[idx+1]
        elif "Sources" in parts:
            idx = parts.index("Sources")
            if idx + 1 < len(parts): module_name = parts[idx+1]
            
        tier = get_module_tier(module_name)

        for file in files:
            if file.endswith(".swift"):
                path = os.path.join(root, file)
                with open(path, 'r') as f:
                    content = f.read()
                    
                    # Find Systems: struct Name: System
                    systems = re.findall(r'struct\s+([A-Za-z0-9_]+)\s*:\s*(?:Async)?System', content)
                    for s in systems:
                        el = RuntimeElement(s, "System", path, tier)
                        if s in registered_systems: el.is_registered = True
                        elements.append(el)
                        
                    # Find Actors: actor Name
                    actors = re.findall(r'actor\s+([A-Za-z0-9_]+)', content)
                    for a in actors:
                        # Exclude standard library/common helper names if needed
                        if a in ["DatabaseActor", "PlatformRuntime", "World"]: continue
                        elements.append(RuntimeElement(a, "Actor", path, tier))

    # 3. Report
    print(f"\n{BOLD}{'ELEMENT':<30} | {'TYPE':<8} | {'TIER':<2} | {'STATUS'}{NC}")
    print("-" * 60)
    
    orphans = 0
    misplaced = 0
    
    # Define local colors just in case global scope is missed
    L_CYAN = '\033[0;36m'
    L_NC = '\033[0m'
    L_RED = '\033[0;31m'
    L_GREEN = '\033[0;32m'

    for el in sorted(elements, key=lambda x: (x.is_registered, x.tier, x.name)):
        status = f"{L_GREEN}REGISTERED{L_NC}" if el.is_registered else f"{L_RED}ORPHAN{L_NC}"
        if el.type == "Actor": status = f"{L_CYAN}STANDALONE{L_NC}" # Actors don't always register
        
        # Alert if System is in Tier 1
        tier_str = str(el.tier)
        if el.tier == 1:
            tier_str = f"{RED}{el.tier} (ILLEGAL){NC}"
            misplaced += 1
        
        if el.type == "System" and not el.is_registered:
            orphans += 1
            
        print(f"{el.name:<30} | {el.type:<8} | {tier_str:<2} | {status}")

    print(f"\n{BOLD}{BLUE}=== RUNTIME ORPHAN SUMMARY ==={NC}")
    print(f"  Unregistered Systems: {RED}{orphans}{NC}")
    print(f"  Misplaced Elements (T1): {RED}{misplaced}{NC}")
    
    if orphans > 0 or misplaced > 0:
        print(f"\n{YELLOW}💡 Advice:{NC}")
        print("  - Systems must be registered in their Module's 'register' function.")
        print("  - Actors should ideally live in Tier 2 or be managed by a Tier 2 Authority.")
        print("  - Tier 1 should contain NO logic elements (Systems/Actors).")

if __name__ == "__main__":
    analyze_runtime()
