# Anigma Governance & Control Plane

## Overview
Anigma enforces architectural integrity through a strict "Ask -> Patch -> Prove" protocol. Agents interact with the codebase via governed tools (the "Anigma Control Plane") rather than direct shell execution.

## Authority Hierarchy
- **Tool Authority**: Wraps and manages standard Swift/Apple tooling (SwiftPM, SwiftLint, DocC, etc.).
- **Graph Authority**: Owns dependency manifests (`swift package describe`), manages cycle detection, and enforces target tier classification.
- **Doctrine Authority**: Enforces project-specific invariants:
    - No `@_exported` imports (unless explicitly allowlisted).
    - Contract-only modules (no implementation leakage into contracts).
    - Import fan-out budget limits.
- **Evidence Authority**: Generates machine-readable receipts (`td` tasks, patch hashes, test result bundles) to prove progress for human review.

## The "Anigma Doctor" Protocol
Every task involving architectural changes (especially dependency changes) MUST run the following sequence:

### 1. Pre-flight (anigma doctor)
Runs before any code changes:
- `swift package describe --type json > .build/anigma-package.json`
- `python3 Scripts/validate_exported_imports.py`
- `python3 Scripts/validate_no_cycles.py .build/anigma-package.json`
- `python3 Scripts/validate_tiers.py`
- `Scripts/validate_build_hygiene.sh`
- `swift build`

### 2. Context Extraction (anigma agent-context)
Produces the "canonical operating packet" for the agent:
- Current `TD` issue state.
- Relevant project doctrine.
- Dependency graph map.
- Validator status/baseline.

### 3. Proof Submission (anigma proof)
Captures execution outcome for review:
- Capture of patches/changes (`git diff`).
- Validator output (after the change).
- Focused test output (`swift test --filter`).
- Artifact hashes for review.

## Rules for Agents
1. **Never bypass Doctor/Proof**: Architectural success is defined by the proof output, not by agent claim.
2. **Explicit Dependency Direction**: Implementation modules depend downward on contract targets. Implementation modules NEVER depend on each other horizontally.
3. **ContractsCore is Constitutional**: Never re-export implementation modules from `ContractsCore`.
