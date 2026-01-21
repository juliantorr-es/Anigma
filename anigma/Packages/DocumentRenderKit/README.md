# DocumentRenderKit

## Responsibility
**Native Document Rendering Bridge**.
This module provides high-performance, native document rendering by bridging to the optimized Anigma C-renderer. It handles memory-safe lifting of native bitmap buffers into Swift `Data` objects.

## Implementation Details
- **Bridge**: Interfaces with `anigma_render.h` headers.
- **Safety**: Uses Swift's unsafe pointer lifting with proper bounds checking and error propagation from the native layer.
- **Truth in Engineering**: This module does **not** use mocks. It performs real rendering via the native backend.

## Usage Example

```swift
let renderer = NativeDocumentRenderer()
let documentData = ... // Document IR data
let renderedImage = try await renderer.render(documentData: documentData)
// renderedImage is now valid PNG/Bitmap Data
```

## Maturity Level
**Level 5 (Golden)**: Native C-bridge implemented, strict concurrency safety, functional verification.
