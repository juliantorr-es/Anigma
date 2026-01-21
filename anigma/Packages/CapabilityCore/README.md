# CapabilityCore

**Cross-platform capability abstraction with governance integration**

CapabilityCore provides a unified interface for platform-specific capabilities (PDF rendering, compression, text shaping, etc.) with built-in governance, audit logging, and ECS integration.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  CapabilityRegistry                      │
│  (Actor-based, thread-safe, governance-integrated)      │
└─────────────────────────────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │   PDF   │     │Compress │     │  Text   │
    │Rendering│     │  -ion   │     │ Shaping │
    └────┬────┘     └────┬────┘     └────┬────┘
         │               │                │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ PDFKit  │     │ Native  │     │CoreText │
    │(macOS)  │     │Enhanced │     │(macOS)  │
    └─────────┘     └─────────┘     └─────────┘
         │               │                │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ PDFium  │     │  zstd   │     │HarfBuzz │
    │ (Linux) │     │ (Linux) │     │ (Linux) │
    └─────────┘     └─────────┘     └─────────┘
```

## Features

- **Type-Safe Resolution**: Resolve capabilities by protocol type
- **Governance Integration**: Permission checks and audit logging
- **ECS Alignment**: Components and systems for capability operations
- **Cross-Platform**: Automatic platform detection and provider selection
- **Thread-Safe**: Actor-based registry with safe concurrent access
- **Extensible**: Easy to add new capabilities and providers

## Core Protocols

### Capability
Base protocol for all capabilities:
```swift
public protocol Capability: Sendable {
    static var capabilityId: String { get }
}
```

### CapabilityProvider
Implemented by all providers:
```swift
public protocol CapabilityProvider: Sendable {
    var providerId: String { get }
    var supportedCapabilities: [String] { get }
}
```

## Built-in Capabilities

| Capability | Protocol | Providers |
|------------|----------|-----------|
| **PDF Rendering** | `PDFRenderingCapability` | PDFKit (macOS), PDFium (Linux) |
| **PDF Surgery** | `PDFSurgeryCapability` | PDFKit (macOS), PDFium (Linux) |
| **Compression** | `CompressionCapability` | Native, Enhanced |
| **Text Shaping** | `TextShapingCapability` | CoreText (macOS), HarfBuzz (Linux) |
| **Git Operations** | `GitCapability` | CLI Sidecar |

## Usage

### Basic Resolution
```swift
import CapabilityCore

let registry = CapabilityRegistry.shared

// Type-based resolution (recommended)
if let pdf = await registry.resolve(
    capabilityId: CapabilityIds.pdfRender,
    as: PDFRenderingCapability.self
) {
    let image = try await pdf.renderPage(
        pdfData: data,
        pageNumber: 1,
        resolution: 144.0
    )
}
```

### With Governance
```swift
let capability = await registry.resolveWithGovernance(
    capabilityId: CapabilityIds.compression,
    as: CompressionCapability.self,
    principal: "user@example.com",
    governance: governanceAdapter,
    auditLog: auditAdapter
)
```

### Registration
```swift
// Register a custom provider
await registry.register(provider: MyCustomProvider())

// Register by type for type-safe resolution
await registry.register(
    provider: myProvider,
    as: MyCapability.self
)
```

## ECS Integration

### Components
- `CapabilityRequestComponent`: Marks entities requiring capabilities
- `CapabilityResultComponent`: Stores operation results
- `CapabilityProviderComponent`: Provider metadata

### Systems
- `CapabilityResolutionSystem`: Processes requests with governance

```swift
// Add capability request to entity
world.addComponent(
    to: entity,
    component: CapabilityRequestComponent(
        capabilityId: CapabilityIds.pdfRender,
        principal: "system",
        context: [:]
    )
)

// System processes and adds result
await resolutionSystem.update(world: world, deltaTime: 0)
```

## Governance

### Permission Checks
```swift
public protocol CapabilityGovernance: Sendable {
    func canResolve(
        capabilityId: String,
        principal: String,
        context: [String: String]
    ) async -> (allowed: Bool, reason: String?)
}
```

### Audit Logging
```swift
public protocol CapabilityAuditLog: Sendable {
    func logResolution(
        capabilityId: String,
        principal: String,
        success: Bool,
        metadata: [String: String]
    ) async
}
```

## Thread Safety

All operations are thread-safe:
- `CapabilityRegistry` is an `actor`
- All protocols require `Sendable` conformance
- Strict concurrency mode enabled

## Testing

```swift
import XCTest
@testable import CapabilityCore

final class MyCapabilityTests: XCTestCase {
    func testCapabilityResolution() async throws {
        let registry = CapabilityRegistry.shared
        await registry.register(provider: MockProvider())
        
        let capability = await registry.resolve(
            capabilityId: "test.capability",
            as: TestCapability.self
        )
        
        XCTAssertNotNil(capability)
    }
}
```

## Dependencies

- **AnigmaPrimitives**: Core types and utilities
- **AnigmaCore**: ECS primitives and governance

## See Also

- [Capability System Documentation](../../Docs/capability-system.md)
- [Implementation Guide](../../Docs/capability-provider-implementation.md)
- [Bootstrap Examples](../../Docs/capability-bootstrap-examples.md)
- [PlatformCore](../PlatformCore/README.md) - Platform-specific implementations

## License

Part of the Anigma project. See LICENSE for details.
