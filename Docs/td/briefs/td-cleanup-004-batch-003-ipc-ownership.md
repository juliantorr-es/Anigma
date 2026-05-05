# Implement td-cleanup-004: cleanup_executable_consolidation

Task ID: td-cleanup-004

## Source of Truth
- Docs/atlas/risk-index.json
- Docs/atlas/targets.json
- Docs/atlas/entrypoints.json
- Docs/atlas/authority-map.json
- Docs/governance/CLEANUP_ALIGNMENT_DOCTRINE.md
- Docs/proofs/td-cleanup-002-batch-001-post-review.md
- Docs/proofs/td-cleanup-003-batch-002-process-configuration-alignment.md
- Docs/proofs/context-pipeline-audit-normalization-2026-05-05.md

## Context Summary
Selected 10 focused risks for risk='daemon_ipc_binding' target='AnigmaDaemonCore'.

## Selected Findings
1. 117db7cec5b230ea9ba906e7920c8260202bc164040fa38471a14a4b894b552f | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift:58 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
2. a269a9b142886a3246e2a268c6a84b791947263b63c1149201931890dda48221 | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/DaemonWorkerRegistry.swift:12 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
3. 1ec69dc063f600f283c8f7d2867ff0d7e43d5e5f247aea8add90b13778f2267a | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/TechDebtWorker.swift:61 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
4. 5807f0a3ca1611f889e1335a5f2130ece8994cbe02e491d8926fe2a13b30bf8a | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift:171 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
5. 09d31c269a07f3723bf4db40ee29cf944f9e0c059f3f05176385cc7d41dc7064 | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift:175 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
6. 5c6e5e02d724b470a64aed09915704dfd9fb378a3d8454f6490bfdc173f8935c | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift:178 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
7. cd4a07247b485a913be7ffc967c6cd019c0606998e72380549889cdf4954bb6c | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift:180 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
8. 579b72d8f1550756a7190263148eb3b74b96bc8b6900c759855c50b32fba8d03 | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift:182 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
9. 28c86c7ac3a44432b103cea2e3b064dcc894fcdfdc62aba91d4ba5e11dd153e9 | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Services.swift:460 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.
10. 0e90229cea83c8444d0443c5f85acecf9c58b7ffb5cd1631091be80a9cb35183 | ipc.binding.socket | critical | medium_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Services.swift:461 | target=None | symbol=None | snippet= | rationale=Former sidecars may collide on sockets, ports, PID files, or lock files.

## Proposed Change Map
1. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
2. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/DaemonWorkerRegistry.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
3. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/TechDebtWorker.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
4. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
5. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
6. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
7. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
8. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
9. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Services.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
10. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Services.swift
   current assumption/risk: Former sidecars may collide on sockets, ports, PID files, or lock files.
   desired alignment: route daemon_ipc_binding through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding

## Non-Goals
- Do not modify unrelated runtime code.
- Do not refresh baselines unless explicitly justified.
- Do not suppress findings instead of repairing them.
- Do not treat scanner findings as automatic bugs.

## Approved Repair Shapes
- Route socket/listener ownership through a daemon IPC authority or lifecycle owner.
- Replace hard-coded socket paths, PID files, or lock files with injected/runtime-owned configuration.
- Keep bind/listen lifecycle explicit and testable.
- Preserve existing behavior.
- Use typed errors for bind/listen failures.
- Keep process exit/shutdown behavior at top-level boundaries only.

## Implementation Sequence
1. Inspect each selected source file.
2. Classify findings.
3. Repair confirmed/likely risks only.
4. Re-run executable-consolidation audit.
5. Rebuild atlas.
6. Verify query output and gate state.

## Validation Commands
- python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
- python3 scripts/anigma_executable_consolidation_audit.py --mode gate --baseline Docs/baselines/executable-consolidation-baseline.json --focus anigmad
- python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json
- python3 scripts/anigma_build_repo_atlas.py
- python3 scripts/anigma_context_query.py --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 10
- swift build --target AnigmaDaemonCore
- python3 scripts/anigma_diagnose.py validate --task-id td-cleanup-004 --command true

## Proof Requirements
- Document selected finding statuses.
- Document audit deltas.
- Document build/test results.
- Note whether production Swift changed.

## Acceptance Criteria
- No production Swift/C++/Metal source changed.
- Query remains focused.
- Repair scope limited to confirmed/likely risks.
- Proof artifact exists.

## Final Report Format
- files modified
- each selected finding status
- audit deltas
- build/test results
- remaining daemon_ipc_binding findings
- whether production Swift changed

## Warning
Scanner findings require source inspection before modification. Source remains canonical.
