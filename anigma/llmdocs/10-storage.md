# Storage and Vaults

## Vault Architecture
- The storage system centers on the vault authority implemented in `Packages/StorageCore/VaultAuthority.swift`.
- Vault layout, encryption, and key management are defined in `Packages/StorageCore/VaultLayout.swift`, `Packages/StorageCore/VaultCrypto.swift`, and `Packages/StorageCore/VaultKeychainProvider.swift`.

## Data Persistence
- Persistent metadata is stored through `Packages/DatabaseCore` with GRDB integration referenced in `Package.swift`.
- Vault indexes and retention ledgers are owned by `Packages/StorageCore/VaultIndexStore.swift` and related types.

## Retention and Export
- Vault export bundles and retention policies are managed by `VaultAuthority` with manifests written under the vault directory.
- Receipts for storage operations are tracked by `Packages/StorageCore/VaultReceiptWriter.swift`.

## Key References
- `Packages/StorageCore/VaultAuthority.swift`
- `Packages/StorageCore/VaultLayout.swift`
- `Packages/DatabaseCore`
