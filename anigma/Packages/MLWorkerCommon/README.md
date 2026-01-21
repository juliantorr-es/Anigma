# MLWorkerCommon

**Shared types and protocols for Anigma ML workers.**

`MLWorkerCommon` defines the common interfaces used by various ML-powered components in the Anigma platform, such as vector databases, OCR engines, and text-shaping systems.

## Core Components

### MLProcessingProtocol
Standard protocol defined for all ML processing units.

```swift
public protocol MLWorker: Actor {
    func process(_ input: MLInput) async throws -> MLOutput
}
```

### ML Types
- `MLInput`: Atomic unit of work for a worker.
- `MLOutput`: Result of processing, including confidence scores and metadata.
- `MLWorkerCapabilities`: Expresses what models/tasks a worker supports.

## Key Features

- **Type Consistency**: Standardizes how data is passed to and from ML models.
- **Worker Discovery**: Protocols for workers to register their capabilities.
- **Unified Results**: Shared schema for results (OCR text, vector arrays, etc).

## Thread Safety

- **Actors**: All worker protocols are designed to be implemented as actors.
- **Sendability**: Input and Output types strictly conform to `Sendable`.

## Dependencies

- **AnigmaPrimitives**: Base types.
- **TelemetryCore**: For recording performance metrics.

## See Also

- [VectorumModule](../VectorumModule/README.md)
- [MLOutputCache](../MLOutputCache/README.md)

## License

Part of the Anigma project. See LICENSE for details.
