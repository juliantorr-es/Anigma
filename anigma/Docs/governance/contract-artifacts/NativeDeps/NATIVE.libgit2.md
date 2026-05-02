# Native Library Intake Contract: libgit2

## Purpose
This library exists in Anigma to provide: native Git operations with deterministic diffs, 3-way merges, and conflict detection capabilities.
It is used by: MakerEngineEnhancements module for GitEngine adapter.
It must never be imported outside: Sources/MakerEngineEnhancements/Adapters/.

## Authority Boundary
Native surface owner: Sources/ExternalC/VersionControl/libgit2  
Swift wrapper owner: Sources/MakerEngineEnhancements/Adapters/GitEngine  
Allowed call sites: MakerEngineEnhancements only (GitEngine, ParallelAgentCoordinator)

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: system package manager (brew) or bundled libgit2

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: libgit2  
Version/Tag: 1.8.4+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: Minimal patches for parallel safety only

## License and Compliance
License: GPLv2 with Linking Exception  
Attribution file: Docs/licenses/libgit2.txt  
App Store suitability: allowed (linking exception)

## Security Posture
Threat model: untrusted repository data, malicious branch names, symlink attacks  
Memory safety risks: owned pointers, buffer management, thread safety  
Mitigations: GitEngine validates all inputs, sandboxed checkout paths, actor isolation

## API Contract
Wrapper API must be:
- Deterministic for same inputs (git operations are deterministic)
- Threading model defined (GitEngine actor manages all libgit2 operations)
- Ownership model explicit (GitEngine owns repository handles)
- Evidence generation for all operations

Error mapping:
Native errors map to typed GitEngineError enum; never leak raw error codes.

## Core Capabilities Required

### Deterministic Diff Generation
- `git_diff_index_to_workdir()` with exact context lines
- `git_diff_tree_to_tree()` for commit-to-commit diffs
- Predictable hunk generation for merge conflict detection

### Safe Parallel Operations
- Repository snapshots anchored to base commits
- Read-only references for concurrent agents
- Lock-free index operations where possible

### Evidence Generation
- Operation receipts with SHA-256 hashes
- Timestamps for all git operations
- Provenance tracking for branch/commit access

## Build and Tooling
SwiftPM target name(s): libgit2 (system library)  
Expected build flags: -DGIT_SSH=OFF, -DGIT_HTTPS=ON  
Platform support: macOS, iOS (limited), Linux

CI requirements:
- Builds on CI with deterministic configuration  
- Version recorded in build logs via git_libgit2_version()
- Test parallel access patterns

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any git operation emits a "GitOperation" receipt including operation type, inputs, and hash outputs.

## Acceptance Tests
Golden tests for correctness: GitEngineTests  
Fuzz/safety tests: Malformed repository data test suite  
Performance sanity: Large repository diff generation under 100ms  
Parallel safety: 10 concurrent agents operating on same base commit

## Integration Requirements
- All operations must produce evidence receipts
- Base commit anchoring for parallel agents
- Conflict detection with human-readable explanations
- Integration with existing MakerEngine quarantine system
