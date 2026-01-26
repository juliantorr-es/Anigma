# Extensions and Integrations

## Safari Web Extension
- Browser extension assets live in `App/SafariExtension`, including `manifest.json`, `background.js`, and `content.js`.
- The Swift handler is in `App/SafariExtension/SafariWebExtensionHandler.swift`.

## MCP Integration
- MCP module support is implemented in `Sources/AnigmaMCPModule` (declared in `Package.swift`).
- The executable entry point is `Sources/AnigmaMCPExecutable` per `Package.swift`.
- MCP rollout notes live in `Docs/sprints/2026-01-MCP-Extension`.

## CLI and Daemon Touchpoints
- The CLI exposes MCP commands via `Packages/AnigmaCLI/Executable/Main.swift`.
- The daemon hosts MCP services inside `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.

## Key References
- `App/SafariExtension`
- `Sources/AnigmaMCPModule`
- `Docs/sprints/2026-01-MCP-Extension`
