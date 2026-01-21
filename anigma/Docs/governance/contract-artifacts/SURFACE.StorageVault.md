# SURFACE.StorageVault

## Surface Definition

**Surface Name**: StorageVault  
**Authority Boundary**: Core Governance Layer (StorageCore + DatabaseCore)  
**Implementation Location**: `Sources/StorageCore/` (vault authority + layout), `Sources/DatabaseCore/` (vault metadata/index tables)  
**Lease Required**: Yes – all reads/writes are mediated by the authority-owned vault actor; no direct filesystem capability is exposed to clients.

## Surface API

### Authority Surface (Core)
- `VaultAuthority.ingest(bytes, kind, mime, actorId?) -> ArtifactRef`
- `VaultAuthority.open(hash, actorId?) -> bytes`
- `VaultAuthority.quarantine(bytes, actorId?) -> QuarantineTicket`
- `VaultAuthority.promote(ticket, kind, mime, actorId?) -> ArtifactRef`
- `VaultAuthority.exportBundle(request, actorId?) -> VaultExportBundle`
- `VaultAuthority.gc(policy, dryRun, actorId?) -> VaultGCReport`

### Database Surface (Index/Graph)
- `vault_artifacts` keyed by `sha256_hex` with size, mime, kind, keyId, createdAt, objectRelpath.
- `vault_edges` for provenance relationships (`derived_from`, `receipt_for`, `thumbnail_of`, etc.).
- `vault_access_log` for allow/deny decisions with reasons (hash only, no absolute paths).

## Data Surface

### Vault Layout (Deterministic)
```
VaultRoot/
  objects/sha256/aa/bb/<full-hex-hash>
  manifests/runs/<runId>.json
  quarantine/<ticketId>/*
  temp/
```

### ArtifactRef
- `sha256_hex` (identity)
- `byte_len`
- `mime`
- `kind` (original | derived | receipt | preview | export | temp)
- `key_id`
- `object_relpath`

### Crypto & Encoding
- Canonical hash: `sha256` of plaintext bytes before encryption.
- At-rest encryption: envelope encryption, per-artifact derived keys.
- Export manifests include plaintext hash, envelope hash, receipts, and a signed manifest payload.

## Concurrency Model

- The vault is an actor-owned authority; all filesystem access is serialized within the actor.
- Database writes are isolated by `DatabaseActor` and ordered with vault writes.
- Promotion from quarantine is atomic: verify -> write vault object -> persist DB record -> emit receipt.

## Stop Conditions

- Reject ingest if hash does not match computed plaintext or size limits exceeded.
- Reject promotion if quarantine policy fails (type sniff, parser sanity, classification).
- Reject open if access policy denies or integrity check fails (hash mismatch).
- Any failure emits a denial receipt with a stable reason code.

## Acceptance Tests

1. Ingest a fixture -> returned hash matches SHA-256 of plaintext; object stored at deterministic relpath.
2. Quarantine promotion requires policy pass; denied promotions emit receipts and do not create objects.
3. Open verifies stored blob integrity and denies on tamper.
4. Export bundle includes manifest + receipts; offline verification recomputes hashes and passes.
5. GC dry-run emits a retention report without deleting; live run deletes only eligible artifacts and logs to `retention_events` plus the vault ledger.

## Migration Plan

1. Add StorageVault contract surface to ContractsCore and wire to StorageCore authority actor.
2. Route any existing artifact writes through the vault authority (no direct filesystem paths).
3. Keep DatabaseCore as index only; large payloads move to vault objects.
4. Add Harmonia CLI surfaces for `vault status`, `vault verify`, `vault export`, `vault gc`.
5. Add validation checks that scan for plaintext artifacts in `objects/` and missing DB references.

## Evaluated Existing Abstractions

- `Sources/DatabaseCore/ContentAddressedStore.swift` (SQLite-backed blob store; rejected for large blobs/streaming).
- `Sources/HarmoniaModule/Storage/ArtifactStore.swift` (DB blob payloads; keep as metadata/index adapter).
- `Sources/HarmoniaModuleExperimental/Security/SecretVault.swift` (pattern for permissions + audit logging).

---

**Contract Status**: DRAFT  
**Last Updated**: 2025-12-19  
**Authority**: Core Governance Layer
