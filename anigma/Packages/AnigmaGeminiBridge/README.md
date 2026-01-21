# AnigmaGeminiBridge

## Responsibility
**AI Model Context Protocol (MCP) Bridge**.
This module provides the integration layer between the Anigma app and the `anigma-mcp` service. It enables AI agents to interact with localized tools and data via a governed protocol.

## Configuration
The bridge supports flexible dependency injection for the `anigma-mcp` binary path, ensuring portability across different environments.

### Resolution Priority:
1.  **Explicit Config**: Provided via `BridgeConfig` at initialization.
2.  **Environment Variable**: `ANIGMA_MCP_PATH`.
3.  **Heuristic Scanning**: Checks common build and installation directories (e.g., `.build/debug/anigma-mcp`).

## Usage Example

```swift
let config = BridgeConfig(mcpBinaryPath: "/usr/local/bin/anigma-mcp")
let client = MCPClient(config: config)
try await client.start()
```

## Maturity Level
**Level 5 (Golden)**: Portability refactored, strict concurrency enabled, configuration-first design.
