# Context7 Corroboration

*Note: Context7 was queried to retrieve corroborating documentation based on the official source anchors. Context7 is treated as a corroborating retrieval layer, not the final authority.*

## Queries Executed
1. **Query**: "Unity Entities archetypes chunks components systems DOTS data-oriented"
   - **Retrieved Topic**: Unity Data-Oriented Technology Stack (DOTS) and ECS.
   - **Corroboration**: Confirmed Unity chunks are exactly 16 KiB uniform memory blocks holding same-archetype components. Confirmed ECS improves data locality through SoA patterns.
   - **Primary Authority**: [Unity DOTS Documentation](https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/index.html)

2. **Query**: "Metal MTLBuffer bytesNoCopy storage modes shared private"
   - **Retrieved Topic**: Apple Metal memory management.
   - **Corroboration**: Confirmed `MTLStorageMode.shared` is the default for Apple Silicon unified memory. Confirmed `makeBuffer(bytesNoCopy:)` wraps existing allocations without copying.
   - **Primary Authority**: [Apple Developer Metal Documentation](https://developer.apple.com/documentation/metal/mtldevice/makebuffer(bytesnocopy:length:options:deallocator:))

3. **Query**: "SwiftPM target product graph boundaries"
   - **Retrieved Topic**: Swift Package Manager architecture.
   - **Corroboration**: Confirmed strict logical separation of targets and products, reinforcing Anigma's doctrine to isolate native linker flags in separate targets.
   - **Primary Authority**: `swiftlang/swift-package-manager` repository and docs.

## Conclusion
Context7 retrievals successfully corroborated all findings from the primary official sources. No contradictions were found. Official docs and local source remain the primary authority.