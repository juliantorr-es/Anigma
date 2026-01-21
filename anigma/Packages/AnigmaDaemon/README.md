# AnigmaDaemon (anigmad)

The main executable for the Anigma sidecar daemon. This process acts as a coordinator for governed capability execution, providing a gRPC interface over Unix Domain Sockets (UDS).

## Usage

```bash
# Start the daemon (default)
anigmad

# Run in worker mode (internal use by coordinator)
anigmad --worker <job_kind>

# Run internal verification suite
anigmad --verify

# List registered job kinds
anigmad --list-jobs
```

## Features

- **Governed Execution**: All jobs are executed in isolated subprocesses with resource limits (CPU, Memory).
- **Audit Logging**: Every action generates a cryptographic receipt signed by the daemon.
- **Vault Integration**: Immutable artifact storage with integrity verification.
- **gRPC API**: Structured interface for client interactions.

## Verification

The daemon includes a built-in verification suite that tests:
1. gRPC service availability.
2. Worker isolation (CPU/Memory limits).
3. Vault streaming integrity.
4. Receipt generation and signing.

To run verification:
```bash
swift run anigmad --verify
```

## Architecture

`anigmad` coordinates several actors:
- `DaemonServer`: Main coordinator.
- `GRPCServerManager`: Handles networking.
- `JobQueue` & `WorkerPool`: Manages job execution.
- `VaultAuthority`: Manages artifact storage.
- `ReceiptEngine`: Manages cryptographic receipts.
