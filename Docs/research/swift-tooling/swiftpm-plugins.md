# SwiftPM Plugins

**Source Repository:** `swiftlang/swift-package-manager`
**Commit:** `770f14b0a593399b78787ecd728f35e870c4cf6e`
**Key File:** `Sources/SPMBuildCore/Plugins/PluginInvocation.swift`
**Key Symbols:** `public enum PluginAction` (L26)

## Plugin Commands and Context
In `Sources/SPMBuildCore/Plugins/PluginInvocation.swift`, `PluginAction` defines the strict bounds of what a plugin can do. At L27, `createBuildToolCommands` exposes explicit outputs like `pluginGeneratedSources: [AbsolutePath]`.

Furthermore, the `invoke` method on `PluginModule` (L63) takes strict parameters for sandboxing, including `allowNetworkConnections: [SandboxNetworkPermission]`, `writableDirectories`, and `readOnlyDirectories`.

## Anigma Doctrine Takeaways
- **Sandbox Compliance:** Any Anigma command plugin must declare network permissions explicitly, as SwiftPM will sandbox it. Build tool plugins must not perform network operations.
- **Tooling Outputs:** Build tool plugins should be used strictly for generating verifiable source code or resources. Their outputs must be directed to the designated plugin output directory (`pluginGeneratedSources`) exactly as modeled in the upstream SwiftPM invocation signature.
