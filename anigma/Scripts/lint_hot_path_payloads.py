#!/usr/bin/env python3
"""
Gate 1 Linter: No raw Data/[UInt8]/[Float] in hot-path media contracts.

This script enforces the Constructive Doctrine rule:
"Hot-path contracts must not pass raw Data, [UInt8], [Float], or fake PayloadReference frame blobs.
Use FrameReference, AudioBufferReference, ImageSurfaceReference, PacketStreamReference, or ArtifactReference instead."

See:
- POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md Part 8, Gate 1
- Docs/architecture/CONSTRUCTIVE_DOCTRINE_STYLE_GUIDE.md
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Tuple

# Allowed reference types that can be used instead of raw Data
ALLOWED_TYPES = {
    'FrameReference',
    'AudioBufferReference', 
    'ImageSurfaceReference',
    'PacketStreamReference',
    'ArtifactReference',
    'MediaReference',
}

# Forbidden payload types in hot-path contracts
FORBIDDEN_TYPES = {
    'Data',
    '[UInt8]',
    '[Float]',
}

# Directories containing hot-path contracts (Tier 1)
# Only these directories contain MEDIA hot-path contracts that should enforce the no-raw-Data rule
# Per Constructive Doctrine: "Hot-path contracts must not pass raw Data, [UInt8], [Float]"
# This applies specifically to MEDIA contracts (video, audio, image processing)
HOT_PATH_CONTRACT_DIRS = {
    'Packages/ContractsCore/Sources/FoundationContracts/',
    'Packages/ContractsCore/Sources/MediaPipelineContracts/',
}

# Files within hot-path directories that are NOT media hot-path (e.g., UI, serialization)
NONOT_PATH_FILES = {
    'UIContracts.swift',  # UI state contracts, not media hot-path
    'ActionCatalog.swift',  # Action registry
    'StateContracts.swift',  # General state contracts
    'CoreContracts.swift',  # Core types
    'OperationResult.swift',  # Operation results
    'RollbackComplexity.swift',  # Rollback logic
    'ValidationContracts.swift',  # Validation contracts
    'TokenBuffer.swift',  # Token buffer
    'DiaplasionStateContracts.swift',  # Document state (serialization)
    'EvidenceContracts.swift',  # Evidence contracts (have their own rules)
    'GovernanceStripContracts.swift',  # Governance strips
    'EmbeddingComputing.swift',  # Embedding computation
}

# Files/patterns to skip
SKIP_PATTERNS = {
    '.build',
    'Tests/',
    'ThirdParty/',
    'Native/',
    'Deprecated/',
    '.git',
    '__pycache__',
}

# Files that are allowed to use Data (durable artifact boundaries or behind MaterializationGate)
# These are explicitly allowed by the Constructive Doctrine:
# "Raw Data may only appear at durable artifact boundaries or behind MaterializationGate with a receipt."
# 
# Note: Files NOT in this list that use Data/[UInt8]/[Float] need to be fixed to use
# approved reference types instead.
ALLOWED_DATA_FILES = {
    # Contract files that deal with serialization, hashing, or wire protocols
    # These use Data for internal representation but are behind MaterializationGate
    'ContractRuntimeTypes.swift',  # Evidence serialization
    'EvidenceCore.swift',
    'NativeWire.swift',
    'ContractSpec.swift',
    'KeyDerivation.swift',
    'MediaPipelineContracts.swift',  # storeRaw/loadRaw are durable artifact boundaries
    'CoreMLArtifactContract.swift',
    'ModelContract.swift',
    'MLWorkerContracts.swift',
}

# Type patterns to match in declarations
# Matches: var x: Data, let y: [UInt8], func f(d: Data), struct S { var p: Data }
# But NOT: DataProductKind, DataSubjectScope (where Data is part of a compound type name)
TYPE_PATTERN = re.compile(
    r'\b(?:var|let|func|class|struct|protocol|enum|case)\s+'
    r'(?:[a-zA-Z_][a-zA-Z0-9_]*\s+)?'  # optional name
    r'(?:\([^)]*\)\s*)?'  # optional parameter list
    r'[:,]\s*'
    r'(?:\bData\b|\\[UInt8\\]|\\[Float\\])'  # exact match: Data, [UInt8], [Float]
)


def is_skip_path(path: str) -> bool:
    """Check if a path should be skipped."""
    for skip in SKIP_PATTERNS:
        if skip in path:
            return True
    return False


def is_hot_path_contract(path: str) -> bool:
    """Check if a path is in a hot-path contract directory."""
    for contract_dir in HOT_PATH_CONTRACT_DIRS:
        if contract_dir in path:
            return True
    return False


def is_allowed_file(path: str) -> bool:
    """Check if a file is allowed to use Data (durable artifact boundaries)."""
    filename = os.path.basename(path)
    return filename in ALLOWED_DATA_FILES


def extract_type_declarations(content: str) -> List[Tuple[int, str, str]]:
    """Extract type declarations from source code."""
    violations = []
    
    lines = content.split('\n')
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Skip comments
        if stripped.startswith('//'):
            continue
        
        # Skip empty lines
        if not stripped:
            continue
            
        # Check for each forbidden type
        for forbidden in FORBIDDEN_TYPES:
            # Match the forbidden type as a type annotation
            # Pattern: (var|let|func|...) <name>: <forbidden_type>
            # Or: (var|let|func|...) (<name>: <forbidden_type>)
            
            # Escape square brackets for regex
            escaped_forbidden = re.escape(forbidden)
            
            # Pattern 1: var x: Data or let x: Data
            pattern1 = fr'\b(?:var|let|private\s+(?:var|let)|public\s+(?:var|let)|internal\s+(?:var|let)|fileprivate\s+(?:var|let))\s+[a-zA-Z_][a-zA-Z0-9_]*\s*:\s*{escaped_forbidden}\b'
            
            # Pattern 2: func f(x: Data) or func f(_ x: Data)
            pattern2 = fr'\b(?:func|init)\s*\([^)]*[a-zA-Z_][a-zA-Z0-9_]*\s*:\s*{escaped_forbidden}\b[^)]*\)'
            
            # Pattern 3: struct S { var x: Data } or class S { let x: Data }
            # This is harder - just check if the line contains ": Data" or ": [UInt8]" etc.
            pattern3 = fr':\s*{escaped_forbidden}\b'
            
            if re.search(pattern1, stripped) or re.search(pattern2, stripped) or re.search(pattern3, stripped):
                # Make sure it's not part of a longer type name
                # e.g., DataProductKind, DataSubjectScope
                if forbidden == 'Data':
                    # Check for word boundaries around Data
                    # Make sure it's not preceded by an uppercase letter (part of a type name)
                    # and not followed by an uppercase letter
                    data_pattern = fr'(?<!\b[A-Z])Data\b(?!\b[A-Z])'
                    if re.search(data_pattern, stripped):
                        violations.append((line_num, stripped, forbidden))
                        break
                else:
                    # For [UInt8] and [Float], just check exact match
                    if forbidden in stripped:
                        violations.append((line_num, stripped, forbidden))
                        break
    
    return violations


def check_file(file_path: str) -> List[Tuple[int, str, str]]:
    """Check a single file for violations."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return extract_type_declarations(content)
    except (IOError, UnicodeDecodeError):
        return []


def main():
    """Main entry point."""
    # Determine repo root - either parent of Scripts/ or current directory
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    
    # If script is in anigma/Scripts/, repo root is anigma/
    if script_dir.name == 'Scripts':
        repo_root = script_dir.parent
    # If script is run from elsewhere, try to find anigma directory
    elif not (repo_root / 'anigma').exists():
        # Try going up one more level
        repo_root = script_dir.parent.parent
    
    all_violations = []
    files_checked = 0
    
    # Walk through the repository
    for root, dirs, files in os.walk(repo_root):
        # Filter out skipped directories
        dirs[:] = [d for d in dirs if not is_skip_path(os.path.join(root, d))]
        
        for file in files:
            if not file.endswith('.swift'):
                continue
            
            file_path = os.path.join(root, file)
            
            # Skip non-hot-path files for now
            if not is_hot_path_contract(file_path):
                continue
            
            # Skip files that are NOT media hot-path (e.g., UI, general contracts)
            filename = os.path.basename(file_path)
            if filename in NONOT_PATH_FILES:
                continue
            
            # Skip files that are allowed to use Data (durable artifact boundaries)
            if is_allowed_file(file_path):
                continue
            
            files_checked += 1
            violations = check_file(file_path)
            
            for line_num, full_match, type_name in violations:
                relative_path = os.path.relpath(file_path, repo_root)
                all_violations.append({
                    'file': relative_path,
                    'line': line_num,
                    'code': full_match,
                    'type': type_name,
                })
    
    # Print results
    if all_violations:
        print(f"❌ FAILED: Found {len(all_violations)} Gate 1 violations\n")
        print("Gate 1: No raw Data/[UInt8]/[Float] media payloads in hot-path contracts\n")
        print("Approved shapes:")
        print("  - FrameReference (video frames)")
        print("  - AudioBufferReference (decoded audio)")
        print("  - ImageSurfaceReference (images)")
        print("  - PacketStreamReference (compressed packet streams)")
        print("  - ArtifactReference (durable files)\n")
        
        for v in all_violations:
            print(f"  {v['file']}:{v['line']}")
            print(f"    {v['code']}")
            print(f"    ❌ Forbidden type: {v['type']}\n")
        
        print(f"\nChecked {files_checked} files in hot-path contract directories.")
        sys.exit(1)
    else:
        print(f"✅ PASSED: No Gate 1 violations found")
        print(f"Checked {files_checked} files in hot-path contract directories.")
        sys.exit(0)


if __name__ == '__main__':
    main()
