# PlatformCore

**Platform-specific capability implementations**

PlatformCore provides concrete implementations of capabilities defined in CapabilityCore, with platform detection and automatic provider selection.

## Architecture

PlatformCore bridges the abstract capability protocols with platform-specific APIs:

```
CapabilityCore (Protocols)
         │
         ▼
   PlatformCore (Implementations)
         │
    ┌────┴────┐
    │         │
  macOS     Linux
    │         │
  PDFKit   PDFium
CoreText  HarfBuzz
```

## Providers

### PDF Providers

#### NativePDFProvider (macOS/iOS) ✅
- **Status**: Production-ready
- **Platform**: macOS 10.15+, iOS 13+
- **Backend**: PDFKit
- **Features**:
  - Page rendering with custom DPI
  - Per-page text extraction
  - Page dimensions query
  - Page rotation and removal
  - Merge and split operations

#### PDFiumProvider (Linux) 🚧
- **Status**: Stub (infrastructure ready)
- **Platform**: Linux
- **Backend**: PDFium C library
- **Requirements**: `libpdfium-dev`

### Compression Providers

#### NativeCompressionProvider ✅
- **Status**: Production-ready
- **Platform**: All (macOS, iOS, Linux)
- **Algorithms**: LZ4, ZLIB, LZMA, LZFSE

#### EnhancedCompressionProvider ✅
- **Status**: Production-ready
- **Platform**: All (macOS, iOS, Linux)
- **Features**: Better error handling, algorithm validation

### Text Shaping Providers

#### NativeTextShapingProvider (macOS/iOS) ✅
- **Status**: Production-ready
- **Platform**: macOS, iOS
- **Backend**: CoreText
- **Features**:
  - Full CTLine/CTRun integration
  - Proper glyph positioning
  - Advance width/height calculation

#### HarfBuzzTextShapingProvider (Linux) ✅
- **Status**: Functional (requires HarfBuzz + FreeType)
- **Platform**: Linux
- **Backend**: HarfBuzz + FreeType
- **Requirements**: `libharfbuzz-dev`, `libfreetype6-dev`

### Git Provider

#### CLIGitProvider ✅
- **Status**: Production-ready
- **Platform**: All (requires git binary)
- **Pattern**: Sidecar (GPL compliance)

## Bootstrap

### Automatic Platform Detection
```swift
import PlatformCore

// Automatically registers platform-appropriate providers
await PlatformCapabilityBootstrap.registerPlatformCapabilities()
```

### With Governance
```swift
import PlatformCore
import AnigmaCore

let governance = GovernanceController()
await governance.initialize()

let governanceAdapter = CapabilityGovernanceAdapter(controller: governance)
let auditAdapter = CapabilityAuditAdapter(auditLog: governance.auditLog)

await PlatformCapabilityBootstrap.registerPlatformCapabilities(
    governance: governanceAdapter,
    auditLog: auditAdapter
)
```

## Platform Matrix

| Provider | macOS | iOS | Linux | Windows |
|----------|-------|-----|-------|---------|
| NativePDFProvider | ✅ | ✅ | ❌ | ❌ |
| PDFiumProvider | ❌ | ❌ | 🚧 | 🚧 |
| NativeCompressionProvider | ✅ | ✅ | ✅ | ✅ |
| EnhancedCompressionProvider | ✅ | ✅ | ✅ | ✅ |
| NativeTextShapingProvider | ✅ | ✅ | ❌ | ❌ |
| HarfBuzzTextShapingProvider | ❌ | ❌ | ✅ | 🚧 |
| CLIGitProvider | ✅ | ✅ | ✅ | ✅ |

**Legend**: ✅ Production-ready | 🚧 Infrastructure ready | ❌ Not applicable

## Governance Adapters

### CapabilityGovernanceAdapter
Bridges `GovernanceController` with `CapabilityRegistry`:
```swift
let adapter = CapabilityGovernanceAdapter(controller: governance)
// Treats capability resolution as write operations
// Evaluates through governance write gate
```

### CapabilityAuditAdapter
Bridges `AuditLogging` with `CapabilityRegistry`:
```swift
let adapter = CapabilityAuditAdapter(auditLog: auditLog)
// Logs all capability resolutions
// Enriches metadata with capability_id and success status
```

## C Library Integration

### Setup (Linux)
```bash
# Install dependencies
sudo apt-get install libpdfium-dev libharfbuzz-dev libfreetype6-dev

# Build
swift build
```

### Setup (macOS - for testing)
```bash
# Install dependencies
brew install harfbuzz freetype

# Build
swift build
```

## Testing

### Integration Tests
```swift
import XCTest
@testable import PlatformCore

final class PDFIntegrationTests: XCTestCase {
    override func setUp() async throws {
        await PlatformCapabilityBootstrap.registerPlatformCapabilities()
    }
    
    func testPDFRendering() async throws {
        let registry = CapabilityRegistry.shared
        let provider = await registry.resolve(
            capabilityId: CapabilityIds.pdfRender,
            as: PDFRenderingCapability.self
        )
        XCTAssertNotNil(provider)
    }
}
```

## Dependencies

- **CapabilityCore**: Capability protocols and registry
- **AnigmaCore**: Governance and ECS
- **ContractsCore**: Audit logging protocols
- **CHarfBuzz** (Linux): HarfBuzz C bindings
- **CFreeType** (Linux): FreeType C bindings
- **CPDFium** (Linux): PDFium C bindings

## Thread Safety

- `PlatformCapabilityBootstrap` is an `actor`
- All providers are `Sendable`
- Strict concurrency mode enabled

## See Also

- [CapabilityCore](../CapabilityCore/README.md) - Core protocols
- [Implementation Guide](../../Docs/capability-provider-implementation.md)
- [Bootstrap Examples](../../Docs/capability-bootstrap-examples.md)

## License

Part of the Anigma project. See LICENSE for details.
