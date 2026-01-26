# Jobs and Workflow Execution

## Job Lifecycle
- Job submission and status endpoints are handled by `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Jobs.swift`.
- The daemon enforces capability token checks before job submission and retrieval.

## Job Infrastructure
- The daemon owns a `JobQueue`, `JobRegistry`, and `WorkerPool` initialized in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.
- Job persistence is backed by `SQLiteJobPersistence` in the same daemon core layer.

## Worker Registration
- Default workers are registered in `DaemonServer.registerDefaultWorkers()` in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.
- Worker coverage spans PDF, chunking, indexing, governance, ML inference, and media pipelines.

## Governance Hooks
- Each job submission is associated with a receipt via `ReceiptEngine` in `DaemonServer`.
- Job events emit telemetry signals and optionally log audit trails.

## Key References
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Jobs.swift`
