#!/usr/bin/env python3
"""
validate_verification_profiles.py

Validate verification profiles manifest and check tool availability.

Usage:
    python3 Scripts/validate_verification_profiles.py              # Full validation
    python3 Scripts/validate_verification_profiles.py --verbose   # Verbose output
    python3 Scripts/validate_verification_profiles.py --check-tools  # Only tool check

Exit codes:
    0 = All validation passed
    1 = Validation errors (required tools missing or schema issues)
    2 = Only optional tool warnings (non-blocking)
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import yaml
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.absolute()
MANIFEST_PATH = REPO_ROOT / "Docs" / "manifests" / "verification-profiles.yaml"

# -----------------------------------------------------------------------------
# Results
# -----------------------------------------------------------------------------

class ValidationResult:
    """Collects validation results."""
    
    def __init__(self):
        self.passed: List[str] = []
        self.warnings: List[str] = []
        self.errors: List[str] = []
        self.tool_availability: Dict[str, Dict[str, Any]] = {}
    
    def is_valid(self) -> bool:
        return len(self.errors) == 0
    
    def has_warnings(self) -> bool:
        return len(self.warnings) > 0
    
    def exit_code(self) -> int:
        if self.has_errors():
            return 1
        if self.has_warnings():
            return 2
        return 0
    
    def has_errors(self) -> bool:
        return len(self.errors) > 0
    
    def add_passed(self, message: str):
        self.passed.append(message)
    
    def add_warning(self, message: str):
        self.warnings.append(message)
    
    def add_error(self, message: str):
        self.errors.append(message)
    
    def set_tool_availability(self, tool: str, available: bool, version: Optional[str] = None):
        self.tool_availability[tool] = {
            "available": available,
            "version": version,
            "status": "required" if tool in {"python3", "git", "swift", "td"} else "optional"
        }
    
    def print_report(self, verbose: bool = False):
        print("=" * 70)
        print("VERIFICATION PROFILES VALIDATION REPORT")
        print("=" * 70)
        
        if self.passed:
            print(f"\n✅ PASSED: {len(self.passed)}")
            if verbose:
                for msg in self.passed:
                    print(f"  ✓ {msg}")
        
        if self.errors:
            print(f"\n❌ ERRORS: {len(self.errors)}")
            for msg in self.errors:
                print(f"  ✗ {msg}")
        
        if self.warnings:
            print(f"\n⚠️  WARNINGS: {len(self.warnings)}")
            for msg in self.warnings:
                print(f"  ⚠ {msg}")
        
        # Tool availability summary
        print(f"\n🔧 Tool Availability:")
        for tool, info in sorted(self.tool_availability.items()):
            status_icon = "✅" if info["available"] else "❌"
            version = f" (v{info['version']})" if info["version"] else ""
            status = info["status"]
            print(f"  {status_icon} {tool:20} {status:10}{version}")
        
        print("\n" + "=" * 70)
        if self.has_errors():
            print("RESULT: FAILED - Errors must be resolved")
        elif self.has_warnings():
            print("RESULT: PASSED WITH WARNINGS (optional tools missing)")
        else:
            print("RESULT: PASSED - All validation checks succeeded")
        print("=" * 70)


# -----------------------------------------------------------------------------
# Tool Checking
# -----------------------------------------------------------------------------

def check_tool_available(tool_name: str) -> Tuple[bool, Optional[str]]:
    """Check if a tool is available and get its version."""
    try:
        # For tools that support --version
        for version_flag in ["--version", "-v", "version"]:
            try:
                result = subprocess.run(
                    [tool_name, version_flag],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    # Extract version from output
                    output = result.stdout.strip() or result.stderr.strip()
                    if output:
                        # Try to extract version number
                        lines = output.split('\n')
                        for line in lines:
                            if line.strip():
                                return True, line.strip().split('\n')[0]
                    return True, None
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        # For tools without --version, just check if they exist
        if shutil.which(tool_name):
            return True, None
        
        return False, None
    except Exception:
        return False, None


def detect_all_tools() -> Dict[str, Tuple[bool, Optional[str]]]:
    """Detect availability of all known tools."""
    tools = [
        "python3", "git", "swift", "td",
        "swiftlint", "swift-format",
        "rg", "fd", "jq", "yq",
        "dot", "mermaid-cli", "structurizr",
        "git-filter-repo"
    ]
    
    results = {}
    for tool in tools:
        available, version = check_tool_available(tool)
        results[tool] = (available, version)
    
    return results


# -----------------------------------------------------------------------------
# Profile Validation
# -----------------------------------------------------------------------------

def load_manifest(path: Path = MANIFEST_PATH) -> Optional[Dict[str, Any]]:
    """Load the verification profiles manifest."""
    if not path.exists():
        return None
    
    try:
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        return data if data else None
    except yaml.YAMLError as e:
        print(f"ERROR: YAML parse error in {path}: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"ERROR: Could not read {path}: {e}", file=sys.stderr)
        return None


def validate_manifest_structure(manifest: Dict[str, Any], result: ValidationResult):
    """Validate the manifest has required structure."""
    if "profiles" not in manifest or not manifest["profiles"]:
        result.add_error("Manifest must have 'profiles' list")
        return
    
    if "profile_groups" not in manifest:
        result.add_warning("Manifest should have 'profile_groups' for lane-based assignment")
    
    if "validation" not in manifest:
        result.add_warning("Manifest should have 'validation' section with rules")
    
    if "tool_availability" not in manifest:
        result.add_warning("Manifest should have 'tool_availability' section")
    
    result.add_passed("Manifest structure is valid")


def validate_profile_fields(profile: Dict[str, Any], profile_id: str, result: ValidationResult):
    """Validate a single profile has required fields."""
    required_fields = ["id", "description", "commands"]
    
    for field in required_fields:
        if field not in profile or not profile[field]:
            result.add_error(f"Profile '{profile_id}': missing required field '{field}'")
            return
    
    # Validate commands are non-empty
    commands = profile.get("commands", [])
    if not commands:
        result.add_error(f"Profile '{profile_id}': no commands defined")
        return
    
    for i, cmd in enumerate(commands):
        if not cmd or not isinstance(cmd, dict):
            result.add_error(f"Profile '{profile_id}': command {i} is empty or invalid")
            continue
        
        if "command" not in cmd or not cmd["command"].strip():
            result.add_error(f"Profile '{profile_id}': command {i} has empty command string")
            continue
    
    result.add_passed(f"Profile '{profile_id}' is valid")


def validate_profiles(manifest: Dict[str, Any], result: ValidationResult):
    """Validate all profiles in the manifest."""
    profiles = manifest.get("profiles", [])
    profile_ids = set()
    
    for profile in profiles:
        profile_id = profile.get("id", "unknown")
        
        # Check for duplicate IDs
        if profile_id in profile_ids:
            result.add_error(f"Duplicate profile ID: '{profile_id}'")
        profile_ids.add(profile_id)
        
        # Validate profile fields
        validate_profile_fields(profile, profile_id, result)
        
        # Validate required_tools and optional_tools
        required_tools = profile.get("required_tools", [])
        optional_tools = profile.get("optional_tools", [])
        
        if not required_tools:
            result.add_warning(f"Profile '{profile_id}': no required_tools defined")
        
        for tool in required_tools:
            if tool.strip():
                result.set_tool_availability(tool.strip(), None, None)
    
    result.add_passed(f"Validated {len(profiles)} profiles")


def validate_required_tools(manifest: Dict[str, Any], tool_checks: Dict[str, Tuple[bool, Optional[str]]], result: ValidationResult):
    """Check that required tools for all profiles are available."""
    profiles = manifest.get("profiles", [])
    
    for profile in profiles:
        profile_id = profile.get("id", "unknown")
        required_tools = profile.get("required_tools", [])
        
        for tool in required_tools:
            tool = tool.strip()
            if not tool:
                continue
            
            available, version = tool_checks.get(tool, (False, None))
            result.set_tool_availability(tool, available, version)
            
            if not available:
                result.add_error(f"Profile '{profile_id}' requires '{tool}' but it is not installed")


def validate_optional_tools(manifest: Dict[str, Any], tool_checks: Dict[str, Tuple[bool, Optional[str]]], result: ValidationResult):
    """Check optional tools and report missing ones as warnings."""
    profiles = manifest.get("profiles", [])
    
    for profile in profiles:
        profile_id = profile.get("id", "unknown")
        optional_tools = profile.get("optional_tools", [])
        
        for tool in optional_tools:
            tool = tool.strip()
            if not tool:
                continue
            
            available, version = tool_checks.get(tool, (False, None))
            result.set_tool_availability(tool, available, version)
            
            # Also check commands that reference optional_tool
            commands = profile.get("commands", [])
            for cmd in commands:
                if cmd.get("optional_tool") == tool and not available:
                    result.add_warning(
                        f"Profile '{profile_id}': command uses optional tool '{tool}' which is not installed"
                    )


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Validate verification profiles manifest and tool availability",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--check-tools",
        action="store_true",
        help="Only check tool availability, skip profile validation"
    )
    parser.add_argument(
        "--manifest",
        type=str,
        default=str(MANIFEST_PATH),
        help="Path to verification profiles YAML"
    )
    args = parser.parse_args()
    
    result = ValidationResult()
    manifest_path = Path(args.manifest)
    
    # Load manifest
    if not args.check_tools:
        manifest = load_manifest(manifest_path)
        if manifest is None:
            result.add_error(f"Could not load manifest: {manifest_path}")
            result.print_report(verbose=args.verbose)
            sys.exit(1)
        
        # Validate manifest structure
        validate_manifest_structure(manifest, result)
        
        # Validate individual profiles
        validate_profiles(manifest, result)
    
    # Detect tools
    tool_checks = detect_all_tools()
    
    # Record all tool availability
    for tool, (available, version) in tool_checks.items():
        result.set_tool_availability(tool, available, version)
    
    # Validate required tools
    if not args.check_tools:
        validate_required_tools(manifest, tool_checks, result)
        validate_optional_tools(manifest, tool_checks, result)
    else:
        # Only tool checking mode - check required tools that are commonly needed
        required_tools = ["python3", "git", "swift", "td"]
        for tool in required_tools:
            available, version = tool_checks.get(tool, (False, None))
            result.set_tool_availability(tool, available, version)
            if not available:
                result.add_error(f"Required tool '{tool}' is not installed")
        
        optional_tools = ["swiftlint", "swift-format", "rg", "fd", "jq", "yq", "dot", "mermaid-cli", "structurizr", "git-filter-repo"]
        for tool in optional_tools:
            available, version = tool_checks.get(tool, (False, None))
            result.set_tool_availability(tool, available, version)
            if not available:
                result.add_warning(f"Optional tool '{tool}' is not installed")
    
    # Print report
    result.print_report(verbose=args.verbose)
    
    sys.exit(result.exit_code())


if __name__ == "__main__":
    main()
