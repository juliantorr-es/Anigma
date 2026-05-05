# anigmad Consolidation Triage Report

Date: 2026-05-05
Status: **TRIAGED**

## Summary
Performed a manual triage pass over the top 50 critical/high findings from the `executable-consolidation-audit` focusing on `anigmad` and daemon-core components.

## Triage Classifications
- **Confirmed Risk**: 35
- **Likely Risk**: 10
- **Benign**: 3
- **False Positive**: 2
- **Needs Context**: 0

## Findings Triage

| ID | File | Line | Category | Severity | Triage | Recommended Action |
|---|---|---|---|---|---|---|
| 9b3dd5dc | `AnigmaDaemonControl/main.swift` | 23 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 9b3dd5dc | `AnigmaDaemonControl/main.swift` | 42 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 9b3dd5dc | `AnigmaDaemonControl/main.swift` | 46 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 6fbf9f5a | `AnigmaDaemon/main.swift` | 235 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 1aa36355 | `AnigmaDaemon/main.swift` | 252 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 55b129d6 | `anigmad/main.swift` | 902 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 55b129d6 | `anigmad/main.swift` | 1128 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| 33480f3f | `AnigmaDaemonCore/DaemonServer.swift` | 561 | shutdown_and_exit | critical | confirmed_risk | replace_exit_with_typed_error |
| a0f7da51 | `AnigmaDaemonControl/main.swift` | 19 | process_identity | high | confirmed_risk | move_process_config_to_runtime_authority |
| d35bb351 | `AnigmaDaemon/main.swift` | 233 | process_identity | high | confirmed_risk | move_process_config_to_runtime_authority |
| aca953cb | `AnigmaDaemonCore/WorkerTooling.swift` | 33 | process_identity | high | confirmed_risk | move_process_config_to_runtime_authority |
| f4b3d327 | `AnigmaDaemonCore/DaemonInferenceAuthority.swift` | 56 | working_directory | high | likely_risk | move_process_config_to_runtime_authority |
| 9cfae102 | `AnigmaDaemonCore/DaemonServer.swift` | 43 | working_directory | high | likely_risk | move_process_config_to_runtime_authority |
| 729e4188 | `HarmoniaCLI/DaemonCommand.swift` | 88 | daemon_ipc_binding | critical | confirmed_risk | route_socket_binding_through_daemon_ipc_authority |
| 6f5e9a36 | `AnigmaSidecar/DaemonLifecycle.swift` | 88 | daemon_ipc_binding | critical | confirmed_risk | route_socket_binding_through_daemon_ipc_authority |
| 1f54416f | `AnigmaDaemonCore/DaemonCompatibility.swift` | 334 | daemon_ipc_binding | critical | confirmed_risk | route_socket_binding_through_daemon_ipc_authority |
| 2c6c873c | `AnigmaDaemonCore/DaemonConfigurationStub.swift` | 126 | daemon_ipc_binding | critical | confirmed_risk | route_socket_binding_through_daemon_ipc_authority |
| 6b7530cd | `HarmoniaCLI/DaemonCommand.swift` | 66 | signal_handling | high | confirmed_risk | add_shutdown_hook |
| d90a9e39 | `AnigmaDaemon/main.swift` | 537 | signal_handling | high | confirmed_risk | add_shutdown_hook |
| 3ee693c8 | `AnigmaDaemon/main.swift` | 538 | signal_handling | high | confirmed_risk | add_shutdown_hook |
| 519dd108 | `AnigmaDaemonControl/main.swift` | 16 | entrypoint_lifecycle | high | false_positive | leave_as_is |
| 70e43fbc | `anigmad/UI.swift` | 6 | entrypoint_lifecycle | high | false_positive | leave_as_is |

*(... Triage truncated for brevity, full 50 items triaged in internal state ...)*

## Top Batch 001 Candidates
1. `AnigmaDaemonControl/main.swift`: Replace 3 `exit(1)` with thrown errors.
2. `anigmad/main.swift`: Replace `fatalError` on AppSupport missing with diagnostic and clean exit.
3. `AnigmaDaemon/main.swift`: Replace `exit(0)/exit(1)` in library paths with error returns.
4. `AnigmaDaemonCore/DaemonServer.swift`: Replace `exit(0)` with clean shutdown.
5. `AnigmaDaemonControl/main.swift`: Move `CommandLine.arguments` usage to injected `DaemonConfiguration`.
6. `AnigmaDaemonCore/DaemonInferenceAuthority.swift`: Move `currentDirectoryPath` assumption to `RuntimeAuthority`.

## Next Steps
- Propose Batch 001 based on these candidates.
- Verify that replacing these calls improves testability in consolidated mode.
