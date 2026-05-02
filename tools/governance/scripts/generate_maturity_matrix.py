#!/usr/bin/env python3
# Scripts/generate_maturity_matrix.py
# Anigma Module Maturity & Refinement Diagnostic

import os
import re
import sys
import subprocess

# --- Configuration & Colors ---
BOLD = '\033[1m'
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

TIER_1 = {"GovernanceCore", "DoctrineCore", "AnigmaPrimitives", "ContractsCore", "SecurityEventsManager", "TelemetryCore"}
TIER_2 = {"AnigmaCore", "PlatformCore", "DatabaseCore", "StorageCore", "ExecutionCore", "InferenceCore", "CathedralModule", "CapabilityCore", "AnigmaSystemSpine", "GovernedMigrationCore"}
TIER_3 = {"HarmoniaModule", "DiaplasionModule", "AccessumModule", "OutlineumModule", "PragmaModule", "ConexusModule", "CodexModule", "TranscriptumModule", "ObservatoriumModule", "PolytroposModule", "VectorumModule", "PraxisModule"}

WHITELIST = ["CHarfBuzz", "CFreeType", "CPDFium", "Scripts", "Vendor", "Demo"]

class ModuleMetrics:
    def __init__(self, name, tier):
        self.name = name
        self.tier = tier
        self.arch_score = 100
        self.concurrency_score = 100
        self.design_score = 100
        self.parity_score = 0  # 0 or 100
        self.violations = []

    @property
    def overall_maturity(self):
        # Weighted average
        score = (self.arch_score * 0.4) + (self.concurrency_score * 0.3) + (self.design_score * 0.1) + (self.parity_score * 0.2)
        return round(score / 20) # 1-5 Scale

def get_modules():
    modules = []
    for path in ["Packages", "Sources"]:
        if os.path.exists(path):
            for d in os.listdir(path):
                if os.path.isdir(os.path.join(path, d)) and d not in WHITELIST:
                    if d in TIER_1: tier = 1
                    elif d in TIER_2: tier = 2
                    elif d in TIER_3: tier = 3
                    else: tier = 0 # Untiered/App
                    modules.append(ModuleMetrics(d, tier))
    return sorted(modules, key=lambda x: (x.tier, x.name))

def check_architecture(modules, package_content):
    def get_deps(name):
        pattern = rf'\.target\(\s*name:\s*"{name}"(.*?)\)'
        match = re.search(pattern, package_content, re.DOTALL)
        if not match: return set()
        dep_match = re.search(r'dependencies:\s*\[(.*?)\]', match.group(1), re.DOTALL)
        if not dep_match: return set()
        return set(re.findall(r'"([^"]+)"', dep_match.group(1)))

    all_tier_3 = TIER_3
    all_tier_2 = TIER_2
    
    for m in modules:
        deps = get_deps(m.name)
        if m.tier == 1:
            forbidden = deps & (TIER_2 | TIER_3)
            if forbidden: 
                m.arch_score -= 50
                m.violations.append(f"Tier 1 depends on T2/T3: {forbidden}")
        elif m.tier == 2:
            forbidden = deps & TIER_3
            if forbidden:
                m.arch_score -= 50
                m.violations.append(f"Tier 2 depends on T3: {forbidden}")
        elif m.tier == 3:
            forbidden = (deps & TIER_3) - {m.name}
            if forbidden:
                m.arch_score -= 30
                m.violations.append(f"Tier 3 tightly coupled: {forbidden}")

def check_concurrency(modules, project_root):
    # Static patterns check
    for m in modules:
        m_path = None
        for p in ["Packages", "Sources"]:
            test_path = os.path.join(project_root, p, m.name)
            if os.path.exists(test_path):
                m_path = test_path
                break
        
        if not m_path: continue

        # Count violations in module
        try:
            # Check for legacy GCD and global mutability
            cmd = f"grep -rE 'DispatchQueue|NSLock|var [a-zA-Z0-9]+ = ' {m_path} | grep '.swift' | wc -l"
            count = int(subprocess.check_output(cmd, shell=True).decode().strip())
            m.concurrency_score -= min(count * 5, 60)
            if count > 0: m.violations.append(f"{count} legacy concurrency patterns")
        except: pass

def check_design(modules, project_root):
    for m in modules:
        # Only check design for UI/App modules
        if any(x in m.name for x in ["UI", "App", "Console", "View"]):
            m_path = os.path.join(project_root, "Packages" if m.tier != 0 else "Sources", m.name)
            if not os.path.exists(m_path): continue
            
            try:
                cmd = f"grep -rn 'Color\.' {m_path} | grep -v 'Bauhaus' | wc -l"
                colors = int(subprocess.check_output(cmd, shell=True).decode().strip())
                m.design_score -= min(colors * 2, 100)
                if colors > 0: m.violations.append(f"{colors} hardcoded colors")
            except: pass
        else:
            m.design_score = 100 # Not applicable

def check_parity(modules, project_root):
    for m in modules:
        if os.path.exists(os.path.join(project_root, "Tests", f"{m.name}Tests")) or \
           os.path.exists(os.path.join(project_root, "Tests", f"{m.name}sTests")):
            m.parity_score = 100
        else:
            m.parity_score = 0
            m.violations.append("Missing test suite")

def get_color_for_score(score):
    if score >= 90: return GREEN
    if score >= 70: return YELLOW
    return RED

def get_maturity_label(level):
    labels = ["-", "DRAFT", "ACTIVE", "STABLE", "HIGH-ASSURANCE", "CANONICAL"]
    colors = [NC, RED, YELLOW, BLUE, CYAN, GREEN]
    return f"{BOLD}{colors[level]}{labels[level]}{NC}"

def main():
    project_root = os.getcwd()
    with open("Package.swift", "r") as f:
        package_content = f.read()

    modules = get_modules()
    
    print(f"\n{BOLD}{BLUE}🔍 GENERATING ANIGMA MATURITY MATRIX...{NC}")
    
    check_architecture(modules, package_content)
    check_concurrency(modules, project_root)
    check_design(modules, project_root)
    check_parity(modules, project_root)

    # Print Table
    print(f"\n{BOLD}{'MODULE':<25} | {'T':<2} | {'ARC':<4} | {'CON':<4} | {'DSN':<4} | {'PAR':<4} | {'MATURITY'}{NC}")
    print("-" * 85)

    total_maturity = 0
    
    for m in modules:
        a_c = get_color_for_score(m.arch_score)
        c_c = get_color_for_score(m.concurrency_score)
        d_c = get_color_for_score(m.design_score)
        p_c = get_color_for_score(m.parity_score)
        
        maturity = m.overall_maturity
        total_maturity += maturity
        
        print(f"{m.name:<25} | {m.tier:<2} | {a_c}{m.arch_score:>3}%{NC} | {c_c}{m.concurrency_score:>3}%{NC} | {d_c}{m.design_score:>3}%{NC} | {p_c}{m.parity_score:>3}%{NC} | {get_maturity_label(maturity)}")

    project_avg = round(total_maturity / len(modules), 1)
    print("-" * 85)
    print(f"{BOLD}OVERALL PROJECT MATURITY: {get_maturity_label(int(project_avg))} ({project_avg}/5.0){NC}\n")

    # Show top violations
    print(f"{BOLD}CRITICAL REMEDIATION PATHS:{NC}")
    for m in modules:
        if m.overall_maturity <= 2 and m.violations:
            print(f"  {RED}• {m.name}{NC}: {', '.join(m.violations[:3])}")

if __name__ == "__main__":
    main()
