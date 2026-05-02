# Anigma Capability System

The Anigma Capability System provides a portable, governed way to access platform-specific or library-dependent functionality through stable Swift contracts.

## Architecture

The system is split into three tiers:

1.  **Capability Contracts (`CapabilityCore`)**: Pure Swift protocols and data models. No C headers, no platform conditionals.
2.  **Capability Providers**: Adapters that implement the contracts using specific libraries or OS frameworks.
3.  **Capability Registry**: A runtime registry where providers are registered and resolved by the application.

## Goals

*   **Portability**: Code using capabilities doesn't care if it's running on macOS (using PDFKit) or Linux (using PDFium).
*   **Governance**: Capabilities can be audited, gated, and limited by policy through protocol-based governance integration.
*   **License Compliance**: GPL/AGPL tools are kept as sidecars (separate processes) to avoid linking into the core Anigma binary.
*   **ECS Integration**: Capabilities integrate with Anigma's Entity-Component-System architecture through dedicated components and systems.

## Current Capabilities

### PDF Rendering (`anigma.capability.pdf.render`)
Rendering pages to bitmaps, text extraction, and metadata.
*   **Providers**: `NativePDFProvider` (macOS/iOS via PDFKit).
*   **Features**: Page-level rendering, dimensions query, per-page text extraction

### PDF Surgery (`anigma.capability.pdf.surgery`)
Structural operations like merging, splitting, rotating, and removing pages.
*   **Providers**: `NativePDFProvider` (macOS/iOS via PDFKit).
*   **Features**: Merge, split, rotate pages, remove pages

### Compression (`anigma.capability.compression`)
Data compression and decompression.
*   **Providers**: `NativeCompressionProvider` (macOS/iOS via Compression framework). Supports GZIP and LZ4.

### Git Operations (`anigma.capability.git`)
Cloning, fetching, status, and commits.
*   **Providers**: `CLIGitProvider` (Sidecar via `/usr/bin/git`).

### Text Shaping (`anigma.capability.text.shaping`)
Advanced text shaping and font fallback.
*   **Providers**: TBD (Planned: ICU + HarfBuzz + FreeType).

## Usage

### Basic Resolution

```swift
import CapabilityCore

let registry = CapabilityRegistry.shared
if let pdfRender = await registry.resolve(
    capabilityId: CapabilityIds.pdfRender,
    as: PDFRenderingCapability.self
) {
    let text = try await pdfRender.extractText(pdfData: myData)
}
```

### Type-Based Resolution

```swift
import CapabilityCore

let registry = CapabilityRegistry.shared
await registry.register(myProvider, for: MyProviderType.self)

if let provider = await registry.provider(for: MyProviderType.self) {
    // Use provider
}
```

### Governance Integration

```swift
import CapabilityCore

// Implement governance protocol
struct MyGovernance: CapabilityRegistry.CapabilityGovernance {
    func canResolve(
        capabilityId: String,
        principal: String,
        context: [String: String]
    ) async -> (allowed: Bool, reason: String?) {
        // Check permissions
        return (true, nil)
    }
}

// Resolve with governance
let capability = await registry.resolveWithGovernance(
    capabilityId: CapabilityIds.pdfRender,
    as: PDFRenderingCapability.self,
    principal: "user@example.com",
    governance: MyGovernance(),
    auditLog: myAuditLog
)
```

### ECS Integration

```swift
import CapabilityCore
import AnigmaCore

// Create entity requesting a capability
let entityId = await world.createEntity()
await world.addComponent(
    entityId,
    CapabilityRequestComponent(
        capabilityId: CapabilityIds.pdfRender,
        priority: 1,
        context: ["principal": "system"]
    )
)

// System processes requests
let system = CapabilityResolutionSystem(
    governance: myGovernance,
    auditLog: myAuditLog
)
try await system.update(world: world)

// Check result
if let result = await world.getComponent(entityId, CapabilityResultComponent.self) {
    if result.success {
        // Capability available
    }
}
```

### Registering Providers

Providers should be registered during application bootstrap.

```swift
import CapabilityCore
import PlatformCore

// Register all platform capabilities
await PlatformCapabilityBootstrap.registerPlatformCapabilities(
    governance: myGovernance,
    auditLog: myAuditLog
)

// Check what's registered
let capabilities = await PlatformCapabilityBootstrap.registeredCapabilities()
print("Registered capabilities: \(capabilities)")
```

## Sidecar Tools (GPL Compliance)

GPL or AGPL functionality MUST be implemented as a `SidecarCapabilityProvider`. This involves:
1.  A separate executable installed by the user.
2.  Communication via stdin/stdout or a local socket.
3.  No linking of GPL code into the Anigma process.

Example: `CLIGitProvider` uses the system `git` binary as a sidecar.

## Testing

Comprehensive tests are available in `Tests/CapabilityCoreTests/`:
- ID-based registration and resolution
- Type-based registration
- Governance integration (allow/deny)
- Audit logging
- Introspection methods

Run tests with:
```bash
swift test --filter CapabilityRegistryTests
```

## Architecture Alignment

The capability system follows Anigma's architectural standards:

- **ECS Components**: `CapabilityRequestComponent`, `CapabilityResultComponent`, `CapabilityProviderComponent`
- **ECS Systems**: `CapabilityResolutionSystem` (AsyncSystem)
- **Governance**: Protocol-based governance integration via `CapabilityGovernance`
- **Audit Logging**: Protocol-based audit logging via `CapabilityAuditLog`
- **Strict Concurrency**: All types are `Sendable`, registry is an `actor`
