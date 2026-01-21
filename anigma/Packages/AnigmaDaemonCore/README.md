# AnigmaDaemon

Production-grade sidecar daemon for governed, deterministic capability execution.

## Status

**Phase 1**: ✅ Complete - Contract and protobuf schema
**Phase 2**: ✅ Complete - Daemon core implementation
**Phase 3**: ✅ Complete - Toolchain Integration

## Components

### Configuration (`DaemonConfiguration.swift`)
- Platform-aware UDS paths (`~/Library/Caches/anigma` on macOS, `$XDG_RUNTIME_DIR` on Linux)
- Separate `bind_host` and `bind_port` (no footguns)
- Resource quotas and worker pool configuration

### Capability Tokens (`CapabilityToken.swift`)
- Scoped capability token minting
- Token validation with expiry checking
- Session management

### Contracts
- [`CONTRACT.md`](../../Docs/sidecar/CONTRACT.md) - Production contract
- [`anigma.proto`](Protos/anigma.proto) - gRPC API schema
- [`vertical-slice.md`](../../Docs/sidecar/vertical-slice.md) - Acceptance spec

## Next Steps

- [x] Daemon lifecycle (start/stop/health)
- [x] gRPC server (UDS transport)
- [x] Job queue and worker pool
- [x] Vault integration
- [x] `artifact.copy` job kind
- [x] Minimal vertical slice test
- [x] Toolchain workers (FFmpeg, ImageMagick, etc.)
- [ ] Strict isolation tuning (macOS limitations)

## Architecture

```
Coordinator Process (anigmad)
├── gRPC Server (UDS)
├── Capability Token Manager
├── Job Queue
├── Vault Integration
└── Worker Pool
    └── Worker Subprocesses
        └── artifact.copy, pdf.render, etc.
```

See [`CONTRACT.md`](../../Docs/sidecar/CONTRACT.md) for full specification.
