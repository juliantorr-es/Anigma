# Export and Artifact Handling

## Export Modules
- Export services are defined in `Packages/ExportCore` and `Packages/ExportUI` (declared in `Package.swift`).
- The daemon initializes the export engine in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.

## Artifact Storage
- Artifact persistence is handled by the vault authority in `Packages/StorageCore/VaultAuthority.swift`.
- Artifact provenance and retention reports are written by `Packages/StorageCore/VaultReceiptWriter.swift` and related types.

## Artifact Store Module
- Higher-level artifact workflows are encapsulated in `Sources/ArtifactStoreModule` per `Package.swift`.

## Key References
- `Packages/ExportCore`
- `Packages/StorageCore/VaultAuthority.swift`
- `Sources/ArtifactStoreModule`
