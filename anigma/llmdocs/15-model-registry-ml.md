# Model Registry and ML Services

## Model Registry
- Model registry storage is implemented in `Packages/ModelRegistry` and surfaced through `Sources/ModelRegistryModule`.
- The daemon initializes the registry in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.

## ML Worker Stack
- Shared ML worker utilities live in `Packages/MLWorkerCommon`.
- The `ml-worker` executable is defined in `Packages/MLWorkerExecutable` via `Package.swift`.

## Inference Interfaces
- Local inference adapters are provided in the CLI under `Packages/AnigmaCLI/Sources/LocalInference`.
- `InferenceCore` is a core package defined in `Package.swift` and used by the daemon and CLI layers.

## External Model Integration
- Model fetching and caching for CLI usage is under `Packages/AnigmaCLI/Sources/ModelManagement`.
- HuggingFace and other provider adapters are wired in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift` via `HuggingFaceAdapter`.

## Key References
- `Package.swift`
- `Packages/ModelRegistry`
- `Packages/AnigmaCLI/Sources/LocalInference`
