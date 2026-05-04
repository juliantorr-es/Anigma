#!/usr/bin/env python3
# Tools/governance/scripts/validate_authority_bypasses_enhanced.py
# Enhanced Architecture Validator: Detect runtime authority bypasses with execute() pattern detection

import re
import sys
import os
from pathlib import Path

# --- Configuration ---
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
BOLD = '\033[1m'
NC = '\033[0m'

def main():
    print(f"\n{BOLD}{BLUE}=== ENHANCED AUTHORITY BYPASS VALIDATION (P1-Runtime-Architecture-Lockdown) ==={NC}")
    
    violations = 0
    
    # Find all Swift files in the project
    project_root = Path(__file__).parent.parent.parent.parent
    swift_files = []
    
    # Search in common source directories
    source_dirs = [
        project_root / "anigma" / "Packages",
        project_root / "anigma" / "Sources",
    ]
    
    for source_dir in source_dirs:
        if source_dir.exists():
            swift_files.extend(source_dir.rglob("*.swift"))
    
    print(f"Scanning {len(swift_files)} Swift files for authority bypasses...")
    
    # Check 1: Direct DatabaseActor usage outside DatabaseCore/DatabaseAuthority
    print(f"\n{BOLD}Check 1: DatabaseActor usage{NC}")
    database_actor_pattern = re.compile(r'DatabaseActor\s*\(')
    
    for swift_file in swift_files:
        try:
            content = swift_file.read_text()
            matches = database_actor_pattern.findall(content)
            
            if matches:
                # Check if this is in DatabaseCore or DatabaseAuthority (allowed)
                file_path = str(swift_file)
                if "DatabaseAuthority" in file_path or "DatabaseCore" in file_path:
                    continue
                
                # Check if this is in a test file (allowed for testing)
                if "Tests" in file_path or "Test" in swift_file.name:
                    continue
                
                print(f"{RED}❌ AUTHORITY BYPASS{NC}: Direct DatabaseActor usage in {swift_file}")
                print(f"   Line: {content.count('\n', 0, content.find('DatabaseActor')) + 1}")
                violations += 1
        except Exception as e:
            print(f"Warning: Could not read {swift_file}: {e}")
    
    # Check 2: Capability modules importing DatabaseCore directly
    print(f"\n{BOLD}Check 2: Capability module DatabaseCore imports{NC}")
    capability_modules = ["HarmoniaModule", "DiaplasionModule", "AccessumModule", 
                          "OutlineumModule", "PragmaModule", "ConexusModule",
                          "CodexModule", "TranscriptumModule", "ObservatoriumModule",
                          "PolytroposModule", "VectorumModule", "PraxisModule"]
    
    database_core_import = re.compile(r'import\s+DatabaseCore')
    
    for swift_file in swift_files:
        try:
            content = swift_file.read_text()
            
            # Check if this is a capability module
            is_capability_module = any(
                f"{module}" in str(swift_file) 
                for module in capability_modules
            )
            
            if is_capability_module and database_core_import.search(content):
                print(f"{RED}❌ AUTHORITY BYPASS{NC}: Capability module importing DatabaseCore directly")
                print(f"   File: {swift_file}")
                violations += 1
        except Exception as e:
            print(f"Warning: Could not read {swift_file}: {e}")
    
    # Check 3: Direct database execute calls outside DatabaseAuthority
    print(f"\n{BOLD}Check 3: Direct database execute bypasses{NC}")
    execute_patterns = [
        r'\.execute\(',
        r'\.executeAsync\('
    ]
    
    for swift_file in swift_files:
        try:
            content = swift_file.read_text()
            file_path = str(swift_file)
            
            # Skip DatabaseAuthority and DatabaseCore internals
            if "DatabaseAuthority" in file_path or "DatabaseCore" in file_path:
                continue
            
            # Skip test files
            if "Tests" in file_path or "Test" in swift_file.name:
                continue
            
            # Check for execute patterns
            for pattern in execute_patterns:
                if re.search(pattern, content):
                    # Make sure it's not a comment or string literal (simple check)
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if re.search(pattern, line) and not line.strip().startswith('//'):
                            print(f"{RED}❌ AUTHORITY BYPASS{NC}: Direct database execute call outside DatabaseAuthority")
                            print(f"   File: {swift_file}")
                            print(f"   Line: {i + 1}")
                            violations += 1
                            break
        except Exception as e:
            print(f"Warning: Could not read {swift_file}: {e}")

    # Check 4: Direct evidence writes outside EvidenceAuthority
    print(f"\n{BOLD}Check 4: Evidence system bypasses{NC}")
    evidence_write_patterns = [
        r'insertEvidence\(',
        r'writeEvidence\(',
        r'appendEvidence\(',
        r'saveEvidence\('
    ]
    
    for swift_file in swift_files:
        try:
            content = swift_file.read_text()
            
            # Skip EvidenceAuthority itself
            if "EvidenceAuthority" in str(swift_file):
                continue
            
            for pattern in evidence_write_patterns:
                if re.search(pattern, content):
                    print(f"{RED}❌ AUTHORITY BYPASS{NC}: Direct evidence write outside EvidenceAuthority")
                    print(f"   File: {swift_file}")
                    print(f"   Pattern: {pattern}")
                    violations += 1
                    break
        except Exception as e:
            print(f"Warning: Could not read {swift_file}: {e}")

    # Summary
    print(f"\n{BOLD}=== SUMMARY ==={NC}")
    if violations > 0:
        print(f"{RED}❌ Found {violations} authority bypass violations.{NC}")
        print(f"\n{YELLOW}Remediation:{NC}")
        print("  1. Database mutations must route through DatabaseAuthority")
        print("  2. Capability modules should use PlatformRuntime, not DatabaseCore directly")
        print("  3. Evidence writes must route through EvidenceAuthority")
        print("  4. Direct .execute() calls must route through DatabaseAuthority.mutate()")
        print(f"\n{BOLD}Reference:{NC} Docs/ADR/0006-three-tier-runtime-architecture.md")
        return 1
    else:
        print(f"{GREEN}✅ No authority bypass violations detected.{NC}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
