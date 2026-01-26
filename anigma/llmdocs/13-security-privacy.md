# Security and Privacy

## Capability and API Key Controls
- The daemon enforces capability tokens and API keys via `CapabilityTokenManager` and `APIKeyManager` in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.
- Handler endpoints validate tokens before allowing job or data operations.

## Vault Encryption
- All artifacts are encrypted at rest by `Packages/StorageCore/VaultCrypto.swift` and managed in `Packages/StorageCore/VaultAuthority.swift`.
- Vault key material is handled by `Packages/StorageCore/VaultKeychainProvider.swift`.

## Telemetry Redaction
- Redaction policy is enforced by `Packages/TelemetryCore/Redaction.swift` and applied in `Packages/TelemetryCore/TelemetryClient.swift`.

## App-Level Secrets
- The macOS app integrates keychain handling via `App/MacApp/KeychainManager.swift`.
- Authentication workflows live in `App/MacApp/Services/AuthenticationService.swift`.

## Key References
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/StorageCore/VaultAuthority.swift`
- `Packages/TelemetryCore/Redaction.swift`
