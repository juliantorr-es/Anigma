# CLI and TUI Surface

## CLI Entry Point
- The CLI main entry is `Packages/AnigmaCLI/Executable/Main.swift`.
- The CLI declares subcommands for planning, running, onboarding, and tool management in the same file.

## Execution Modes
- The CLI supports plan/run flows, dry-run enforcement, and JSON/text output formatting.
- Interactive sessions are handled through the TUI path in `Packages/AnigmaCLI/Executable/Main.swift` and components in `Packages/AnigmaCLI/Sources/TUI`.

## Orchestration and Providers
- Task routing and contract building use `Packages/AnigmaCLI/Orchestrator/AnigmaCLIOrchestrator.swift`.
- Provider discovery lives in `Packages/AnigmaCLI/Providers` and is surfaced via the `providers` command.

## Daemon Coordination
- The CLI ensures the daemon is running via `Packages/AnigmaSidecar/DaemonGuardian.swift`.
- One-shot execution paths use `Packages/AnigmaSidecar/SidecarBridge.swift` for remote job execution.

## Key References
- `Packages/AnigmaCLI/Executable/Main.swift`
- `Packages/AnigmaCLI/Sources/TUI`
- `Packages/AnigmaCLI/Orchestrator/AnigmaCLIOrchestrator.swift`
